// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// solhint-disable gas-small-strings

/// @title IHypernativeFirewall
/// @author Merge Layers Inc.
/// @notice Interface for the HypernativeFirewall contract
interface IHypernativeFirewall {
    /// @notice Registers an account with the firewall
    /// @param account The account to register
    /// @param isStrictMode The strict mode
    function register(address account, bool isStrictMode) external;

    /// @notice Validates the blacklisted account interaction
    /// @param sender The sender of the transaction
    function validateBlacklistedAccountInteraction(address sender) external;

    /// @notice Validates the forbidden account interaction
    /// @param sender The sender of the transaction
    function validateForbiddenAccountInteraction(address sender) external view;

    /// @notice Validates the forbidden context interaction
    /// @param origin The origin of the transaction
    /// @param sender The sender of the transaction
    function validateForbiddenContextInteraction(address origin, address sender) external view;
}

/// @title HypernativeFirewallProtected
/// @author Merge Layers Inc.
/// @notice Abstract contract that provides firewall protection for the contract.
/// @dev Inherited from Hypernative and refactored it for our needs, but without changing the core logic.
abstract contract HypernativeFirewallProtected {
    bytes32 private constant HYPERNATIVE_ORACLE_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.hypernative.firewall")) - 1);
    bytes32 private constant HYPERNATIVE_ADMIN_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.hypernative.admin")) - 1);
    bytes32 private constant HYPERNATIVE_MODE_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.hypernative.is_strict_mode")) - 1);
    
    // ----------- EVENTS ------------
    event FirewallAdminChanged(address indexed previousAdmin, address indexed newAdmin);

    /// @notice Emitted when the firewall address is changed
    /// @param previousFirewall The previous firewall address
    /// @param newFirewall The new firewall address
    event FirewallAddressChanged(address indexed previousFirewall, address indexed newFirewall);

    error HypernativeFirewallProtected_NotAdmin();
    error HypernativeFirewallProtected_NotValid();

    modifier onlyFirewallAdmin() {
        require(msg.sender == hypernativeFirewallAdmin(), HypernativeFirewallProtected_NotAdmin());
        _;
    }

    /// @notice Modifier to restrict access to only approved firewall addresses and EOAs
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
        // Effects: register the account with the firewall
        IHypernativeFirewall(_hypernativeFirewall()).register(_account, _hypernativeFirewallIsStrictMode());
    }

    /// @notice Function to set the firewall
    /// @dev Admin only function, sets new firewall admin. set to address(0) to revoke firewall
    /// @param _firewall The new firewall address
    function setFirewall(address _firewall) public onlyFirewallAdmin {
        address oldFirewall = _hypernativeFirewall();

        // Effects: set the firewall address
        _setAddressBySlot(HYPERNATIVE_ORACLE_STORAGE_SLOT, _firewall);

        // Events: emit the firewall address changed event
        emit FirewallAddressChanged(oldFirewall, _firewall);
    }

    /// @notice Function to set the strict mode
    /// @param _mode The strict mode
    function setIsStrictMode(bool _mode) public onlyFirewallAdmin {
        // Effects: set the strict mode
        _setValueBySlot(HYPERNATIVE_MODE_STORAGE_SLOT, _mode ? 1 : 0);
    }

    function changeFirewallAdmin(address _newAdmin) public onlyFirewallAdmin() {
        require(_newAdmin != address(0), HypernativeFirewallProtected_NotValid());
        _changeFirewallAdmin(_newAdmin);
    }

  
    // ----------- INTERNAL FUNCTIONS ------------
    function _firewallGate(address sender) internal {
        address fw = _hypernativeFirewall();
        if (fw == address(0)) return;

        IHypernativeFirewall firewall = IHypernativeFirewall(fw);
        firewall.validateBlacklistedAccountInteraction(sender);
        if (tx.origin == sender && sender.code.length == 0) return;
        firewall.validateForbiddenContextInteraction(tx.origin, sender);
    }

    /// @notice Internal function to initialize the firewall
    /// @param _firewall The firewall address
    /// @param _admin The firewall admin address
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
