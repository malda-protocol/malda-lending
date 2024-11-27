// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

// interfaces
import {IZkVerifierImageRegistry} from "src/interfaces/IZkVerifierImageRegistry.sol";

import {Steel} from "risc0/steel/Steel.sol";

// contracts
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";
import {mErc20Immutable} from "src/mToken/mErc20Immutable.sol";

import {BytesLib} from "src/libraries/BytesLib.sol";

import {ImErc20Host} from "src/interfaces/ImErc20Host.sol";
import {ImTokenLogs} from "src/interfaces/ImTokenLogs.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

contract mErc20Host is mErc20Immutable, ZkVerifier, ImErc20Host, ImTokenOperationTypes {
    // ----------- STORAGE ------------
    // user -> chainId -> operation type -> nonce
    mapping(address => mapping(uint32 => mapping(OperationType => uint32))) public nonces;

    /**
     * @inheritdoc ImErc20Host
     */
    ImTokenLogs public logsOperator;

    /**
     * @notice Constructs the new money market
     * @param underlying_ The address of the underlying asset
     * @param operator_ The address of the Operator
     * @param interestRateModel_ The address of the interest rate model
     * @param initialExchangeRateMantissa_ The initial exchange rate, scaled by 1e18
     * @param name_ ERC-20 name of this token
     * @param symbol_ ERC-20 symbol of this token
     * @param decimals_ ERC-20 decimal precision of this token
     * @param admin_ Address of the administrator of this token
     * @param zkVerifier_ The IRiscZeroVerifier address
     * @param zkVerifierImageRegistry_ The IZkVerifierImageRegistry address
     */
    constructor(
        address underlying_,
        address operator_,
        address interestRateModel_,
        uint256 initialExchangeRateMantissa_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address payable admin_,
        address zkVerifier_,
        address zkVerifierImageRegistry_,
        address logs_
    )
        mErc20Immutable(
            underlying_,
            operator_,
            interestRateModel_,
            initialExchangeRateMantissa_,
            name_,
            symbol_,
            decimals_,
            admin_
        )
    {
        // Initialize the ZkVerifier
        ZkVerifier.initialize(zkVerifier_, zkVerifierImageRegistry_);

        logsOperator = ImTokenLogs(logs_);

        // Set the proper admin now that initialization is done
        admin = admin_;
    }

    // ----------- VIEW ------------
    /**
     * @inheritdoc ImErc20Host
     */
    function getNonce(address user, uint32 chainId, OperationType opType) external view returns (uint32) {
        return nonces[user][chainId][opType];
    }

    // ----------- OWNER ------------
    /**
     * @notice Sets the _risc0Verifier address
     * @param _risc0Verifier the new IRiscZeroVerifier address
     */
    function setVerifier(address _risc0Verifier) external onlyAdmin {
        _setVerifier(_risc0Verifier);
    }

    /**
     * @notice Sets the ZkVerifierImageRegistry
     * @param _imageRegistry the new image registry address
     */
    function setVerifierImageRegistry(address _imageRegistry) external onlyAdmin {
        _setVerifierImageRegistry(_imageRegistry);
    }

    // ----------- PUBLIC ------------
    /**
     * @inheritdoc ImErc20Host
     */
    function mintExternal(bytes calldata journalData, bytes calldata seal) external override {
        // verify received data
        _verifyProof(OperationType.Mint, journalData, seal);

        // decode action data
        // | Offset | Length | Data Type       |
        // |--------|--------|-----------------|
        // | 0     | 32     | uint256 mintAmount  |
        // | 32    | 20     | address user    |
        // | 52    | 4      | uint32 nonce    |
        // | 56    | 4      | uint32 chainId  |
        uint256 mintAmount = BytesLib.toUint256(BytesLib.slice(journalData, 0, 32), 0);
        address user = BytesLib.toAddress(BytesLib.slice(journalData, 32, 20), 0);
        uint32 nonce = BytesLib.toUint32(BytesLib.slice(journalData, 52, 4), 0);
        uint32 chainId = BytesLib.toUint32(BytesLib.slice(journalData, 56, 4), 0);

        // checks
        _checkSender(msg.sender, user);
        require(mintAmount > 0, mErc20Host_AmountNotValid());
        uint32 _nonce = _getNonce(user, chainId, OperationType.Mint);
        require(_nonce == nonce, mErc20Host_NonceNotValid());

        // actions
        _increaseNonce(user, chainId, OperationType.Mint);
        _mint(user, mintAmount, false);

        logsOperator.registerLog(
            msg.sender,
            OperationType.Mint,
            chainId,
            uint32(block.chainid),
            nonce,
            abi.encodePacked(mintAmount, msg.sender, nonce, chainId)
        );
        emit mErc20Host_MintExternal(msg.sender, user, mintAmount, _nonce, chainId);
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function borrowExternal(bytes calldata journalData, bytes calldata seal) external override {
        // verify received data
        _verifyProof(OperationType.Borrow, journalData, seal);

        // decode action data
        // | Offset | Length | Data Type       |
        // |--------|--------|-----------------|
        // | 0     | 32     | uint256 borrowAmount  |
        // | 32    | 20     | address user    |
        // | 52    | 4      | uint32 nonce    |
        // | 56    | 4      | uint32 chainId  |
        uint256 borrowAmount = BytesLib.toUint256(BytesLib.slice(journalData, 0, 32), 0);
        address user = BytesLib.toAddress(BytesLib.slice(journalData, 32, 20), 0);
        uint32 nonce = BytesLib.toUint32(BytesLib.slice(journalData, 52, 4), 0);
        uint32 chainId = BytesLib.toUint32(BytesLib.slice(journalData, 56, 4), 0);

        // checks
        _checkSender(msg.sender, user);

        require(borrowAmount > 0, mErc20Host_AmountNotValid());
        uint32 _nonce = _getNonce(user, chainId, OperationType.Borrow);
        require(_nonce == nonce, mErc20Host_NonceNotValid());

        // actions
        _increaseNonce(user, chainId, OperationType.Borrow);
        _borrow(user, borrowAmount, true);

        logsOperator.registerLog(
            msg.sender,
            OperationType.Borrow,
            chainId,
            uint32(block.chainid),
            nonce,
            abi.encodePacked(borrowAmount, msg.sender, nonce, chainId)
        );
        emit mErc20Host_BorrowExternal(msg.sender, user, borrowAmount, _nonce, chainId);
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function borrowOnExtension(uint256 amount, bytes calldata journalData, bytes calldata seal) external override {
        // verify received data
        _verifyProof(OperationType.BorrowOnOtherChain, journalData, seal);

        // decode action data
        // | Offset | Length | Data Type       |
        // |--------|--------|-----------------|
        // | 0     | 32     | uint256 liquidity  |
        // | 32    | 20     | address user    |
        // | 52    | 4      | uint32 dstChainId  |
        uint256 liquidity = BytesLib.toUint256(BytesLib.slice(journalData, 0, 32), 0);
        address user = BytesLib.toAddress(BytesLib.slice(journalData, 32, 20), 0);
        uint32 dstChainId = BytesLib.toUint32(BytesLib.slice(journalData, 52, 4), 0);

        // checks
        _checkSender(msg.sender, user);
        require(liquidity > 0 && amount > 0 && amount <= liquidity, mErc20Host_AmountNotValid());

        // actions
        uint32 _nonce = _getNonce(user, uint32(block.chainid), OperationType.BorrowOnOtherChain);
        _increaseNonce(user, uint32(block.chainid), OperationType.BorrowOnOtherChain);
        _borrow(user, amount, false);

        logsOperator.registerLog(
            user,
            OperationType.BorrowOnOtherChain,
            uint32(block.chainid),
            dstChainId,
            _nonce,
            abi.encodePacked(amount, user, _nonce, uint32(block.chainid))
        );
        emit mErc20Host_BorrowOnExternsionChain(msg.sender, user, amount, _nonce, dstChainId);
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function repayExternal(bytes calldata journalData, bytes calldata seal) external override {
        // verify received data
        _verifyProof(OperationType.Repay, journalData, seal);

        // decode action data
        // | Offset | Length | Data Type       |
        // |--------|--------|-----------------|
        // | 0     | 32     | uint256 repayAmount  |
        // | 32    | 20     | address borrower    |
        // | 52    | 4      | uint32 nonce    |
        // | 56    | 4      | uint32 chainId  |
        uint256 repayAmount = BytesLib.toUint256(BytesLib.slice(journalData, 0, 32), 0);
        address borrower = BytesLib.toAddress(BytesLib.slice(journalData, 32, 20), 0);
        uint32 nonce = BytesLib.toUint32(BytesLib.slice(journalData, 52, 4), 0);
        uint32 chainId = BytesLib.toUint32(BytesLib.slice(journalData, 56, 4), 0);

        // checks
        _checkSender(msg.sender, borrower);
        require(repayAmount > 0, mErc20Host_AmountNotValid());
        uint32 _nonce = _getNonce(borrower, chainId, OperationType.Repay);
        require(_nonce == nonce, mErc20Host_NonceNotValid());

        // actions
        _increaseNonce(borrower, chainId, OperationType.Repay);
        _repayBehalf(borrower, repayAmount, false);

        logsOperator.registerLog(
            msg.sender,
            OperationType.Repay,
            chainId,
            uint32(block.chainid),
            nonce,
            abi.encodePacked(repayAmount, msg.sender, nonce, chainId)
        );
        emit mErc20Host_RepayExternal(msg.sender, borrower, repayAmount, _nonce, chainId);
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function withdrawExternal(bytes calldata journalData, bytes calldata seal) external override {
        // verify received data
        _verifyProof(OperationType.Redeem, journalData, seal);

        // decode action data
        // | Offset | Length | Data Type       |
        // |--------|--------|-----------------|
        // | 0     | 32     | uint256 amount  |
        // | 32    | 20     | address user    |
        // | 52    | 4      | uint32 nonce    |
        // | 56    | 4      | uint32 chainId  |
        uint256 amount = BytesLib.toUint256(BytesLib.slice(journalData, 0, 32), 0);
        address user = BytesLib.toAddress(BytesLib.slice(journalData, 32, 20), 0);
        uint32 nonce = BytesLib.toUint32(BytesLib.slice(journalData, 52, 4), 0);
        uint32 chainId = BytesLib.toUint32(BytesLib.slice(journalData, 56, 4), 0);

        // checks
        _checkSender(msg.sender, user);
        require(amount > 0, mErc20Host_AmountNotValid());
        uint32 _nonce = _getNonce(user, chainId, OperationType.Redeem);
        require(_nonce == nonce, mErc20Host_NonceNotValid());

        // actions
        _increaseNonce(user, chainId, OperationType.Redeem);
        _redeem(user, amount, true);

        logsOperator.registerLog(
            msg.sender,
            OperationType.Redeem,
            chainId,
            uint32(block.chainid),
            nonce,
            abi.encodePacked(amount, msg.sender, nonce, chainId)
        );
        emit mErc20Host_WithdrawExternal(msg.sender, user, amount, _nonce, chainId);
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function withdrawOnExtension(uint256 amount, bytes calldata journalData, bytes calldata seal) external override {
        // verify received data
        _verifyProof(OperationType.RedeemOnOtherChain, journalData, seal);

        // decode action data
        // | Offset | Length | Data Type       |
        // |--------|--------|-----------------|
        // | 0     | 32     | uint256 liquidity  |
        // | 32    | 20     | address user    |
        // | 52    | 4      | uint32 dstChainId  |
        uint256 liquidity = BytesLib.toUint256(BytesLib.slice(journalData, 0, 32), 0);
        address user = BytesLib.toAddress(BytesLib.slice(journalData, 32, 20), 0);
        uint32 dstChainId = BytesLib.toUint32(BytesLib.slice(journalData, 52, 4), 0);

        // checks
        _checkSender(msg.sender, user);
        require(liquidity > 0 && amount > 0 && amount <= liquidity, mErc20Host_AmountNotValid());

        // actions
        uint32 _nonce = _getNonce(user, uint32(block.chainid), OperationType.RedeemOnOtherChain);
        _increaseNonce(user, uint32(block.chainid), OperationType.RedeemOnOtherChain);
        _redeem(user, amount, false);

        logsOperator.registerLog(
            user,
            OperationType.RedeemOnOtherChain,
            uint32(block.chainid),
            dstChainId,
            _nonce,
            abi.encodePacked(amount, user, _nonce, uint32(block.chainid))
        );
        emit mErc20Host_WithdrawOnExtensionChain(msg.sender, user, amount, _nonce, dstChainId);
    }

    // ----------- PRIVATE ------------
    function _verifyProof(OperationType imageType, bytes calldata journalData, bytes calldata seal) private {
        require(journalData.length > 0, mErc20Host_JournalNotValid());

        // verify it using the ZkVerifier contract
        _verifyInput(journalData, seal, uint256(imageType));
    }

    function _getNonce(address from, uint32 chainId, OperationType operation) private view returns (uint32) {
        return nonces[from][chainId][operation];
    }

    function _increaseNonce(address from, uint32 chainId, OperationType operation) private {
        nonces[from][chainId][operation]++;
    }

    function _checkSender(address sender, address user) private view {
        if (sender != user) {
            require(
                sender == admin || rolesOperator.isAllowedFor(sender, rolesOperator.PROOF_FORWARDER()),
                mErc20Host_CallerNotAllowed()
            );
        }
    }
}
