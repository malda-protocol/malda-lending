// Copyright (c) 2025 Merge Layers Inc.
//
// This source code is licensed under the Business Source License 1.1
// (the "License"); you may not use this file except in compliance with the
// License. You may obtain a copy of the License at
//
//     https://github.com/malda-protocol/malda-lending/blob/main/LICENSE-BSL
//
// See the License for the specific language governing permissions and
// limitations under the License.
//
// This file contains code derived from or inspired by Compound V2,
// originally licensed under the BSD 3-Clause License. See LICENSE-COMPOUND-V2
// for original license terms and attributions.

// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|
*/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {HypernativeFirewallProtected} from "src/libraries/HypernativeFirewallProtected.sol";

// contracts
import {IRoles} from "src/interfaces/IRoles.sol";
import {IBlacklister} from "src/interfaces/IBlacklister.sol";
import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

import {mTokenProofDecoderLib} from "src/libraries/mTokenProofDecoderLib.sol";

import {IZkVerifier} from "src/verifier/ZkVerifier.sol";

/// @title mTokenGateway
/// @author Merge Layers Inc.
/// @notice Gateway contract for mToken operations
contract mTokenGateway is OwnableUpgradeable, ImTokenGateway, ImTokenOperationTypes, HypernativeFirewallProtected {
    using SafeERC20 for IERC20;

    // ----------- CONSTANTS -----------
    /// @notice Linea chain ID
    uint32 private constant LINEA_CHAIN_ID = 59144;

    // ----------- STORAGE -----------
    /// @inheritdoc ImTokenGateway
    IRoles public rolesOperator;

    /// @inheritdoc ImTokenGateway
    IBlacklister public blacklistOperator;

    /// @notice The ZkVerifier contract
    IZkVerifier public verifier;

    /// @notice Mapping of operation types to pause status
    mapping(OperationType operationType => bool paused) public paused;

    /// @inheritdoc ImTokenGateway
    address public underlying;

    /// @notice Mapping of accumulated amounts in
    mapping(address account => uint256 amount) public accAmountIn;

    /// @notice Mapping of accumulated amounts out
    mapping(address account => uint256 amount) public accAmountOut;

    /// @notice Mapping of allowed callers
    mapping(address caller => mapping(address target => bool allowed)) public allowedCallers;

    /// @notice Mapping of whitelisted users
    mapping(address user => bool whitelisted) public userWhitelisted;

    /// @notice Whether whitelist is enabled
    bool public whitelistEnabled;

    /// @notice Gas fee required for `supplyOnHost`
    uint256 public gasFee;

    // slither-disable-next-line unused-state
    uint256[50] private __gap;

    // ----------- MODIFIERS -----------
    /// @notice Modifier to restrict access to only allowed users
    /// @param _type The operation type
    modifier notPaused(OperationType _type) {
        // Requirements: the operation is not paused
        require(!paused[_type], mTokenGateway_Paused(_type));
        _;
    }

    /// @notice Modifier to restrict access to only allowed users
    /// @param user The user address
    modifier onlyAllowedUser(address user) {
        if (whitelistEnabled) {
            // Requirements: the user is whitelisted
            require(userWhitelisted[user], mTokenGateway_UserNotWhitelisted());
        }
        _;
    }

    /// @notice Modifier to restrict access to only not blacklisted users
    /// @param user The user address
    modifier ifNotBlacklisted(address user) {
        // Requirements: the user is not blacklisted
        require(!blacklistOperator.isBlacklisted(user), mTokenGateway_UserBlacklisted());
        _;
    }

    /// @notice Modifier to check liquidate conditions
    modifier liquidateChecks() {
        // Requirements: the liquidate operation is not paused
        require(!paused[OperationType.Liquidate], mTokenGateway_Paused(OperationType.Liquidate));
        // Requirements: the amount in operation is not paused
        require(!paused[OperationType.AmountIn], mTokenGateway_Paused(OperationType.AmountIn));
        if (whitelistEnabled) {
            // Requirements: the sender is whitelisted
            require(userWhitelisted[msg.sender], mTokenGateway_UserNotWhitelisted());
        }
        // Requirements: the sender is not blacklisted
        require(!blacklistOperator.isBlacklisted(msg.sender), mTokenGateway_UserBlacklisted());
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    /// @notice Disables initializers on implementation
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the gateway
    /// @param _owner Owner address
    /// @param _underlying Underlying token
    /// @param _roles Roles contract
    /// @param _blacklister Blacklister contract
    /// @param zkVerifier_ ZK verifier
    function initialize(
        address payable _owner,
        address _underlying,
        address _roles,
        address _blacklister,
        address zkVerifier_
    ) external initializer {
        __Ownable_init(_owner);

        // Requirements: roles contract is not zero address
        require(_roles != address(0), mTokenGateway_AddressNotValid());
        // Requirements: ZK verifier is not zero address
        require(zkVerifier_ != address(0), mTokenGateway_AddressNotValid());
        // Requirements: blacklister contract is not zero address
        require(_blacklister != address(0), mTokenGateway_AddressNotValid());
        // Requirements: underlying token is not zero address
        require(_underlying != address(0), mTokenGateway_AddressNotValid());
        // Requirements: roles contract is not zero address
        require(_roles != address(0), mTokenGateway_AddressNotValid());

        // Effects: set the underlying token
        underlying = _underlying;
        // Effects: set the roles operator
        rolesOperator = IRoles(_roles);
        // Effects: set the blacklist operator
        blacklistOperator = IBlacklister(_blacklister);
        // Effects: set the ZK verifier
        verifier = IZkVerifier(zkVerifier_);
    }

    // ----------- OWNER ------------
    /// @notice Initializes the firewall configuration
    /// @param _firewall Firewall address to set
    function initFirewall(address _firewall) external onlyOwner {
        _initHypernativeFirewall(_firewall, owner());
    }

    /// @notice Sets the blacklister contract
    /// @param _blacklister Address of the blacklister
    function setBlacklister(address _blacklister) external onlyOwner {
        // Requirements: blacklister contract is not zero address
        require(_blacklister != address(0), mTokenGateway_AddressNotValid());
        // Effects: set the blacklist operator
        blacklistOperator = IBlacklister(_blacklister);
    }

    /// @notice Sets user whitelist status
    /// @param user The user address
    /// @param state The new state
    function setWhitelistedUser(address user, bool state) external onlyOwner {
        // Effects: set the user whitelist status
        userWhitelisted[user] = state;
        // Events: emit the user whitelist status changed event
        emit mTokenGateway_UserWhitelisted(user, state);
    }

    /// @notice Enable user whitelist
    function enableWhitelist() external onlyOwner {
        // Effects: enable the user whitelist
        whitelistEnabled = true;
        // Events: emit the user whitelist enabled event
        emit mTokenGateway_WhitelistEnabled();
    }

    /// @notice Disable user whitelist
    function disableWhitelist() external onlyOwner {
        // Effects: disable the user whitelist
        whitelistEnabled = false;
        // Events: emit the user whitelist disabled event
        emit mTokenGateway_WhitelistDisabled();
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function setPaused(OperationType _type, bool state) external override onlyFirewallApprovedAllowEOA {
        if (state) {
            // Requirements: if pausing, the caller is the owner or allowed for guardian pause
            require(
                msg.sender == owner() || rolesOperator.isAllowedFor(msg.sender, rolesOperator.GUARDIAN_PAUSE()),
                mTokenGateway_CallerNotAllowed()
            );
        } else {
            // Requirements: if unpausing, the caller is the owner
            require(msg.sender == owner(), mTokenGateway_CallerNotAllowed());
        }

        // Effects: set the paused state
        paused[_type] = state;

        // Events: emit the paused state changed event
        emit mTokenGateway_PausedState(_type, state);
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function extractForRebalancing(uint256 amount)
        external
        notPaused(OperationType.Rebalancing)
        onlyFirewallApprovedAllowEOA
    {
        if (!rolesOperator.isAllowedFor(msg.sender, rolesOperator.REBALANCER())) {
            revert mTokenGateway_NotRebalancer();
        }
        IERC20(underlying).safeTransfer(msg.sender, amount);
    }

    /// @notice Sets the gas fee
    /// @param amount the new gas fee
    function setGasFee(uint256 amount) external onlyOwner {
        // Effects: set the gas fee
        gasFee = amount;

        // Events: emit the gas fee updated event
        emit mTokenGateway_GasFeeUpdated(amount);
    }

    /**
     * @notice Withdraw gas received so far
     * @param receiver the receiver address
     */
    function withdrawGasFees(address payable receiver) external onlyFirewallApprovedAllowEOA {
        // Requirements: the sender is the owner or allowed for sequencer
        require(
            msg.sender == owner() || _isAllowedFor(msg.sender, _getSequencerRole()), mTokenGateway_CallerNotAllowed()
        );

        // Requirements: the receiver is not zero address
        require(receiver != address(0), mTokenGateway_AddressNotValid());

        // Interactions: transfer the gas fees to the receiver
        receiver.transfer(address(this).balance);
    }

    /// @notice Updates IZkVerifier address
    /// @param _zkVerifier the verifier address
    function updateZkVerifier(address _zkVerifier) external onlyOwner {
        // Requirements: the ZK verifier is not zero address
        require(_zkVerifier != address(0), mTokenGateway_AddressNotValid());

        // Events: emit the ZK verifier updated event
        emit ZkVerifierUpdated(address(verifier), _zkVerifier);

        // Effects: set the ZK verifier
        verifier = IZkVerifier(_zkVerifier);
    }

    // ----------- EXTERNAL ------------
    /// @inheritdoc ImTokenGateway
    function updateAllowedCallerStatus(address caller, bool status) external override {
        // Effects: set the allowed caller status
        allowedCallers[msg.sender][caller] = status;

        // Events: emit the allowed caller updated event
        emit AllowedCallerUpdated(msg.sender, caller, status);
    }

    /// @inheritdoc ImTokenGateway
    function supplyOnHost(uint256 amount, address receiver, bytes4 lineaSelector)
        external
        payable
        override
        notPaused(OperationType.AmountIn)
        onlyAllowedUser(msg.sender)
        ifNotBlacklisted(msg.sender)
        ifNotBlacklisted(receiver)
        onlyFirewallApprovedAllowEOA
    {
        _takeIn(underlying, amount, receiver);

        // Events: emit the supplied event
        emit mTokenGateway_Supplied(
            msg.sender,
            receiver,
            accAmountIn[receiver],
            accAmountOut[receiver],
            amount,
            uint32(block.chainid),
            LINEA_CHAIN_ID,
            lineaSelector
        );
    }

    /// @inheritdoc ImTokenGateway
    function liquidate(address userToLiquidate, uint256 liquidateAmount, address collateral, address receiver)
        external
        payable
        override
        liquidateChecks
        ifNotBlacklisted(receiver)
        onlyFirewallApprovedAllowEOA
    {
        // Effects: take in the underlying
        _takeIn(underlying, liquidateAmount, receiver);

        // Events: emit the liquidate event
        emit mTokenGateway_Liquidate(
            msg.sender, receiver, liquidateAmount, uint32(block.chainid), LINEA_CHAIN_ID, userToLiquidate, collateral
        );
    }

    /// @inheritdoc ImTokenGateway
    function outHere(bytes calldata journalData, bytes calldata seal, uint256[] calldata amounts, address receiver)
        external
        notPaused(OperationType.AmountOutHere)
        ifNotBlacklisted(msg.sender)
        ifNotBlacklisted(receiver)
        onlyFirewallApprovedAllowEOA
    {
        // Requirements: if the sender is allowed for proof batch forwarder, verify the proof
        if (!rolesOperator.isAllowedFor(msg.sender, rolesOperator.PROOF_BATCH_FORWARDER())) {
            _verifyProof(journalData, seal);
        }

        // Cecode the journal data
        bytes[] memory journals = abi.decode(journalData, (bytes[]));
        uint256 length = journals.length;
        // Requirements: the length of the journals must be equal to the length of the amounts
        require(length == amounts.length, mTokenGateway_LengthNotValid());

        for (uint256 i; i < journals.length; i++) {
            // Effects: process the outgoing transfer(s)
            _outHere(journals[i], amounts[i], receiver);
        }
    }

    // ----------- VIEW ------------
    /// @inheritdoc ImTokenGateway
    function isPaused(OperationType _type) external view returns (bool) {
        return paused[_type];
    }

    /// @inheritdoc ImTokenGateway
    function getProofData(address user, uint32) external view returns (uint256, uint256) {
        return (accAmountIn[user], accAmountOut[user]);
    }

    /// @notice Registers an account in the firewall
    /// @param _account Account to register
    function firewallRegister(address _account) public override(HypernativeFirewallProtected) {
        super.firewallRegister(_account);
    }

    // ----------- PRIVATE ------------
    /// @notice Handles inbound transfers and accounting
    /// @param asset Asset address
    /// @param amount Amount to transfer
    /// @param receiver Receiver address
    function _takeIn(address asset, uint256 amount, address receiver) private {
        // Requirements: the amount must be greater than 0
        require(amount > 0, mTokenGateway_AmountNotValid());

        // Requirements: the gas fee must be greater than or equal to the gas fee
        require(msg.value >= gasFee, mTokenGateway_NotEnoughGasFee());

        // Effects: update the accumulated amount in for the receiver
        accAmountIn[receiver] += amount;

        // Interactions: transfer the underlying from the sender to the contract
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Processes an outgoing transfer based on journal data
    /// @param journalData Encoded journal payload
    /// @param amount Amount to transfer
    /// @param receiver Receiver address override
    function _outHere(bytes memory journalData, uint256 amount, address receiver) private {
        (address _sender, address _market,, uint256 _accAmountOut, uint32 _chainId, uint32 _dstChainId,) =
            mTokenProofDecoderLib.decodeJournal(journalData);

        // TODO @Cosmin Keep until we allow self-sequencing
        // temporary overwrite; will be removed in future implementations
        receiver = _sender;

        // Requirements: the sender is not blacklisted
        require(!blacklistOperator.isBlacklisted(_sender), mTokenGateway_UserBlacklisted());

        // Requirements: the sender is allowed for proof forwarder or batch proof forwarder
        _checkSender(msg.sender, _sender);

        // Requirements: the market is this extension market
        require(_market == address(this), mTokenGateway_AddressNotValid());

        // Requirements: the source chain is Linea
        require(_chainId == LINEA_CHAIN_ID, mTokenGateway_ChainNotValid()); // allow only Linea

        // Requirements: the destination chain is the current chain
        require(_dstChainId == uint32(block.chainid), mTokenGateway_ChainNotValid());

        // Requirements: the amount is greater than 0
        require(amount > 0, mTokenGateway_AmountNotValid());

        // Requirements: the accumulated amount out is greater than or equal to the amount
        require(_accAmountOut - accAmountOut[_sender] >= amount, mTokenGateway_AmountTooBig());

        // Requirements: the balance of the underlying is greater than or equal to the amount
        require(IERC20(underlying).balanceOf(address(this)) >= amount, mTokenGateway_ReleaseCashNotAvailable());

        // Effects: update the accumulated amount out for the sender
        accAmountOut[_sender] += amount;

        // Interactions: transfer the underlying from the contract to the sender
        IERC20(underlying).safeTransfer(_sender, amount);

        // Events: emit the extracted event
        emit mTokenGateway_Extracted(
            msg.sender,
            _sender,
            receiver,
            accAmountIn[_sender],
            accAmountOut[_sender],
            amount,
            uint32(_chainId),
            uint32(block.chainid)
        );
    }

    /// @notice Verifies proof data and inclusion constraints
    /// @param journalData Encoded journals
    /// @param seal Proof seal data
    function _verifyProof(bytes calldata journalData, bytes calldata seal) private view {
        // Requirements: the journal data is not empty
        require(journalData.length > 0, mTokenGateway_JournalNotValid());

        // Decode the dynamic array of journals.
        bytes[] memory journals = abi.decode(journalData, (bytes[]));

        // Check the L1Inclusion flag for each journal.
        bool isSequencer = _isAllowedFor(msg.sender, _getProofForwarderRole())
            || _isAllowedFor(msg.sender, _getBatchProofForwarderRole());

        if (!isSequencer) {
            for (uint256 i = 0; i < journals.length; i++) {
                (,,,,,, bool l1Inclusion) = mTokenProofDecoderLib.decodeJournal(journals[i]);
                // Requirements: the L1 inclusion is required
                require(l1Inclusion, mTokenGateway_L1InclusionRequired());
            }
        }

        // Interactions: verify the proof using the ZkVerifier contract
        verifier.verifyInput(journalData, seal);
    }

    /// @notice Validates sender permissions for proof forwarding
    /// @param msgSender Caller address
    /// @param srcSender Source sender encoded in journal
    function _checkSender(address msgSender, address srcSender) private view {
        // If the caller is not the source sender
        if (msgSender != srcSender) {
            // Requirements: the sender must have permission to forward proof from the source sender
            require(
                allowedCallers[srcSender][msgSender] || msgSender == owner()
                    || _isAllowedFor(msgSender, _getProofForwarderRole())
                    || _isAllowedFor(msgSender, _getBatchProofForwarderRole()),
                mTokenGateway_CallerNotAllowed()
            );
        }
    }

    /// @notice Returns sequencer role identifier
    /// @return Role id
    function _getSequencerRole() private view returns (bytes32) {
        return rolesOperator.SEQUENCER();
    }

    /// @notice Returns batch proof forwarder role identifier
    /// @return Role id
    function _getBatchProofForwarderRole() private view returns (bytes32) {
        return rolesOperator.PROOF_BATCH_FORWARDER();
    }

    /// @notice Returns proof forwarder role identifier
    /// @return Role id
    function _getProofForwarderRole() private view returns (bytes32) {
        return rolesOperator.PROOF_FORWARDER();
    }

    /// @notice Checks if sender has a specific role
    /// @param _sender Sender address
    /// @param role Role to check
    /// @return True if allowed
    function _isAllowedFor(address _sender, bytes32 role) private view returns (bool) {
        return rolesOperator.isAllowedFor(_sender, role);
    }
}
