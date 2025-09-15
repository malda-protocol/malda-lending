// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IHypernativeFirewall {
    function register(address account, bool isStrictMode) external;
    function validateForbiddenAccountInteraction(address sender) external view;
    function validateForbiddenContextInteraction(address origin, address sender) external view;
    function validateBlacklistedAccountInteraction(address sender) external;
}

abstract contract HypernativeFirewallProtected {
    bytes32 private constant HYPERNATIVE_ORACLE_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.hypernative.firewall")) - 1);
    bytes32 private constant HYPERNATIVE_ADMIN_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.hypernative.admin")) - 1);
    bytes32 private constant HYPERNATIVE_MODE_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.hypernative.is_strict_mode")) - 1);
    
    event FirewallAdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event FirewallAddressChanged(address indexed previousFirewall, address indexed newFirewall);


    modifier onlyFirewallApproved() {
        address firewallAddress = _hypernativeFirewall();
        if (firewallAddress == address(0)) {
            _;
            return;
        }
        
        IHypernativeFirewall firewall = IHypernativeFirewall(firewallAddress);
        firewall.validateForbiddenContextInteraction(tx.origin, msg.sender);
        _;
    }

    modifier onlyFirewallApprovedAllowEOA() {
        address firewallAddress = _hypernativeFirewall();
        if (firewallAddress == address(0)) {
            _;
            return;
        }
        IHypernativeFirewall firewall = IHypernativeFirewall(firewallAddress);
        firewall.validateBlacklistedAccountInteraction(msg.sender);
        if (tx.origin == msg.sender && msg.sender.code.length == 0) {
            _;
            return;
        }
        
        firewall.validateForbiddenContextInteraction(tx.origin, msg.sender);
        _;
    }

    modifier onlyNotBlacklistedEOA() {
        address firewallAddress = _hypernativeFirewall();
        if (firewallAddress == address(0)) {
            _;
            return;
        }

        IHypernativeFirewall firewall = IHypernativeFirewall(firewallAddress);
        require(msg.sender == tx.origin && msg.sender.code.length == 0, "FirewallProtected: caller is not EOA");
        firewall.validateBlacklistedAccountInteraction(msg.sender);
        _;
    }

    modifier onlyFirewallAdmin() {
        require(msg.sender == hypernativeFirewallAdmin(), "FirewallProtected: caller is not the firewall admin");
        _;
    }

    function _initHypernativeFirewall(address _firewall, address _admin) internal {
        _changeFirewallAdmin(_admin);
        require(_firewall != address(0), "Firewall address cannot be initialized to 0");
        setFirewall(_firewall); 
    }

    function firewallRegister(address _account) public virtual {
        address firewallAddress = _hypernativeFirewall();
        bool isStrictMode = _hypernativeFirewallIsStrictMode();
        IHypernativeFirewall firewall = IHypernativeFirewall(firewallAddress);
        firewall.register(_account, isStrictMode);
    }

    /**
     * @dev Admin only function, sets new firewall admin. set to address(0) to revoke firewall
     */
    function setFirewall(address _firewall) public onlyFirewallAdmin() {
        address oldFirewall = _hypernativeFirewall();
        _setAddressBySlot(HYPERNATIVE_ORACLE_STORAGE_SLOT, _firewall);
        emit FirewallAddressChanged(oldFirewall, _firewall);
    }

    function setIsStrictMode(bool _mode) public onlyFirewallAdmin() {
        _setValueBySlot(HYPERNATIVE_MODE_STORAGE_SLOT, _mode ? 1 : 0);
    }

    function changeFirewallAdmin(address _newAdmin) public onlyFirewallAdmin() {
        require(_newAdmin != address(0), "Firewall admin cannot be set to 0");
        _changeFirewallAdmin(_newAdmin);
    }

    function _changeFirewallAdmin(address _newAdmin) internal {
        address oldAdmin = hypernativeFirewallAdmin();
        _setAddressBySlot(HYPERNATIVE_ADMIN_STORAGE_SLOT, _newAdmin);
        emit FirewallAdminChanged(oldAdmin,  _newAdmin);
    }


    function _setAddressBySlot(bytes32 slot, address newAddress) internal {
        assembly {
            sstore(slot, newAddress)
        }
    }

    function _setValueBySlot(bytes32 _slot, uint256 _value) internal {
        assembly {
            sstore(_slot, _value)
        }
    }

    function hypernativeFirewallAdmin() public view returns (address) {
        return _getAddressBySlot(HYPERNATIVE_ADMIN_STORAGE_SLOT);
    }

    function _hypernativeFirewallIsStrictMode() private view returns (bool) {
        return _getValueBySlot(HYPERNATIVE_MODE_STORAGE_SLOT) == 1;
    }

    function _hypernativeFirewall() private view returns (address) {
        return _getAddressBySlot(HYPERNATIVE_ORACLE_STORAGE_SLOT);
    }

    function _getAddressBySlot(bytes32 slot) internal view returns (address addr) {
        assembly {
            addr := sload(slot)
        }
    }

    function _getValueBySlot(bytes32 _slot) internal view returns (uint256 value) {
        assembly {
            value := sload(_slot)
        }
    }
}