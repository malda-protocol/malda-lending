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
    
    // ----------- EVENTS ------------
    event FirewallAdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event FirewallAddressChanged(address indexed previousFirewall, address indexed newFirewall);

    error HypernativeFirewallProtected_NotAdmin();
    error HypernativeFirewallProtected_NotValid();

    modifier onlyFirewallAdmin() {
        require(msg.sender == hypernativeFirewallAdmin(), HypernativeFirewallProtected_NotAdmin());
        _;
    }

    modifier onlyFirewallApprovedAllowEOA() {
        _firewallGate(msg.sender);
        _;
    }
 
    // ----------- VIEW ------------
    function hypernativeFirewallAdmin() public view returns (address) {
        return _getAddressBySlot(HYPERNATIVE_ADMIN_STORAGE_SLOT);
    }

    // ----------- PUBLIC ------------
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
        require(_newAdmin != address(0), HypernativeFirewallProtected_NotValid());
        _changeFirewallAdmin(_newAdmin);
    }

  
    // ----------- INTERNAL ------------
    function _firewallGate(address sender) internal {
        address fw = _hypernativeFirewall();
        if (fw == address(0)) return;

        IHypernativeFirewall firewall = IHypernativeFirewall(fw);
        firewall.validateBlacklistedAccountInteraction(sender);
        if (tx.origin == sender && sender.code.length == 0) return;
        firewall.validateForbiddenContextInteraction(tx.origin, sender);
    }

    function _initHypernativeFirewall(address _firewall, address _admin) internal {
        _changeFirewallAdmin(_admin);
        require(_firewall != address(0), HypernativeFirewallProtected_NotValid());
        setFirewall(_firewall); 
    }

    function _changeFirewallAdmin(address _newAdmin) internal {
        address oldAdmin = hypernativeFirewallAdmin();
        _setAddressBySlot(HYPERNATIVE_ADMIN_STORAGE_SLOT, _newAdmin);
        emit FirewallAdminChanged(oldAdmin,  _newAdmin);
    }


    // ----------- PRIVATE ------------
    function _setAddressBySlot(bytes32 slot, address newAddress) private {
        assembly {
            sstore(slot, newAddress)
        }
    }

    function _setValueBySlot(bytes32 _slot, uint256 _value) private {
        assembly {
            sstore(_slot, _value)
        }
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