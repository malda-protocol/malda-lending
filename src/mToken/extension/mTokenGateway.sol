// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// contracts
import {IRoles} from "src/interfaces/IRoles.sol";
import {ImTokenLogs} from "src/interfaces/ImTokenLogs.sol";
import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

import {BytesLib} from "src/libraries/BytesLib.sol";

import {Steel} from "risc0/steel/Steel.sol";
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";

contract mTokenGateway is Ownable, ERC20, ZkVerifier, ImTokenGateway, ImTokenOperationTypes {
    using SafeERC20 for IERC20;

    // ----------- STORAGE -----------
    /**
     * @inheritdoc ImTokenGateway
     */
    IRoles public rolesOperator;

    /**
     * @inheritdoc ImTokenGateway
     */
    ImTokenLogs public logsOperator;

    mapping(OperationType => bool) public paused;

    /**
     * @inheritdoc ImTokenGateway
     */
    address public underlying;
    // user -> chainId -> operation type -> nonce
    mapping(address => mapping(uint32 => mapping(OperationType => uint32))) public nonces;

    uint8 private _underlyingDecimals;

    uint32 private constant LINEA_CHAIN_ID = 59144;

    constructor(
        address payable _owner,
        address _underlying,
        address _roles,
        address zkVerifier_,
        address zkVerifierImageRegistry_,
        address _logs
    )
        Ownable(_owner)
        ERC20(
            string.concat("pending_", IERC20Metadata(_underlying).name()),
            string.concat("p_", IERC20Metadata(_underlying).symbol())
        )
    {
        underlying = _underlying;
        _underlyingDecimals = IERC20Metadata(_underlying).decimals();

        rolesOperator = IRoles(_roles);
        logsOperator = ImTokenLogs(_logs);

        // Initialize the ZkVerifier
        ZkVerifier.initialize(zkVerifier_, zkVerifierImageRegistry_);
    }

    modifier notPaused(OperationType _type) {
        require(!paused[_type], mTokenGateway_Paused(_type));
        _;
    }

    // ----------- VIEW ------------
    /// @notice return the decimals value
    function decimals() public view override returns (uint8) {
        return _underlyingDecimals;
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function getNonce(address user, uint32 chainId, OperationType opType) external view returns (uint32) {
        return nonces[user][chainId][opType];
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function isPaused(OperationType _type) external view returns (bool) {
        return paused[_type];
    }

    // ----------- OWNER ------------

    /**
     * @inheritdoc ImTokenGateway
     */
    function setPaused(OperationType _type, bool state) external override {
        if (state) {
            require(
                msg.sender == owner() || rolesOperator.isAllowedFor(msg.sender, rolesOperator.GUARDIAN_PAUSE()),
                mTokenGateway_CallerNotAllowed()
            );
        } else {
            require(msg.sender == owner(), mTokenGateway_CallerNotAllowed());
        }
        paused[_type] = state;
    }

    /**
     * @notice Sets the _risc0Verifier address
     * @param _risc0Verifier the new IRiscZeroVerifier address
     */
    function setVerifier(address _risc0Verifier) external onlyOwner {
        _setVerifier(_risc0Verifier);
    }

    /**
     * @notice Sets the ZkVerifierImageRegistry
     * @param _imageRegistry the new image registry address
     */
    function setVerifierImageRegistry(address _imageRegistry) external onlyOwner {
        _setVerifierImageRegistry(_imageRegistry);
    }

    // ----------- PUBLIC ------------
    /**
     * @inheritdoc ImTokenGateway
     */
    function mintOnHost(uint256 amount) external notPaused(OperationType.MintOnOtherChain) {
        require(amount > 0, mTokenGateway_AmountNotValid());

        IERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);

        uint32 _nonce =
            _getNonce(msg.sender, uint32(block.chainid), ImTokenOperationTypes.OperationType.MintOnOtherChain);
        _increaseNonce(msg.sender, uint32(block.chainid), ImTokenOperationTypes.OperationType.MintOnOtherChain);

        logsOperator.registerLog(
            msg.sender,
            ImTokenOperationTypes.OperationType.MintOnOtherChain,
            uint32(block.chainid),
            LINEA_CHAIN_ID,
            _nonce,
            abi.encodePacked(amount, msg.sender, _nonce, uint32(block.chainid))
        );

        _mint(msg.sender, amount);
        emit mTokenGateway_MintInitiated(msg.sender, amount, _nonce, uint32(block.chainid));
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function borrowOnHost(uint256 amount) external override notPaused(OperationType.BorrowOnOtherChain) {
        require(amount > 0, mTokenGateway_AmountNotValid());

        uint32 _nonce =
            _getNonce(msg.sender, uint32(block.chainid), ImTokenOperationTypes.OperationType.BorrowOnOtherChain);
        _increaseNonce(msg.sender, uint32(block.chainid), ImTokenOperationTypes.OperationType.BorrowOnOtherChain);

        logsOperator.registerLog(
            msg.sender,
            ImTokenOperationTypes.OperationType.BorrowOnOtherChain,
            uint32(block.chainid),
            LINEA_CHAIN_ID,
            _nonce,
            abi.encodePacked(amount, msg.sender, _nonce, uint32(block.chainid))
        );

        emit mTokenGateway_BorrowInitiated(msg.sender, amount, _nonce, uint32(block.chainid));
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function borrowExternal(bytes calldata journalData, bytes calldata seal)
        external
        override
        notPaused(OperationType.Borrow)
    {
        // verify received data
        _verifyProof(ImTokenOperationTypes.OperationType.Borrow, journalData, seal);

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
        require(amount > 0, mTokenGateway_AmountNotValid());
        uint32 _nonce = _getNonce(user, chainId, ImTokenOperationTypes.OperationType.Borrow);
        require(_nonce == nonce, mTokenGateway_NonceNotValid());
        require(IERC20(underlying).balanceOf(address(this)) >= amount, mTokenGateway_ReleaseCashNotAvailable());

        // effects
        _increaseNonce(user, chainId, ImTokenOperationTypes.OperationType.Borrow);
        logsOperator.registerLog(
            user,
            OperationType.Borrow,
            chainId,
            uint32(block.chainid),
            nonce,
            abi.encodePacked(amount, user, nonce, chainId)
        );

        // interactions
        IERC20(underlying).safeTransfer(user, amount);

        emit mTokenGateway_BorrowExternal(user, amount, _nonce, chainId);
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function repayOnHost(uint256 amount) external notPaused(OperationType.RepayOnOtherChain) {
        require(amount > 0, mTokenGateway_AmountNotValid());

        IERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);

        uint32 _nonce =
            _getNonce(msg.sender, uint32(block.chainid), ImTokenOperationTypes.OperationType.RepayOnOtherChain);
        _increaseNonce(msg.sender, uint32(block.chainid), ImTokenOperationTypes.OperationType.RepayOnOtherChain);

        logsOperator.registerLog(
            msg.sender,
            OperationType.RepayOnOtherChain,
            uint32(block.chainid),
            LINEA_CHAIN_ID,
            _nonce,
            abi.encodePacked(amount, msg.sender, _nonce, uint32(block.chainid))
        );

        emit mTokenGateway_RepayInitiated(msg.sender, amount, _nonce, uint32(block.chainid));
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function withdrawOnHost(uint256 amount) external notPaused(OperationType.RedeemOnOtherChain) {
        require(amount > 0, mTokenGateway_AmountNotValid());

        _burn(msg.sender, amount);

        uint32 _nonce =
            _getNonce(msg.sender, uint32(block.chainid), ImTokenOperationTypes.OperationType.RedeemOnOtherChain);
        _increaseNonce(msg.sender, uint32(block.chainid), ImTokenOperationTypes.OperationType.RedeemOnOtherChain);

        logsOperator.registerLog(
            msg.sender,
            ImTokenOperationTypes.OperationType.RedeemOnOtherChain,
            uint32(block.chainid),
            LINEA_CHAIN_ID,
            _nonce,
            abi.encodePacked(amount, msg.sender, _nonce, uint32(block.chainid))
        );
        emit mTokenGateway_WithdrawInitiated(msg.sender, amount, _nonce, uint32(block.chainid));
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function withdrawExternal(bytes calldata journalData, bytes calldata seal)
        external
        notPaused(OperationType.Redeem)
    {
        // verify received data
        _verifyProof(ImTokenOperationTypes.OperationType.Redeem, journalData, seal);

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
        require(amount > 0, mTokenGateway_AmountNotValid());
        uint32 _nonce = _getNonce(user, chainId, ImTokenOperationTypes.OperationType.Redeem);
        require(_nonce == nonce, mTokenGateway_NonceNotValid());
        require(IERC20(underlying).balanceOf(address(this)) >= amount, mTokenGateway_ReleaseCashNotAvailable());

        // effects
        _increaseNonce(user, chainId, ImTokenOperationTypes.OperationType.Redeem);
        logsOperator.registerLog(
            msg.sender,
            ImTokenOperationTypes.OperationType.Redeem,
            chainId,
            uint32(block.chainid),
            nonce,
            abi.encodePacked(amount, msg.sender, nonce, chainId)
        );
        // interactions
        IERC20(underlying).safeTransfer(user, amount);

        emit mTokenGateway_Released(user, amount, _nonce, chainId);
    }

    /**
     * @dev Non-transferable
     */
    function transfer(address, uint256) public pure override returns (bool) {
        revert mTokenGateway_NonTransferable();
    }

    /**
     * @dev Non-transferable
     */
    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert mTokenGateway_NonTransferable();
    }

    // ----------- PRIVATE ------------
    function _verifyProof(OperationType imageType, bytes calldata journalData, bytes calldata seal) private {
        require(journalData.length > 0, mTokenGateway_JournalNotValid());

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
                sender == owner() || rolesOperator.isAllowedFor(sender, rolesOperator.PROOF_FORWARDER()),
                mTokenGateway_CallerNotAllowed()
            );
        }
    }
}
