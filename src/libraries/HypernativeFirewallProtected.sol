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
/// @notice Abstract contract that provides firewall protection for the contract
abstract contract HypernativeFirewallProtected {
    // ----------- CONSTANTS ------------
    /// @notice Storage slot for the firewall address
    bytes32 private constant HYPERNATIVE_ORACLE_STORAGE_SLOT =
        bytes32(uint256(keccak256("eip1967.hypernative.firewall")) - 1);

    /// @notice Storage slot for the firewall admin address
    bytes32 private constant HYPERNATIVE_ADMIN_STORAGE_SLOT =
        bytes32(uint256(keccak256("eip1967.hypernative.admin")) - 1);

    /// @notice Storage slot for the firewall strict mode
    bytes32 private constant HYPERNATIVE_MODE_STORAGE_SLOT =
        bytes32(uint256(keccak256("eip1967.hypernative.is_strict_mode")) - 1);

    // ----------- EVENTS ------------
    /// @notice Emitted when the firewall admin is changed
    /// @param previousAdmin The previous firewall admin address
    /// @param newAdmin The new firewall admin address
    event FirewallAdminChanged(address indexed previousAdmin, address indexed newAdmin);

    /// @notice Emitted when the firewall address is changed
    /// @param previousFirewall The previous firewall address
    /// @param newFirewall The new firewall address
    event FirewallAddressChanged(address indexed previousFirewall, address indexed newFirewall);

    // ----------- ERRORS ------------
    /// @notice Thrown when the caller is not an EOA
    error HypernativeFirewallProtected_CallerNotEOA();

    /// @notice Thrown when the caller is not the firewall admin
    error HypernativeFirewallProtected_CallerNotFirewallAdmin();

    /// @notice Thrown when the address is not valid
    error HypernativeFirewallProtected_AddressNotValid();

    // ----------- MODIFIERS ------------
    /// @notice Modifier to restrict access to only approved firewall addresses
    modifier onlyFirewallApproved() {
        // If firewall is not set, allow the transaction
        address firewallAddress = _hypernativeFirewall();
        if (firewallAddress == address(0)) {
            _;
            return;
        }

        // If firewall is set, validate the context interaction
        IHypernativeFirewall firewall = IHypernativeFirewall(firewallAddress);
        // @audit-question is using tx.origin a recommended pattern? it's generally frowned upon
        // solhint-disable-next-line avoid-tx-origin
        firewall.validateForbiddenContextInteraction(tx.origin, msg.sender);
        _;
    }

    /// @notice Modifier to restrict access to only approved firewall addresses and EOAs
    modifier onlyFirewallApprovedAllowEOA() {
        // If firewall is not set, allow the transaction
        address firewallAddress = _hypernativeFirewall();
        if (firewallAddress == address(0)) {
            _;
            return;
        }

        // If firewall is set, validate the blacklisted account interaction
        IHypernativeFirewall firewall = IHypernativeFirewall(firewallAddress);
        firewall.validateBlacklistedAccountInteraction(msg.sender);

        // If the caller is an EOA, validate the context interaction
        // @audit-question is using tx.origin a recommended pattern? it's generally frowned upon
        // solhint-disable-next-line avoid-tx-origin
        if (tx.origin == msg.sender && msg.sender.code.length == 0) {
            _;
            return;
        }

        // Validate the context interaction
        // @audit-question is using tx.origin a recommended pattern? it's generally frowned upon
        // solhint-disable-next-line avoid-tx-origin
        firewall.validateForbiddenContextInteraction(tx.origin, msg.sender);
        _;
    }

    /// @notice Modifier to restrict access to only not blacklisted EOAs
    modifier onlyNotBlacklistedEOA() {
        // If firewall is not set, allow the transaction
        address firewallAddress = _hypernativeFirewall();
        if (firewallAddress == address(0)) {
            _;
            return;
        }

        // If firewall is set, validate the blacklisted account interaction
        IHypernativeFirewall firewall = IHypernativeFirewall(firewallAddress);
        // @audit-question is using tx.origin a recommended pattern? it's generally frowned upon
        // solhint-disable-next-line avoid-tx-origin
        require(msg.sender == tx.origin && msg.sender.code.length == 0, HypernativeFirewallProtected_CallerNotEOA());
        firewall.validateBlacklistedAccountInteraction(msg.sender);
        _;
    }

    /// @notice Modifier to restrict access to only the firewall admin
    modifier onlyFirewallAdmin() {
        require(msg.sender == hypernativeFirewallAdmin(), HypernativeFirewallProtected_CallerNotFirewallAdmin());
        _;
    }

    // ----------- PUBLIC FUNCTIONS ------------
    /// @notice Function to register an account with the firewall
    /// @param _account The account to register
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

    /// @notice Function to change the firewall admin
    /// @param _newAdmin The new firewall admin address
    function changeFirewallAdmin(address _newAdmin) public onlyFirewallAdmin {
        // Requirements: firewall admin is not zero
        require(_newAdmin != address(0), HypernativeFirewallProtected_AddressNotValid());

        // Effects: change the firewall admin
        _changeFirewallAdmin(_newAdmin);
    }

    /// @notice Function to get the firewall admin
    /// @return The firewall admin address
    function hypernativeFirewallAdmin() public view returns (address) {
        return _getAddressBySlot(HYPERNATIVE_ADMIN_STORAGE_SLOT);
    }

    // ----------- INTERNAL FUNCTIONS ------------
    /// @notice Internal function to initialize the firewall
    /// @param _firewall The firewall address
    /// @param _admin The firewall admin address
    function _initHypernativeFirewall(address _firewall, address _admin) internal {
        // Effects: change the firewall admin
        _changeFirewallAdmin(_admin);

        // Requirements: firewall address is not zero
        require(_firewall != address(0), HypernativeFirewallProtected_AddressNotValid());

        // Effects: set the firewall address
        setFirewall(_firewall);
    }

    /// @notice Internal function to change the firewall admin
    /// @param _newAdmin The new firewall admin address
    function _changeFirewallAdmin(address _newAdmin) internal {
        address oldAdmin = hypernativeFirewallAdmin();

        // Effects: set the firewall admin address
        _setAddressBySlot(HYPERNATIVE_ADMIN_STORAGE_SLOT, _newAdmin);

        // Events: emit the firewall admin changed event
        emit FirewallAdminChanged(oldAdmin, _newAdmin);
    }

    /// @notice Internal function to set the address in the slot
    /// @param slot The slot to set the address in
    /// @param newAddress The address to set in the slot
    function _setAddressBySlot(bytes32 slot, address newAddress) internal {
        assembly {
            sstore(slot, newAddress)
        }
    }

    /// @notice Internal function to set the value in the slot
    /// @param _slot The slot to set the value in
    /// @param _value The value to set in the slot
    function _setValueBySlot(bytes32 _slot, uint256 _value) internal {
        assembly {
            sstore(_slot, _value)
        }
    }

    /// @notice Internal function to get the address from the slot
    /// @param slot The slot to get the address from
    /// @return addr The address from the slot
    function _getAddressBySlot(bytes32 slot) internal view returns (address addr) {
        assembly {
            addr := sload(slot)
        }
    }

    /// @notice Internal function to get the value from the slot
    /// @param _slot The slot to get the value from
    /// @return value The value from the slot
    function _getValueBySlot(bytes32 _slot) internal view returns (uint256 value) {
        assembly {
            value := sload(_slot)
        }
    }

    /// @notice Internal function to get the strict mode
    /// @return The strict mode
    function _hypernativeFirewallIsStrictMode() private view returns (bool) {
        return _getValueBySlot(HYPERNATIVE_MODE_STORAGE_SLOT) == 1;
    }

    /// @notice Internal function to get the firewall address
    /// @return The firewall address
    function _hypernativeFirewall() private view returns (address) {
        return _getAddressBySlot(HYPERNATIVE_ORACLE_STORAGE_SLOT);
    }
}
