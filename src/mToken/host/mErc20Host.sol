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
        require(underlying_ != address(0), mErc20Host_AddressNotValid());
        require(operator_ != address(0), mErc20Host_AddressNotValid());
        require(interestRateModel_ != address(0), mErc20Host_AddressNotValid());
        require(zkVerifier_ != address(0), mErc20Host_AddressNotValid());
        require(roles_ != address(0), mErc20Host_AddressNotValid());
        require(admin_ != address(0), mErc20Host_AddressNotValid());

        // Initialize the base contract
        _proxyInitialize(
            underlying_, operator_, interestRateModel_, initialExchangeRateMantissa_, name_, symbol_, decimals_, admin_
        );

        verifier = IZkVerifier(zkVerifier_);

        rolesOperator = IRoles(roles_);

        // Set the proper admin now that initialization is done
        admin = admin_;
    }

    // solhint-enable gas-calldata-parameters

    // ----------- OWNER ------------
    /// @notice Updates an allowed chain status
    /// @param _chainId the chain id
    /// @param status_ the new status
    function updateAllowedChain(uint32 _chainId, bool status_) external {
        _onlyAdminOrRole(_getChainsManagerRole());

        allowedChains[_chainId] = status_;
        emit mErc20Host_ChainStatusUpdated(_chainId, status_);
    }

    /// @inheritdoc ImErc20Host
    function extractForRebalancing(uint256 amount) external {
        IOperatorDefender(operator).beforeRebalancing(address(this));

        if (!_isAllowedFor(msg.sender, rolesOperator.REBALANCER())) revert mErc20Host_NotRebalancer();
        IERC20(underlying).safeTransfer(msg.sender, amount);
    }

    /// @notice Sets the migrator address
    /// @param _migrator The new migrator address
    function setMigrator(address _migrator) external onlyAdmin {
        require(_migrator != address(0), mErc20Host_AddressNotValid());
        migrator = _migrator;
        emit mErc20Host_MigratorUpdated(_migrator);
    }

    /// @notice Sets the gas fees helper address
    /// @param _helper The new helper address
    function setGasHelper(address _helper) external onlyAdmin {
        require(_helper != address(0), mErc20Host_AddressNotValid());
        gasHelper = IGasFeesHelper(_helper);
    }

    /// @notice Withdraw gas received so far
    /// @param receiver the receiver address
    function withdrawGasFees(address payable receiver) external {
        _onlyAdminOrRole(_getSequencerRole());
        require(receiver != address(0), mErc20Host_AddressNotValid());

        uint256 balance = address(this).balance;
        receiver.transfer(balance);
    }

    /// @notice Updates IZkVerifier address
    /// @param _zkVerifier the verifier address
    function updateZkVerifier(address _zkVerifier) external onlyAdmin {
        require(_zkVerifier != address(0), mErc20Host_AddressNotValid());
        emit ZkVerifierUpdated(address(verifier), _zkVerifier);
        verifier = IZkVerifier(_zkVerifier);
    }

    // ----------- PUBLIC ------------
    /// @inheritdoc ImErc20Host
    function updateAllowedCallerStatus(address caller, bool status) external override {
        allowedCallers[msg.sender][caller] = status;
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
    ) external override {
        // verify received data
        if (!_isAllowedFor(msg.sender, _getBatchProofForwarderRole())) {
            _verifyProof(journalData, seal);
        }

        bytes[] memory journals = _decodeJournals(journalData);
        uint256 length = journals.length;
        CommonLib.checkLengthMatch(length, liquidateAmount.length);
        CommonLib.checkLengthMatch(length, userToLiquidate.length);
        CommonLib.checkLengthMatch(length, collateral.length);

        for (uint256 i; i < length;) {
            _liquidateExternal(journals[i], userToLiquidate[i], liquidateAmount[i], collateral[i], receiver);
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc ImErc20Host
    function mintExternal(
        bytes calldata journalData,
        bytes calldata seal,
        uint256[] calldata mintAmount,
        uint256[] calldata minAmountsOut,
        address receiver
    ) external override {
        if (!_isAllowedFor(msg.sender, _getBatchProofForwarderRole())) {
            _verifyProof(journalData, seal);
        }

        _checkOutflow(CommonLib.computeSum(mintAmount));

        bytes[] memory journals = _decodeJournals(journalData);
        uint256 length = journals.length;
        CommonLib.checkLengthMatch(length, mintAmount.length);

        for (uint256 i; i < length;) {
            _mintExternal(journals[i], mintAmount[i], minAmountsOut[i], receiver);
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc ImErc20Host
    function repayExternal(
        bytes calldata journalData,
        bytes calldata seal,
        uint256[] calldata repayAmount,
        address receiver
    ) external override {
        if (!_isAllowedFor(msg.sender, _getBatchProofForwarderRole())) {
            _verifyProof(journalData, seal);
        }

        _checkOutflow(CommonLib.computeSum(repayAmount));

        bytes[] memory journals = _decodeJournals(journalData);
        uint256 length = journals.length;
        CommonLib.checkLengthMatch(length, repayAmount.length);

        for (uint256 i; i < length;) {
            _repayExternal(journals[i], repayAmount[i], receiver);
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc ImErc20Host
    function performExtensionCall(uint256 actionType, uint256 amount, uint32 dstChainId) external payable override {
        //actionType:
        // 1 - withdraw
        // 2 - borrow
        CommonLib.checkHostToExtension(amount, dstChainId, msg.value, allowedChains, gasHelper);

        uint256 _amount = amount;
        if (actionType == 1) {
            _amount = _redeem(msg.sender, amount, false);
            emit mErc20Host_WithdrawOnExtensionChain(msg.sender, dstChainId, _amount);
        } else if (actionType == 2) {
            _borrow(msg.sender, amount, false);
            emit mErc20Host_BorrowOnExtensionChain(msg.sender, dstChainId, _amount);
        } else {
            revert mErc20Host_ActionNotAvailable();
        }
        acc[dstChainId].outPerChain[msg.sender] += _amount;
        _checkOutflow(_amount);
    }

    /// @inheritdoc ImErc20Host
    function mintOrBorrowMigration(bool isMint, uint256 amount, address receiver, address borrower, uint256 minAmount)
        external
        onlyMigrator
    {
        require(amount > 0, mErc20Host_AmountNotValid());

        if (isMint) {
            _mint(receiver, receiver, amount, minAmount, false);
            emit mErc20Host_MintMigration(receiver, amount);
        } else {
            _borrowWithReceiver(borrower, receiver, amount);
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
        (address _sender, address _market, uint256 _accAmountIn,, uint32 _chainId, uint32 _dstChainId,) =
            mTokenProofDecoderLib.decodeJournal(singleJournal);

        // temporary overwrite; will be removed in future implementations
        receiver = _sender;

        // base checks
        _checkProofCall(_dstChainId, _chainId, _market, _sender);

        // operation checks
        {
            require(liquidateAmount > 0, mErc20Host_AmountNotValid());
            require(liquidateAmount <= _accAmountIn - acc[_chainId].inPerChain[_sender], mErc20Host_AmountTooBig());
            require(userToLiquidate != msg.sender && userToLiquidate != _sender, mErc20Host_CallerNotAllowed());
        }
        collateral = collateral == address(0) ? address(this) : collateral;

        // actions
        acc[_chainId].inPerChain[_sender] += liquidateAmount;
        _liquidate(receiver, userToLiquidate, liquidateAmount, collateral, false);

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

        // temporary overwrite; will be removed in future implementations
        receiver = _sender;

        // base checks
        _checkProofCall(_dstChainId, _chainId, _market, _sender);

        // operation checks
        {
            require(mintAmount > 0, mErc20Host_AmountNotValid());
            require(mintAmount <= _accAmountIn - acc[_chainId].inPerChain[_sender], mErc20Host_AmountTooBig());
        }

        // actions
        acc[_chainId].inPerChain[_sender] += mintAmount;
        _mint(receiver, receiver, mintAmount, minAmountOut, false);

        emit mErc20Host_MintExternal(msg.sender, _sender, receiver, _chainId, mintAmount);
    }

    /// @notice Processes a single repayExternal call from decoded journal
    /// @param singleJournal Encoded journal entry
    /// @param repayAmount Amount to repay
    /// @param receiver Receiver address
    function _repayExternal(bytes memory singleJournal, uint256 repayAmount, address receiver) internal {
        (address _sender, address _market, uint256 _accAmountIn,, uint32 _chainId, uint32 _dstChainId,) =
            mTokenProofDecoderLib.decodeJournal(singleJournal);

        // temporary overwrite; will be removed in future implementations
        receiver = _sender;

        // base checks
        _checkProofCall(_dstChainId, _chainId, _market, _sender);

        // slither-disable-next-line reentrancy-benign -- _repayBehalf uses ReentrancyGuard in mToken
        uint256 actualRepayAmount = _repayBehalf(receiver, repayAmount, false);

        // operation checks
        {
            require(repayAmount > 0, mErc20Host_AmountNotValid());
            require(actualRepayAmount <= _accAmountIn - acc[_chainId].inPerChain[_sender], mErc20Host_AmountTooBig());
        }

        // actions
        acc[_chainId].inPerChain[_sender] += actualRepayAmount;

        emit mErc20Host_RepayExternal(msg.sender, _sender, receiver, _chainId, actualRepayAmount);
    }

    /// @notice Validates outflow limits via defender
    /// @param amount Amount to check
    function _checkOutflow(uint256 amount) internal {
        IOperatorDefender(operator).checkOutflowVolumeLimit(amount);
    }

    // ----------- PRIVATE ------------
    /// @notice Ensures caller is admin or has specific role
    /// @param _role Role identifier to check
    function _onlyAdminOrRole(bytes32 _role) internal view {
        if (msg.sender != admin && !_isAllowedFor(msg.sender, _role)) {
            revert mErc20Host_CallerNotAllowed();
        }
    }

    /// @notice Performs basic proof call checks
    /// @param dstChainId Destination chain id
    /// @param chainId Source chain id
    /// @param market Market address encoded in proof
    /// @param sender Sender extracted from proof
    function _checkProofCall(uint32 dstChainId, uint32 chainId, address market, address sender) internal view {
        _checkSender(msg.sender, sender);
        require(dstChainId == uint32(block.chainid), mErc20Host_DstChainNotValid());
        require(market == address(this), mErc20Host_AddressNotValid());
        require(allowedChains[chainId], mErc20Host_ChainNotValid());
    }

    /// @notice Ensures message sender matches source sender or has permission
    /// @param msgSender The current msg.sender
    /// @param srcSender Sender encoded in proof
    function _checkSender(address msgSender, address srcSender) internal view {
        if (msgSender != srcSender) {
            require(
                allowedCallers[srcSender][msgSender] || msgSender == admin
                    || _isAllowedFor(msgSender, _getProofForwarderRole())
                    || _isAllowedFor(msgSender, _getBatchProofForwarderRole()),
                mErc20Host_CallerNotAllowed()
            );
        }
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
        require(journalData.length > 0, mErc20Host_JournalNotValid());

        // Decode the dynamic array of journals.
        bytes[] memory journals = _decodeJournals(journalData);

        // Check the L1Inclusion flag for each journal.
        bool isSequencer = _isAllowedFor(msg.sender, _getProofForwarderRole())
            || _isAllowedFor(msg.sender, _getBatchProofForwarderRole());

        if (!isSequencer) {
            for (uint256 i = 0; i < journals.length; i++) {
                (,,,,,, bool l1Inclusion) = mTokenProofDecoderLib.decodeJournal(journals[i]);
                if (!l1Inclusion) {
                    revert mErc20Host_L1InclusionRequired();
                }
            }
        }

        // verify it using the IZkVerifier contract
        verifier.verifyInput(journalData, seal);
    }

    /// @notice Decodes encoded journals data
    /// @param data Encoded journal data
    /// @return Decoded journals array
    function _decodeJournals(bytes calldata data) internal pure returns (bytes[] memory) {
        return abi.decode(data, (bytes[]));
    }
}
