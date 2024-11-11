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
import {ImTokenGateway} from "../../interfaces/ImTokenGateway.sol";
import {IRoles} from "../../interfaces/IRoles.sol";

import {Steel} from "risc0/steel/Steel.sol";
import {ZkVerifier} from "../../verifier/ZkVerifier.sol";

contract mTokenGateway is Ownable, ERC20, ZkVerifier, ImTokenGateway {
    using SafeERC20 for IERC20;

    // ----------- STORAGE -----------
    /**
     * @inheritdoc ImTokenGateway
     */
    IRoles public rolesOperator;

    /**
     * @inheritdoc ImTokenGateway
     */
    address public underlying;
    // user -> amount
    mapping(address => uint256) public pendingAmounts;
    // user -> chainId -> operation type -> nonce
    mapping(address => mapping(uint256 => mapping(OperationType => uint256))) public nonces;
    // user -> chainId -> operation type -> LogData
    mapping(address => mapping(uint256 => mapping(OperationType => LogData[]))) public logs;

    uint8 private _underlyingDecimals;

    constructor(
        address payable _owner,
        address _underlying,
        address _roles,
        address zkVerifier_,
        address zkVerifierImageRegistry_
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

        // Initialize the ZkVerifier
        ZkVerifier.initialize(zkVerifier_, zkVerifierImageRegistry_);
    }

    function decimals() public view override returns (uint8) {
        return _underlyingDecimals;
    }
    // ----------- VIEW ------------
    /**
     * @inheritdoc ImTokenGateway
     */

    function getNonce(address user, uint256 chainId, OperationType opType) external view returns (uint256) {
        return nonces[user][chainId][opType];
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function getLogsAt(address user, uint256 chainId, OperationType opType, uint256 index)
        external
        view
        returns (LogData memory)
    {
        return logs[user][chainId][opType][index];
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function getLogsLength(address user, uint256 chainId, OperationType opType) external view returns (uint256) {
        return logs[user][chainId][opType].length;
    }

    // ----------- OWNER ------------
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
    function mintOnHost(uint256 amount) external {
        require(amount > 0, mTokenGateway_AmountNotValid());

        IERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);

        uint256 _nonce = _getNonce(msg.sender, block.chainid, OperationType.Mint);
        _increaseNonce(msg.sender, block.chainid, OperationType.Mint);

        logs[msg.sender][block.chainid][OperationType.Mint].push(LogData(_nonce, abi.encode(amount)));

        _mint(msg.sender, amount);
        emit mTokenGateway_MintInitiated(msg.sender, amount, _nonce, block.chainid);
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function borrowOnHost(uint256 amount) external override {
        require(amount > 0, mTokenGateway_AmountNotValid());

        uint256 _nonce = _getNonce(msg.sender, block.chainid, OperationType.Borrow);
        _increaseNonce(msg.sender, block.chainid, OperationType.Borrow);

        logs[msg.sender][block.chainid][OperationType.Borrow].push(LogData(_nonce, abi.encode(amount)));

        emit mTokenGateway_BorrowInitiated(msg.sender, amount, _nonce, block.chainid);
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function borrowExternal(bytes calldata journalData, bytes calldata seal) external override {
        // verify received data
        _verifyProof(ImageIdIndexes.BorrowExternal, journalData, seal);

        // decode action data
        (uint256 amount, address user, uint256 nonce, uint256 chainId) =
            abi.decode(journalData[96:], (uint256, address, uint256, uint256));

        // checks
        _checkSender(msg.sender, user);
        require(amount > 0, mTokenGateway_AmountNotValid());
        uint256 _nonce = _getNonce(user, chainId, OperationType.BorrowExternal);
        require(_nonce == nonce, mTokenGateway_NonceNotValid());
        require(IERC20(underlying).balanceOf(address(this)) >= amount, mTokenGateway_ReleaseCashNotAvailable());

        // effects
        _increaseNonce(user, chainId, OperationType.BorrowExternal);
        logs[user][chainId][OperationType.BorrowExternal].push(LogData(_nonce, abi.encode(amount)));

        // interactions
        IERC20(underlying).safeTransfer(user, amount);

        emit mTokenGateway_BorrowExternal(user, amount, _nonce, chainId);
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function repayOnHost(uint256 amount) external {
        require(amount > 0, mTokenGateway_AmountNotValid());

        IERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);

        uint256 _nonce = _getNonce(msg.sender, block.chainid, OperationType.Repay);
        _increaseNonce(msg.sender, block.chainid, OperationType.Repay);

        logs[msg.sender][block.chainid][OperationType.Repay].push(LogData(_nonce, abi.encode(amount)));

        emit mTokenGateway_RepayInitiated(msg.sender, amount, _nonce, block.chainid);
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function withdrawOnHost(uint256 amount) external {
        require(amount > 0, mTokenGateway_AmountNotValid());

        _burn(msg.sender, amount);

        uint256 _nonce = _getNonce(msg.sender, block.chainid, OperationType.Withdraw);
        _increaseNonce(msg.sender, block.chainid, OperationType.Withdraw);

        logs[msg.sender][block.chainid][OperationType.Withdraw].push(LogData(_nonce, abi.encode(amount)));
        pendingAmounts[msg.sender] += amount;

        emit mTokenGateway_WithdrawInitiated(msg.sender, amount, _nonce, block.chainid);
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function withdrawExternal(bytes calldata journalData, bytes calldata seal) external {
        // verify received data
        _verifyProof(ImageIdIndexes.WithdrawExternal, journalData, seal);

        // decode action data
        (uint256 amount, address user, uint256 nonce, uint256 chainId) =
            abi.decode(journalData[96:], (uint256, address, uint256, uint256));

        // checks
        _checkSender(msg.sender, user);
        require(amount > 0, mTokenGateway_AmountNotValid());
        uint256 _nonce = _getNonce(user, chainId, OperationType.WithdrawExternal);
        require(_nonce == nonce, mTokenGateway_NonceNotValid());
        require(pendingAmounts[msg.sender] >= amount, mTokenGateway_AmountTooBig());
        require(IERC20(underlying).balanceOf(address(this)) >= amount, mTokenGateway_ReleaseCashNotAvailable());

        // effects
        pendingAmounts[msg.sender] -= amount;
        _increaseNonce(user, chainId, OperationType.WithdrawExternal);
        logs[user][chainId][OperationType.WithdrawExternal].push(LogData(_nonce, abi.encode(amount)));

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
    function _verifyProof(ImageIdIndexes imageType, bytes calldata journalData, bytes calldata seal) private {
        require(journalData.length > 95, mTokenGateway_JournalNotValid());

        // verify it using the ZkVerifier contract
        _verifyInput(journalData, seal, uint256(imageType));
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
                sender == owner() || rolesOperator.isAllowedFor(sender, rolesOperator.PROOF_FORWARDER()),
                mTokenGateway_CallerNotAllowed()
            );
        }
    }
}
