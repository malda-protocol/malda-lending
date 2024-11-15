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

import {ImErc20Host} from "src/interfaces/ImErc20Host.sol";
import {ImTokenLogs} from "src/interfaces/ImTokenLogs.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

contract mErc20Host is mErc20Immutable, ZkVerifier, ImErc20Host, ImTokenOperationTypes {
    // ----------- STORAGE ------------
    // user -> chainId -> operation type -> nonce
    mapping(address => mapping(uint256 => mapping(OperationType => uint256))) public nonces;

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
    function getNonce(address user, uint256 chainId, OperationType opType) external view returns (uint256) {
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

        logsOperator.registerLog(
            msg.sender,
            OperationType.Mint,
            chainId,
            block.chainid,
            nonce,
            abi.encode(mintAmount, msg.sender, nonce, chainId)
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

        logsOperator.registerLog(
            msg.sender,
            OperationType.Borrow,
            chainId,
            block.chainid,
            nonce,
            abi.encode(borrowAmount, msg.sender, nonce, chainId)
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
        (uint256 liquidity, address user, uint256 dstChainId) =
            abi.decode(journalData[96:], (uint256, address, uint256));

        // checks
        _checkSender(msg.sender, user);
        require(liquidity > 0 && amount > 0 && amount <= liquidity, mErc20Host_AmountNotValid());

        // actions
        uint256 _nonce = _getNonce(user, block.chainid, OperationType.BorrowOnOtherChain);
        _increaseNonce(user, block.chainid, OperationType.BorrowOnOtherChain);
        _borrow(user, amount, false);

        logsOperator.registerLog(
            user,
            OperationType.BorrowOnOtherChain,
            block.chainid,
            dstChainId,
            _nonce,
            abi.encode(amount, user, _nonce, block.chainid)
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

        logsOperator.registerLog(
            msg.sender,
            OperationType.Repay,
            chainId,
            block.chainid,
            nonce,
            abi.encode(repayAmount, msg.sender, nonce, chainId)
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

        logsOperator.registerLog(
            msg.sender,
            OperationType.Redeem,
            chainId,
            block.chainid,
            nonce,
            abi.encode(amount, msg.sender, nonce, chainId)
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
        (uint256 liquidity, address user, uint256 dstChainId) =
            abi.decode(journalData[96:], (uint256, address, uint256));

        // checks
        _checkSender(msg.sender, user);
        require(liquidity > 0 && amount > 0 && amount <= liquidity, mErc20Host_AmountNotValid());

        // actions
        uint256 _nonce = _getNonce(user, block.chainid, OperationType.RedeemOnOtherChain);
        _increaseNonce(user, block.chainid, OperationType.RedeemOnOtherChain);
        _redeem(user, amount, false);

        logsOperator.registerLog(
            user,
            OperationType.RedeemOnOtherChain,
            block.chainid,
            dstChainId,
            _nonce,
            abi.encode(amount, user, _nonce, block.chainid)
        );
        emit mErc20Host_WithdrawOnExtensionChain(msg.sender, user, amount, _nonce, dstChainId);
    }

    // ----------- PRIVATE ------------
    function _verifyProof(OperationType imageType, bytes calldata journalData, bytes calldata seal) private {
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
