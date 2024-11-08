// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

// interfaces
import {IZkVerifierImageRegistry} from "../../interfaces/IZkVerifierImageRegistry.sol";

import {Steel} from "risc0/steel/Steel.sol";

// contracts
import {mErc20Immutable} from "../mErc20Immutable.sol";
import {ZkVerifier} from "../../verifier/ZkVerifier.sol";

import {ImErc20Host} from "../../interfaces/ImErc20Host.sol";

contract mErc20Host is mErc20Immutable, ZkVerifier, ImErc20Host {
    // ----------- STORAGE ------------
    // user -> chainId -> operation type -> nonce
    mapping(address => mapping(uint256 => mapping(OperationType => uint256))) public nonces;
    // user -> chainId -> operation type -> LogData
    mapping(address => mapping(uint256 => mapping(OperationType => LogData[]))) public logs;

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
        address zkVerifierImageRegistry_
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

        // Set the proper admin now that initialization is done
        admin = admin_;
    }

    // ----------- VIEW ------------
    /**
     * @inheritdoc ImErc20Host
     */
    function getNonce(address user, uint256 chainId, OperationType opType) external view returns (uint256) {
        return nonces[user][chainId][opType];
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function getLogsAt(address user, uint256 chainId, OperationType opType, uint256 index)
        external
        view
        returns (LogData memory)
    {
        return logs[user][chainId][opType][index];
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function getLogsLength(address user, uint256 chainId, OperationType opType) external view returns (uint256) {
        return logs[user][chainId][opType].length;
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
        _verifyProof(ImageIdIndexes.Mint, journalData, seal);

        // decode action data
        (uint256 mintAmount, address user, uint256 nonce, uint256 chainId) =
            abi.decode(journalData[96:], (uint256, address, uint256, uint256));

        // checks
        _checkSender(msg.sender, user);
        require(mintAmount > 0, mErc20Host_AmountNotValid());
        uint256 _nonce = _getNonce(user, chainId, OperationType.Mint);
        require(_nonce == nonce, mErc20Host_NonceNotValid());

        // actions
        _increaseNonce(user, chainId, OperationType.Mint);
        _mint(user, mintAmount, false);

        logs[user][chainId][OperationType.Mint].push(LogData(_nonce, abi.encode(mintAmount)));

        emit mErc20Host_MintExternal(msg.sender, user, mintAmount, _nonce, chainId);
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function borrowExternal(bytes calldata journalData, bytes calldata seal) external override {
        // verify received data
        _verifyProof(ImageIdIndexes.Borrow, journalData, seal);

        // decode action data
        (uint256 borrowAmount, address user, uint256 nonce, uint256 chainId) =
            abi.decode(journalData[96:], (uint256, address, uint256, uint256));

        // checks
        _checkSender(msg.sender, user);

        require(borrowAmount > 0, mErc20Host_AmountNotValid());
        uint256 _nonce = _getNonce(user, chainId, OperationType.Borrow);
        require(_nonce == nonce, mErc20Host_NonceNotValid());

        // actions
        _increaseNonce(user, chainId, OperationType.Borrow);
        _borrow(user, borrowAmount, true);

        logs[user][chainId][OperationType.Borrow].push(LogData(_nonce, abi.encode(borrowAmount)));
        emit mErc20Host_BorrowExternal(msg.sender, user, borrowAmount, _nonce, chainId);
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function borrowOnExtension(uint256 amount, bytes calldata journalData, bytes calldata seal) external override {
        // verify received data
        _verifyProof(ImageIdIndexes.BorrowOnExtension, journalData, seal);

        // decode action data
        (uint256 liquidity, address user) = abi.decode(journalData[96:], (uint256, address));

        // checks
        _checkSender(msg.sender, user);
        require(liquidity > 0 && amount > 0 && amount <= liquidity, mErc20Host_AmountNotValid());

        // actions
        uint256 _nonce = _getNonce(user, block.chainid, OperationType.BorrowOnExtension);
        _increaseNonce(user, block.chainid, OperationType.BorrowOnExtension);
        _borrow(user, amount, false);

        logs[user][block.chainid][OperationType.BorrowOnExtension].push(LogData(_nonce, abi.encode(amount)));
        emit mErc20Host_BorrowOnExternsionChain(msg.sender, user, amount, _nonce, block.chainid);
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function repayExternal(bytes calldata journalData, bytes calldata seal) external override {
        // verify received data
        _verifyProof(ImageIdIndexes.Repay, journalData, seal);

        // decode action data
        (uint256 repayAmount, address borrower, uint256 nonce, uint256 chainId) =
            abi.decode(journalData[96:], (uint256, address, uint256, uint256));

        // checks
        _checkSender(msg.sender, borrower);
        require(repayAmount > 0, mErc20Host_AmountNotValid());
        uint256 _nonce = _getNonce(borrower, chainId, OperationType.Repay);
        require(_nonce == nonce, mErc20Host_NonceNotValid());

        // actions
        _increaseNonce(borrower, chainId, OperationType.Repay);
        _repayBehalf(borrower, repayAmount, false);

        logs[borrower][chainId][OperationType.Repay].push(LogData(_nonce, abi.encode(repayAmount)));
        emit mErc20Host_RepayExternal(msg.sender, borrower, repayAmount, _nonce, chainId);
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function withdrawExternal(bytes calldata journalData, bytes calldata seal) external override {
        // verify received data
        _verifyProof(ImageIdIndexes.Redeem, journalData, seal);

        // decode action data
        (uint256 amount, address user, uint256 nonce, uint256 chainId) =
            abi.decode(journalData[96:], (uint256, address, uint256, uint256));

        // checks
        _checkSender(msg.sender, user);
        require(amount > 0, mErc20Host_AmountNotValid());
        uint256 _nonce = _getNonce(user, chainId, OperationType.Redeem);
        require(_nonce == nonce, mErc20Host_NonceNotValid());

        // actions
        _increaseNonce(user, chainId, OperationType.Redeem);
        _redeem(user, amount, true);

        logs[user][chainId][OperationType.Redeem].push(LogData(_nonce, abi.encode(amount)));
        emit mErc20Host_WithdrawExternal(msg.sender, user, amount, _nonce, chainId);
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function withdrawOnExtension(uint256 amount, bytes calldata journalData, bytes calldata seal) external override {
        // verify received data
        _verifyProof(ImageIdIndexes.RedeemOnExtension, journalData, seal);

        // decode action data
        (uint256 liquidity, address user) = abi.decode(journalData[96:], (uint256, address));

        // checks
        _checkSender(msg.sender, user);
        require(liquidity > 0 && amount > 0 && amount <= liquidity, mErc20Host_AmountNotValid());

        // actions
        uint256 _nonce = _getNonce(user, block.chainid, OperationType.RedeemOnExtension);
        _increaseNonce(user, block.chainid, OperationType.RedeemOnExtension);
        _redeem(user, amount, false);

        logs[user][block.chainid][OperationType.RedeemOnExtension].push(LogData(_nonce, abi.encode(amount)));
        emit mErc20Host_WithdrawOnExtensionChain(msg.sender, user, amount, _nonce, block.chainid);
    }

    // ----------- PRIVATE ------------
    function _verifyProof(ImageIdIndexes imageType, bytes calldata journalData, bytes calldata seal) private {
        require(journalData.length > 95, mErc20Host_JournalNotValid());

        // get commitment data
        bytes memory commitmentData = journalData[:96];
        Steel.Commitment memory commitment = abi.decode(commitmentData, (Steel.Commitment));

        // verify it using the ZkVerifier contract
        _verifyInput(journalData, commitment, seal, uint256(imageType));
    }

    function _getNonce(address from, uint256 chainId, OperationType operation) private view returns (uint256) {
        return nonces[from][chainId][operation];
    }

    function _increaseNonce(address from, uint256 chainId, OperationType operation) private {
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
