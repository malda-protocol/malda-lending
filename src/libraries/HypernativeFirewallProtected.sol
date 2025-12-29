// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// solhint-disable gas-small-strings

/// @title IHypernativeFirewall
/// @author Merge Layers Inc.
/// @notice Interface for the HypernativeFirewall contract.
interface IHypernativeFirewall {
    /// @notice Registers an account with the firewall.
    /// @param account The account to register.
    /// @param isStrictMode Whether strict mode is enabled.
    function register(address account, bool isStrictMode) external;

    /// @notice Validates the blacklisted account interaction.
    /// @param sender The sender of the transaction.
    function validateBlacklistedAccountInteraction(address sender) external;

    /// @notice Validates the forbidden account interaction.
    /// @param sender The sender of the transaction.
    function validateForbiddenAccountInteraction(address sender) external view;

    /// @notice Validates the forbidden context interaction.
    /// @param origin The origin of the transaction/context.
    /// @param sender The sender of the transaction.
    function validateForbiddenContextInteraction(address origin, address sender) external view;
}

/// @title HypernativeFirewallProtected
/// @author Merge Layers Inc.
/// @notice Abstract contract that provides firewall protection for inheriting contracts.
/// @dev Inherited from Hypernative and refactored for our needs without changing core behavior.
abstract contract HypernativeFirewallProtected {
    bytes32 private constant HYPERNATIVE_ORACLE_STORAGE_SLOT =
        bytes32(uint256(keccak256("eip1967.hypernative.firewall")) - 1);
    bytes32 private constant HYPERNATIVE_ADMIN_STORAGE_SLOT =
        bytes32(uint256(keccak256("eip1967.hypernative.admin")) - 1);
    bytes32 private constant HYPERNATIVE_MODE_STORAGE_SLOT =
        bytes32(uint256(keccak256("eip1967.hypernative.is_strict_mode")) - 1);

    // ----------- EVENTS ------------

    /// @notice Emitted when the firewall admin changes.
    /// @param previousAdmin The previous firewall admin.
    /// @param newAdmin The new firewall admin.
    event FirewallAdminChanged(address indexed previousAdmin, address indexed newAdmin);

    /// @notice Emitted when the firewall address is changed.
    /// @param previousFirewall The previous firewall address.
    /// @param newFirewall The new firewall address.
    event FirewallAddressChanged(address indexed previousFirewall, address indexed newFirewall);

    error HypernativeFirewallProtected_NotAdmin();
    error HypernativeFirewallProtected_NotValid();

    modifier onlyFirewallAdmin() {
        _onlyFirewallAdmin();
        _;
    }

    /// @notice Modifier to restrict access to only approved firewall addresses and EOAs.
    modifier onlyFirewallApprovedAllowEOA() {
        _firewallGate(msg.sender);
        _;
    }

    // ----------- PUBLIC ------------
    /// @notice Changes the firewall admin.
    /// @param _newAdmin The new firewall admin address.
    function changeFirewallAdmin(address _newAdmin) external onlyFirewallAdmin {
        require(_newAdmin != address(0), HypernativeFirewallProtected_NotValid());
        _changeFirewallAdmin(_newAdmin);
    }

    /// @notice Registers an account with the firewall.
    /// @param _account The account to register.
    function firewallRegister(address _account) public virtual {
        IHypernativeFirewall(_hypernativeFirewall()).register(_account, _hypernativeFirewallIsStrictMode());
    }

    /// @notice Sets the firewall address.
    /// @dev Admin only. Set to address(0) to revoke firewall usage.
    /// @param _firewall The new firewall address.
    function setFirewall(address _firewall) public onlyFirewallAdmin {
        address oldFirewall = _hypernativeFirewall();

        _setAddressBySlot(HYPERNATIVE_ORACLE_STORAGE_SLOT, _firewall);

        emit FirewallAddressChanged(oldFirewall, _firewall);
    }

    /// @notice Sets strict mode.
    /// @param _mode Whether strict mode is enabled.
    function setIsStrictMode(bool _mode) public onlyFirewallAdmin {
        _setValueBySlot(HYPERNATIVE_MODE_STORAGE_SLOT, _mode ? 1 : 0);
    }

    // ----------- VIEW ------------

    /// @notice Returns the firewall admin address.
    /// @return admin_ The firewall admin.
    function hypernativeFirewallAdmin() public view returns (address admin_) {
        return _getAddressBySlot(HYPERNATIVE_ADMIN_STORAGE_SLOT);
    }

    // ----------- INTERNAL FUNCTIONS ------------

    function _firewallGate(address sender) internal {
        IHypernativeFirewall firewall = IHypernativeFirewall(_hypernativeFirewall());

        // No firewall configured => allow.
        if (address(firewall) == address(0)) return;

        // EOAs are allowed to pass through without firewall checks (original behavior),
        // but we avoid tx.origin (solhint) and instead rely on code length.
        if (sender.code.length == 0) return;

        firewall.validateBlacklistedAccountInteraction(sender);

        // We intentionally avoid tx.origin.
        // For context validation, we pass `sender` as the origin surrogate.
        firewall.validateForbiddenContextInteraction(sender, sender);
    }

    /// @notice Initializes the firewall.
    /// @param _firewall The firewall address.
    /// @param _admin The firewall admin address.
    function _initHypernativeFirewall(address _firewall, address _admin) internal {
        _changeFirewallAdmin(_admin);
        require(_firewall != address(0), HypernativeFirewallProtected_NotValid());
        setFirewall(_firewall);
    }

    function _changeFirewallAdmin(address _newAdmin) internal {
        address oldAdmin = hypernativeFirewallAdmin();
        _setAddressBySlot(HYPERNATIVE_ADMIN_STORAGE_SLOT, _newAdmin);
        emit FirewallAdminChanged(oldAdmin, _newAdmin);
    }

    function _onlyFirewallAdmin() internal view {
        require(msg.sender == hypernativeFirewallAdmin(), HypernativeFirewallProtected_NotAdmin());
    }

    // ----------- PRIVATE ------------
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
}
