// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

// interfaces

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
    uint32 public nonce;
    mapping(uint32 => mapping(address => uint256)) public accAmountInPerChain;
    mapping(uint32 => mapping(address => uint256)) public accAmountOutPerChain;

    int32 private constant DEFAULT_NONCE = -1;

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
        ZkVerifier.initialize(zkVerifier_);

        logsOperator = ImTokenLogs(logs_);

        // Set the proper admin now that initialization is done
        admin = admin_;
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
     * @notice Sets the image id
     * @param _imageId the new image id
     */
    function setImageId(bytes32 _imageId) external onlyAdmin {
        _setImageId(_imageId);
    }

    // ----------- PUBLIC ------------
    /**
     * @inheritdoc ImErc20Host
     */
    function liquidateExternal(
        bytes calldata journalData,
        bytes calldata seal,
        uint256 liquidateAmount,
        address collateral
    ) external override {
        // verify received data
        _verifyProof(journalData, seal);

        (
            address liquidator,
            address user,
            uint256 extChainAccAmountIn,
            uint32 chainId,
            uint32 srcNonce,
            address[] memory allowedCallers
        ) = _decodeJournal(journalData);

        // checks
        {
            _checkSender(msg.sender, liquidator, allowedCallers);
            require(liquidateAmount > 0, mErc20Host_AmountNotValid());
            require(
                liquidateAmount <= extChainAccAmountIn - accAmountInPerChain[chainId][liquidator],
                mErc20Host_AmountTooBig()
            );
            require(liquidator != user, mErc20Host_CallerNotAllowed());
        }

        collateral = collateral == address(0) ? address(this) : collateral;

        // actions
        nonce++;
        accAmountInPerChain[chainId][liquidator] += liquidateAmount;
        _liquidate(liquidator, user, liquidateAmount, collateral, false);

        {
            logsOperator.registerLog(msg.sender, OperationType.AmountInHere, chainId, uint32(block.chainid), nonce, "");
            emit mErc20Host_LiquidateExternal(
                liquidator,
                user,
                collateral,
                LiquidateData({
                    msgSender: msg.sender,
                    srcNonce: int32(srcNonce),
                    nonce: int32(nonce),
                    accAmount: accAmountInPerChain[chainId][liquidator],
                    srcChainId: chainId,
                    chainId: uint32(block.chainid),
                    amount: liquidateAmount
                })
            );
        }
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function mintExternal(bytes calldata journalData, bytes calldata seal, uint256 mintAmount) external override {
        // verify received data
        _verifyProof(journalData, seal);

        (
            address sender,
            address user,
            uint256 extChainAccAmountIn,
            uint32 chainId,
            uint32 srcNonce,
            address[] memory allowedCallers
        ) = _decodeJournal(journalData);

        // checks
        _checkSender(msg.sender, sender, allowedCallers);
        require(mintAmount > 0, mErc20Host_AmountNotValid());
        require(mintAmount <= extChainAccAmountIn - accAmountInPerChain[chainId][sender], mErc20Host_AmountTooBig());

        // actions
        nonce++;
        accAmountInPerChain[chainId][sender] += mintAmount;
        _mint(user, mintAmount, false);

        logsOperator.registerLog(msg.sender, OperationType.AmountInHere, chainId, uint32(block.chainid), nonce, "");

        emit mErc20Host_MintExternal(
            msg.sender,
            sender,
            user,
            int32(srcNonce),
            int32(nonce),
            accAmountInPerChain[chainId][sender],
            chainId,
            uint32(block.chainid),
            mintAmount
        );
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function borrowExternal(bytes calldata journalData, bytes calldata seal, uint256 borrowAmount) external override {
        // verify received data
        _verifyProof(journalData, seal);

        (
            address sender,
            address user,
            uint256 extChainAccAmountOut,
            uint32 chainId,
            uint32 srcNonce,
            address[] memory allowedCallers
        ) = _decodeJournal(journalData);

        // checks
        _checkSender(msg.sender, sender, allowedCallers);
        require(borrowAmount > 0, mErc20Host_AmountNotValid());
        require(borrowAmount <= extChainAccAmountOut - accAmountOutPerChain[chainId][sender], mErc20Host_AmountTooBig());

        // actions
        nonce++;
        accAmountOutPerChain[chainId][sender] += borrowAmount;
        _borrow(user, borrowAmount, true);

        logsOperator.registerLog(msg.sender, OperationType.AmountInHere, chainId, uint32(block.chainid), nonce, "");
        emit mErc20Host_BorrowExternal(
            msg.sender,
            sender,
            user,
            int32(srcNonce),
            int32(nonce),
            accAmountOutPerChain[chainId][sender],
            chainId,
            uint32(block.chainid),
            borrowAmount
        );
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function repayExternal(bytes calldata journalData, bytes calldata seal, uint256 repayAmount) external override {
        // verify received data
        _verifyProof(journalData, seal);

        (
            address sender,
            address user,
            uint256 extChainAccAmountIn,
            uint32 chainId,
            uint32 srcNonce,
            address[] memory allowedCallers
        ) = _decodeJournal(journalData);

        // checks
        _checkSender(msg.sender, sender, allowedCallers);
        require(repayAmount > 0, mErc20Host_AmountNotValid());
        require(repayAmount <= extChainAccAmountIn - accAmountInPerChain[chainId][sender], mErc20Host_AmountTooBig());

        // actions
        nonce++;
        accAmountInPerChain[chainId][sender] += repayAmount;
        _repayBehalf(user, repayAmount, false);

        logsOperator.registerLog(msg.sender, OperationType.AmountInHere, chainId, uint32(block.chainid), nonce, "");
        emit mErc20Host_RepayExternal(
            msg.sender,
            sender,
            user,
            int32(srcNonce),
            int32(nonce),
            accAmountInPerChain[chainId][sender],
            chainId,
            uint32(block.chainid),
            repayAmount
        );
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function withdrawExternal(bytes calldata journalData, bytes calldata seal, uint256 amount) external override {
        // verify received data
        _verifyProof(journalData, seal);

        (
            address sender,
            address user,
            uint256 extChainAccAmountOut,
            uint32 chainId,
            uint32 srcNonce,
            address[] memory allowedCallers
        ) = _decodeJournal(journalData);

        // checks
        _checkSender(msg.sender, sender, allowedCallers);
        require(amount > 0, mErc20Host_AmountNotValid());
        require(amount <= extChainAccAmountOut - accAmountOutPerChain[chainId][sender], mErc20Host_AmountTooBig());

        // actions
        nonce++;
        accAmountOutPerChain[chainId][sender] += amount;
        _redeem(user, amount, true);

        logsOperator.registerLog(msg.sender, OperationType.AmountOutHere, chainId, uint32(block.chainid), nonce, "");
        emit mErc20Host_WithdrawExternal(
            msg.sender,
            sender,
            user,
            int32(srcNonce),
            int32(nonce),
            accAmountOutPerChain[chainId][sender],
            chainId,
            uint32(block.chainid),
            amount
        );
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function withdrawOnExtension(uint256 amount, uint32 dstChainId, address[] calldata allowedCallers)
        external
        override
    {
        require(amount > 0, mErc20Host_AmountNotValid());

        // actions
        nonce++;
        accAmountOutPerChain[dstChainId][msg.sender] += amount;
        _redeem(msg.sender, amount, false);

        logsOperator.registerLog(
            msg.sender,
            OperationType.AmountOut,
            uint32(block.chainid),
            dstChainId,
            nonce,
            abi.encodePacked(
                msg.sender,
                msg.sender,
                accAmountOutPerChain[dstChainId][msg.sender],
                uint32(block.chainid),
                allowedCallers
            )
        );

        emit mErc20Host_WithdrawOnExtensionChain(
            msg.sender,
            msg.sender,
            int32(nonce),
            DEFAULT_NONCE,
            accAmountOutPerChain[dstChainId][msg.sender],
            uint32(block.chainid),
            dstChainId,
            amount
        );
    }

    function borrowOnExtension(uint256 amount, uint32 dstChainId, address[] calldata allowedCallers)
        external
        override
    {
        require(amount > 0, mErc20Host_AmountNotValid());

        // actions
        nonce++;
        accAmountOutPerChain[dstChainId][msg.sender] += amount;
        _borrow(msg.sender, amount, false);

        logsOperator.registerLog(
            msg.sender,
            OperationType.AmountOut,
            uint32(block.chainid),
            dstChainId,
            nonce,
            abi.encodePacked(
                msg.sender,
                msg.sender,
                accAmountOutPerChain[dstChainId][msg.sender],
                uint32(block.chainid),
                allowedCallers
            )
        );

        emit mErc20Host_BorrowOnExternsionChain(
            msg.sender,
            msg.sender,
            int32(nonce),
            DEFAULT_NONCE,
            accAmountOutPerChain[dstChainId][msg.sender],
            uint32(block.chainid),
            dstChainId,
            amount
        );
    }

    // ----------- PRIVATE ------------
    function _verifyProof(bytes calldata journalData, bytes calldata seal) private {
        require(journalData.length > 0, mErc20Host_JournalNotValid());

        // verify it using the ZkVerifier contract
        _verifyInput(journalData, seal);
    }

    function _decodeJournal(bytes calldata journalData)
        private
        pure
        returns (
            address _sender,
            address _user,
            uint256 _accAmount,
            uint32 _chainId,
            uint32 _srcNonce,
            address[] memory _allowedCallers
        )
    {
        // decode action data
        // | Offset | Length | Data Type               |
        // |--------|---------|----------------------- |
        // | 0      | 20      | address sender         |
        // | 20     | 20      | address user           |
        // | 40     | 32      | uint256 accAmount      |
        // | 72     | 4       | uint32 chainId         |
        // | 76     | 4       | uint32 srcNonce        |
        // | 80     | -       | [] allowedCallers      |
        _sender = BytesLib.toAddress(BytesLib.slice(journalData, 0, 20), 0);
        _user = BytesLib.toAddress(BytesLib.slice(journalData, 20, 20), 0);
        _accAmount = BytesLib.toUint256(BytesLib.slice(journalData, 40, 32), 0);
        _chainId = BytesLib.toUint32(BytesLib.slice(journalData, 72, 4), 0);
        _srcNonce = BytesLib.toUint32(BytesLib.slice(journalData, 76, 4), 0);
        _allowedCallers = _extractCallers(journalData, 80);
    }

    function _extractCallers(bytes calldata journalData, uint256 allowedCallersOffset)
        private
        pure
        returns (address[] memory allowedCallers)
    {
        if (journalData.length <= allowedCallersOffset) {
            allowedCallers = new address[](0);
        } else {
            bytes memory _slicedJournal = journalData[allowedCallersOffset:];
            uint256 _addrCount = _slicedJournal.length / 32;

            allowedCallers = new address[](_addrCount);
            for (uint256 i; i < _addrCount; i++) {
                bytes memory addressBytes = new bytes(32);
                for (uint256 j = 0; j < 32; j++) {
                    addressBytes[j] = _slicedJournal[i * 32 + j];
                }
                allowedCallers[i] = abi.decode(addressBytes, (address));
            }
        }
    }

    function _checkSender(address sender, address user, address[] memory allowedCallers) private view {
        if (sender != user) {
            bool isAllowedCaller = false;

            // check array
            for (uint256 i = 0; i < allowedCallers.length; i++) {
                if (sender == allowedCallers[i]) {
                    isAllowedCaller = true;
                    break;
                }
            }

            require(
                isAllowedCaller || sender == admin
                    || rolesOperator.isAllowedFor(sender, rolesOperator.PROOF_FORWARDER()),
                mErc20Host_CallerNotAllowed()
            );
        }
    }
}
