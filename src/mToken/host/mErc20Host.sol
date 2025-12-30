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

// interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// contracts
import {IZkVerifier} from "src/verifier/ZkVerifier.sol";
import {mErc20Upgradable} from "src/mToken/mErc20Upgradable.sol";

import {mTokenProofDecoderLib} from "src/libraries/mTokenProofDecoderLib.sol";

import {IRoles} from "src/interfaces/IRoles.sol";
import {ImErc20Host} from "src/interfaces/ImErc20Host.sol";
import {IOperatorDefender} from "src/interfaces/IOperator.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";
import {IGasFeesHelper} from "src/interfaces/IGasFeesHelper.sol";
import {CommonLib} from "src/libraries/CommonLib.sol";

/// @title mErc20Host
/// @author Merge Layers Inc.
/// @notice Host contract for mErc20 tokens
contract mErc20Host is mErc20Upgradable, ImErc20Host, ImTokenOperationTypes {
    using SafeERC20 for IERC20;

    // ----------- STORAGE ------------
    /// @notice Struct for accumulated amounts per chain
    struct Accumulated {
        mapping(address chain => uint256 amount) inPerChain;
        mapping(address chain => uint256 amount) outPerChain;
    }

    /// @notice Mapping of chain IDs to accumulated amounts
    mapping(uint32 chainId => Accumulated accumulated) internal acc;

    /// @notice Mapping of allowed callers
    mapping(address caller => mapping(address target => bool allowed)) public allowedCallers;

    /// @notice Mapping of allowed chains
    mapping(uint32 chainId => bool allowed) public allowedChains;

    /// @notice The ZkVerifier contract
    IZkVerifier public verifier;

    /// @notice The gas fees helper contract
    IGasFeesHelper public gasHelper;

    /// @notice Migrator address
    address public migrator;

    // slither-disable-next-line unused-state
    uint256[50] private __gap;

    // ----------- MODIFIERS ------------

    /// @notice Modifier to restrict access to migrator only
    modifier onlyMigrator() {
        require(msg.sender == migrator, mErc20Host_CallerNotAllowed());
        _;
    }

    // solhint-disable gas-calldata-parameters
    /// @notice Initializes the new money market
    /// @param underlying_ The address of the underlying asset
    /// @param operator_ The address of the Operator
    /// @param interestRateModel_ The address of the interest rate model
    /// @param initialExchangeRateMantissa_ The initial exchange rate, scaled by 1e18
    /// @param name_ ERC-20 name of this token
    /// @param symbol_ ERC-20 symbol of this token
    /// @param decimals_ ERC-20 decimal precision of this token
    /// @param admin_ Address of the administrator of this token
    /// @param zkVerifier_ The IZkVerifier address
    /// @param roles_ The IRoles address
    function initialize(
        address underlying_,
        address operator_,
        address interestRateModel_,
        uint256 initialExchangeRateMantissa_,
        // note: these have to remain as 'memory' to avoid stack-depth issues
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address payable admin_,
        address zkVerifier_,
        address roles_
    ) external initializer {
        // Requirements: the underlying, operator, interest rate model, ZkVerifier, roles, and admin are not zero addresses
        require(
            underlying_ != address(0) && operator_ != address(0) && interestRateModel_ != address(0)
                && zkVerifier_ != address(0) && roles_ != address(0) && admin_ != address(0),
            mErc20Host_AddressNotValid()
        );

        // Effects: set the ZkVerifier
        verifier = IZkVerifier(zkVerifier_);

        // Effects: set the roles
        rolesOperator = IRoles(roles_);

        // Initialize the base contract
        _proxyInitialize(
            underlying_, operator_, interestRateModel_, initialExchangeRateMantissa_, name_, symbol_, decimals_, admin_
        );
    }

    // solhint-enable gas-calldata-parameters
    // ----------- OWNER ------------
    /// @notice Inits firewall
    /// @param _firewall The firewall address
    function initFirewall(address _firewall) external onlyAdmin {
        _initHypernativeFirewall(_firewall, admin);
    }

    /// @notice Updates an allowed chain status
    /// @param _chainId the chain id
    /// @param status_ the new status
    function updateAllowedChain(uint32 _chainId, bool status_) external {
        // Requirements: the caller is admin or has chains manager role
        _onlyAdminOrRole(_getChainsManagerRole());

        // Effects: set the allowed chain status
        allowedChains[_chainId] = status_;

        // Events: emit the chain status updated event
        emit mErc20Host_ChainStatusUpdated(_chainId, status_);
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function extractForRebalancing(uint256 amount) external onlyFirewallApprovedAllowEOA {
        // Interactions: check if rebalancing is paused
        IOperatorDefender(operator).beforeRebalancing(address(this));

        // Requirements: the sender is allowed for rebalancer
        require(_isAllowedFor(msg.sender, rolesOperator.REBALANCER()), mErc20Host_NotRebalancer());

        // Interactions: transfer the underlying to the sender
        IERC20(underlying).safeTransfer(msg.sender, amount);
    }

    /// @notice Sets the migrator address
    /// @param _migrator The new migrator address
    function setMigrator(address _migrator) external onlyAdmin {
        // Requirements: the migrator is not zero address
        require(_migrator != address(0), mErc20Host_AddressNotValid());

        // Effects: set the migrator
        // slither-disable-next-line events-access
        migrator = _migrator;
    }

    /// @notice Sets the gas fees helper address
    /// @param _helper The new helper address
    function setGasHelper(address _helper) external onlyAdmin {
        // Requirements: the helper is not zero address
        require(_helper != address(0), mErc20Host_AddressNotValid());

        // Effects: set the gas helper
        gasHelper = IGasFeesHelper(_helper);
    }

    /// @notice Withdraw gas received so far
    /// @param receiver the receiver address
    function withdrawGasFees(address payable receiver) external {
        // Requirements: the caller is admin or has sequencer role
        _onlyAdminOrRole(_getSequencerRole());

        // Requirements: the receiver is not zero address
        require(receiver != address(0), mErc20Host_AddressNotValid());

        // Interactions: transfer the gas fees to the receiver
        receiver.transfer(address(this).balance);
    }

    /// @notice Updates IZkVerifier address
    /// @param _zkVerifier the verifier address
    function updateZkVerifier(address _zkVerifier) external onlyAdmin {
        // Requirements: the ZkVerifier is not zero address
        require(_zkVerifier != address(0), mErc20Host_AddressNotValid());

        // Events: emit the ZkVerifier updated event
        emit ZkVerifierUpdated(address(verifier), _zkVerifier);

        // Effects: set the ZkVerifier
        verifier = IZkVerifier(_zkVerifier);
    }

    // ----------- PUBLIC ------------
    /// @inheritdoc ImErc20Host
    function updateAllowedCallerStatus(address caller, bool status) external override {
        // Effects: set the allowed caller status
        allowedCallers[msg.sender][caller] = status;

        // Events: emit the allowed caller updated event
        emit AllowedCallerUpdated(msg.sender, caller, status);
    }

    /// @inheritdoc ImErc20Host
    function liquidateExternal(
        bytes calldata journalData,
        bytes calldata seal,
        address[] calldata userToLiquidate,
        uint256[] calldata liquidateAmount,
        address[] calldata collateral,
        address receiver
    ) external override onlyFirewallApprovedAllowEOA {
        // If the sender is not the batch proof forwarder (e.g. self-sequencing), verify the proof
        if (!_isAllowedFor(msg.sender, _getBatchProofForwarderRole())) {
            _verifyProof(journalData, seal);
        }

        // Decode the dynamic array of journals.
        bytes[] memory journals = _decodeJournals(journalData);

        // Check the length of the journals, liquidate amount, user to liquidate, and collateral.
        uint256 length = journals.length;
        CommonLib.checkLengthMatch(length, liquidateAmount.length);
        CommonLib.checkLengthMatch(length, userToLiquidate.length);
        CommonLib.checkLengthMatch(length, collateral.length);

        // Process each journal
        for (uint256 i; i < length; i++) {
            // Interactions: liquidate the external
            _liquidateExternal(journals[i], userToLiquidate[i], liquidateAmount[i], collateral[i], receiver);
        }
    }

    /// @inheritdoc ImErc20Host
    function mintExternal(
        bytes calldata journalData,
        bytes calldata seal,
        uint256[] calldata mintAmount,
        uint256[] calldata minAmountsOut,
        address receiver
    ) external override onlyFirewallApprovedAllowEOA {
        // If the sender is not the batch proof forwarder (e.g. self-sequencing), verify the proof
        if (!_isAllowedFor(msg.sender, _getBatchProofForwarderRole())) {
            _verifyProof(journalData, seal);
        }

        // Interactions: check the outflow volume limit
        _checkOutflow(CommonLib.computeSum(mintAmount));

        // Decode the dynamic array of journals.
        bytes[] memory journals = _decodeJournals(journalData);

        // Check the length of the journals and mint amount.
        uint256 length = journals.length;
        CommonLib.checkLengthMatch(length, mintAmount.length);

        // Process each journal
        for (uint256 i; i < length; i++) {
            // Interactions: mint the external
            _mintExternal(journals[i], mintAmount[i], minAmountsOut[i], receiver);
        }
    }

    /// @inheritdoc ImErc20Host
    function repayExternal(
        bytes calldata journalData,
        bytes calldata seal,
        uint256[] calldata repayAmount,
        address receiver
    ) external override onlyFirewallApprovedAllowEOA {
        // If the sender is not the batch proof forwarder (e.g. self-sequencing), verify the proof
        if (!_isAllowedFor(msg.sender, _getBatchProofForwarderRole())) {
            _verifyProof(journalData, seal);
        }

        // Interactions: check the outflow volume limit
        _checkOutflow(CommonLib.computeSum(repayAmount));

        // Decode the dynamic array of journals.
        bytes[] memory journals = _decodeJournals(journalData);

        // Check the length of the journals and repay amount.
        uint256 length = journals.length;
        CommonLib.checkLengthMatch(length, repayAmount.length);

        // Process each journal
        for (uint256 i; i < length; i++) {
            // Interactions: repay the external
            _repayExternal(journals[i], repayAmount[i], receiver);
        }
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function performExtensionCall(uint256 actionType, uint256 amount, uint32 dstChainId)
        external
        payable
        override
        onlyFirewallApprovedAllowEOA
    {
        // actionType:
        // 1 - withdraw
        // 2 - borrow

        // Interactions: check the host to extension call
        CommonLib.checkHostToExtension(amount, dstChainId, msg.value, allowedChains, gasHelper);

        // Effects: set the amount
        uint256 _amount = amount;

        if (actionType == 1) {
            // Interactions: withdraw the external
            _amount = _redeem(msg.sender, amount, false);
            // Events: emit the withdraw on extension chain event
            emit mErc20Host_WithdrawOnExtensionChain(msg.sender, dstChainId, _amount);
        } else if (actionType == 2) {
            // Interactions: borrow the external
            _borrow(msg.sender, amount, false);
            // Events: emit the borrow on extension chain event
            emit mErc20Host_BorrowOnExtensionChain(msg.sender, dstChainId, _amount);
        } else {
            // Invalid action
            revert mErc20Host_ActionNotAvailable();
        }

        // Effects: update the accumulated amount out for the sender
        acc[dstChainId].outPerChain[msg.sender] += _amount;

        // Interactions: check the outflow volume limit
        _checkOutflow(_amount);
    }

    /// @inheritdoc ImErc20Host
    function mintOrBorrowMigration(bool isMint, uint256 amount, address receiver, address borrower, uint256 minAmount)
        external
        onlyMigrator
        onlyFirewallApprovedAllowEOA
    {
        // Requirements: the amount is greater than 0
        require(amount > 0, mErc20Host_AmountNotValid());

        if (isMint) {
            // Interactions: mint for the receiver
            _mint(receiver, receiver, amount, minAmount, false);
            // Events: emit the mint migration event
            emit mErc20Host_MintMigration(receiver, amount);
        } else {
            // Interactions: borrow for the receiver
            _borrowWithReceiver(borrower, receiver, amount);
            // Events: emit the borrow migration event
            emit mErc20Host_BorrowMigration(borrower, amount);
        }
    }

    // ----------- VIEW ------------
    /// @inheritdoc ImErc20Host
    function getProofData(address user, uint32 dstId) external view returns (uint256, uint256) {
        return (acc[dstId].inPerChain[user], acc[dstId].outPerChain[user]);
    }

    // ----------- INTERNAL ------------
    /// @notice Processes a single liquidateExternal call from decoded journal
    /// @param singleJournal Encoded journal entry
    /// @param userToLiquidate Account to be liquidated
    /// @param liquidateAmount Amount to liquidate
    /// @param collateral Collateral address to seize
    /// @param receiver Receiver of seized collateral
    function _liquidateExternal(
        bytes memory singleJournal,
        address userToLiquidate,
        uint256 liquidateAmount,
        address collateral,
        address receiver
    ) internal {
        // Decode the journal entry
        (address _sender, address _market, uint256 _accAmountIn,, uint32 _chainId, uint32 _dstChainId,) =
            mTokenProofDecoderLib.decodeJournal(singleJournal);

        // TODO @Cosmin Keep until we allow self-sequencing
        // temporary overwrite; will be removed in future implementations
        receiver = _sender;

        // Requirements: check the journal data
        _checkJournalData(_dstChainId, _chainId, _market, _sender);

        // Requirements: the liquidate amount is greater than 0
        require(liquidateAmount > 0, mErc20Host_AmountNotValid());

        // Requirements: amount to be liquidated is not greater than what the user can liquidate
        require(liquidateAmount <= _accAmountIn - acc[_chainId].inPerChain[_sender], mErc20Host_AmountTooBig());

        // Requirements: the user to liquidate is not the msg.sender or the sender (prevents self-liquidation)
        require(userToLiquidate != msg.sender && userToLiquidate != _sender, mErc20Host_CallerNotAllowed());

        // If the collateral is not set, set it to the host market
        collateral = collateral == address(0) ? address(this) : collateral;

        // Effects: update the accumulated amount in for the sender
        acc[_chainId].inPerChain[_sender] += liquidateAmount;

        // Interactions: liquidate the external
        _liquidate(receiver, userToLiquidate, liquidateAmount, collateral, false);

        // Events: emit the liquidate external event
        emit mErc20Host_LiquidateExternal(
            msg.sender, _sender, userToLiquidate, receiver, collateral, _chainId, liquidateAmount
        );
    }

    /// @notice Processes a single mintExternal call from decoded journal
    /// @param singleJournal Encoded journal entry
    /// @param mintAmount Amount to mint
    /// @param minAmountOut Minimum amount out allowed
    /// @param receiver Receiver address
    function _mintExternal(bytes memory singleJournal, uint256 mintAmount, uint256 minAmountOut, address receiver)
        internal
    {
        (address _sender, address _market, uint256 _accAmountIn,, uint32 _chainId, uint32 _dstChainId,) =
            mTokenProofDecoderLib.decodeJournal(singleJournal);

        // TODO @Cosmin Keep until we allow self-sequencing
        // temporary overwrite; will be removed in future implementations
        receiver = _sender;

        // Requirements: check the journal data
        _checkJournalData(_dstChainId, _chainId, _market, _sender);

        // Requirements: the mint amount is greater than 0
        require(mintAmount > 0, mErc20Host_AmountNotValid());

        // Requirements: amount to be minted is not greater than what the user can mint
        require(mintAmount <= _accAmountIn - acc[_chainId].inPerChain[_sender], mErc20Host_AmountTooBig());

        // Effects: update the accumulated amount in for the sender
        acc[_chainId].inPerChain[_sender] += mintAmount;

        // Effects: mint the external
        _mint(receiver, receiver, mintAmount, minAmountOut, false);

        // Events: emit the mint external event
        emit mErc20Host_MintExternal(msg.sender, _sender, receiver, _chainId, mintAmount);
    }

    /// @notice Processes a single repayExternal call from decoded journal
    /// @param singleJournal Encoded journal entry
    /// @param repayAmount Amount to repay
    /// @param receiver Receiver address
    function _repayExternal(bytes memory singleJournal, uint256 repayAmount, address receiver) internal {
        (address _sender, address _market, uint256 _accAmountIn,, uint32 _chainId, uint32 _dstChainId,) =
            mTokenProofDecoderLib.decodeJournal(singleJournal);

        // TODO @Cosmin Keep until we allow self-sequencing
        // temporary overwrite; will be removed in future implementations
        receiver = _sender;

        // Requirements: check the journal data
        _checkJournalData(_dstChainId, _chainId, _market, _sender);

        // Requirements: amount to be repaid is greater than 0
        require(repayAmount > 0, mErc20Host_AmountNotValid());

        // slither-disable-next-line reentrancy-benign -- _repayBehalf uses ReentrancyGuard in mToken
        uint256 actualRepayAmount = _repayBehalf(receiver, repayAmount, false);
        // Requirements: amount to be repaid is not greater than what the user can repay
        require(actualRepayAmount <= _accAmountIn - acc[_chainId].inPerChain[_sender], mErc20Host_AmountTooBig());

        // Effects: update the accumulated amount in for the sender
        acc[_chainId].inPerChain[_sender] += actualRepayAmount;

        // Events: emit the repay external event
        emit mErc20Host_RepayExternal(msg.sender, _sender, receiver, _chainId, actualRepayAmount);
    }

    // ----------- INTERNAL ------------
    /// @notice Validates outflow limits via defender
    /// @param amount Amount to check
    function _checkOutflow(uint256 amount) internal {
        IOperatorDefender(operator).checkOutflowVolumeLimit(amount);
    }

    /// @notice Ensures caller is admin or has specific role
    /// @param _role Role identifier to check
    function _onlyAdminOrRole(bytes32 _role) internal view {
        // Requirements: the caller is admin or has the specified role
        require(msg.sender == admin || _isAllowedFor(msg.sender, _role), mErc20Host_CallerNotAllowed());
    }

    /// @notice Performs basic proof call checks
    /// @param dstChainId Destination chain id
    /// @param chainId Source chain id
    /// @param market Market address encoded in proof
    /// @param sender Sender extracted from proof
    function _checkJournalData(uint32 dstChainId, uint32 chainId, address market, address sender) internal view {
        // If the sender is not the source sender, check if the sender is allowed
        if (msg.sender != sender) {
            // Requirements: the sender must have permission to forward proof from the source sender
            require(
                allowedCallers[sender][msg.sender] || msg.sender == admin
                    || _isAllowedFor(msg.sender, _getProofForwarderRole())
                    || _isAllowedFor(msg.sender, _getBatchProofForwarderRole()),
                mErc20Host_CallerNotAllowed()
            );
        }

        // Requirements: the destination chain is the current chain (Linea)
        require(dstChainId == uint32(block.chainid), mErc20Host_DstChainNotValid());

        // Requirements: the market is this host market
        require(market == address(this), mErc20Host_AddressNotValid());

        // Requirements: the source chain is allowed
        require(allowedChains[chainId], mErc20Host_ChainNotValid());
    }

    /// @notice Checks if sender has specified role
    /// @param _sender Address to check
    /// @param role Role identifier
    /// @return True if allowed
    function _isAllowedFor(address _sender, bytes32 role) internal view returns (bool) {
        return rolesOperator.isAllowedFor(_sender, role);
    }

    /// @notice Retrieves chains manager role id
    /// @return Role identifier
    function _getChainsManagerRole() internal view returns (bytes32) {
        return rolesOperator.CHAINS_MANAGER();
    }

    /// @notice Retrieves proof forwarder role id
    /// @return Role identifier
    function _getProofForwarderRole() internal view returns (bytes32) {
        return rolesOperator.PROOF_FORWARDER();
    }

    /// @notice Retrieves batch proof forwarder role id
    /// @return Role identifier
    function _getBatchProofForwarderRole() internal view returns (bytes32) {
        return rolesOperator.PROOF_BATCH_FORWARDER();
    }

    /// @notice Retrieves sequencer role id
    /// @return Role identifier
    function _getSequencerRole() internal view returns (bytes32) {
        return rolesOperator.SEQUENCER();
    }

    /// @notice Verifies proof data and checks inclusion constraints
    /// @param journalData Encoded journal data
    /// @param seal Zk proof seal
    function _verifyProof(bytes calldata journalData, bytes calldata seal) internal view {
        // Requirements: the journal data is not empty
        require(journalData.length > 0, mErc20Host_JournalNotValid());

        // Decode the dynamic array of journals.
        bytes[] memory journals = _decodeJournals(journalData);

        // Check the L1Inclusion flag for each journal.
        bool isSequencer = _isAllowedFor(msg.sender, _getProofForwarderRole())
            || _isAllowedFor(msg.sender, _getBatchProofForwarderRole());

        if (!isSequencer) {
            for (uint256 i = 0; i < journals.length; i++) {
                (,,,,,, bool l1Inclusion) = mTokenProofDecoderLib.decodeJournal(journals[i]);

                // Requirements: the L1 inclusion is required
                require(l1Inclusion, mErc20Host_L1InclusionRequired());
            }
        }

        // Interactions: verify the proof using the ZkVerifier contract
        verifier.verifyInput(journalData, seal);
    }

    /// @notice Decodes encoded journals data
    /// @param data Encoded journal data
    /// @return Decoded journals array
    function _decodeJournals(bytes calldata data) internal pure returns (bytes[] memory) {
        return abi.decode(data, (bytes[]));
    }
}
