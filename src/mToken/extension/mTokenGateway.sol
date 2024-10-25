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

import {Steel} from "risc0/steel/Steel.sol";
import {ZkVerifier} from "../../verifier/ZkVerifier.sol";

contract mTokenGateway is Ownable, ERC20, ZkVerifier, ImTokenGateway {
    using SafeERC20 for IERC20;

    // ----------- STORAGE -----------
    address public underlying;
    // user -> amount
    mapping(address => uint256) public pendingAmounts;
    // user -> operation type -> nonce
    mapping(address => mapping(OperationType => uint256)) public nonces;

    // user -> operation type -> LogData
    mapping(address => mapping(OperationType => LogData[])) public logs;

    uint8 private _underlyingDecimals;

    // ----------- ERRORS ------------

    constructor(address payable _owner, address _underlying, address zkVerifier_, address zkVerifierImageRegistry_)
        Ownable(_owner)
        ERC20(
            string.concat("pending_", IERC20Metadata(_underlying).name()),
            string.concat("p_", IERC20Metadata(_underlying).symbol())
        )
    {
        underlying = _underlying;
        _underlyingDecimals = IERC20Metadata(_underlying).decimals();

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

    function getNonce(address user, OperationType opType) external view returns (uint256) {
        return nonces[user][opType];
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function getLogsAt(address user, OperationType opType, uint256 index) external view returns (LogData memory) {
        return logs[user][opType][index];
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function getLogsLength(address user, OperationType opType) external view returns (uint256) {
        return logs[user][opType].length;
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
    function mint(uint256 amount) external {
        require(amount > 0, mTokenGateway_AmountNotValid());

        IERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);

        uint256 _nonce = _getNonce(msg.sender, OperationType.Mint);
        _increaseNonce(msg.sender, OperationType.Mint);

        logs[msg.sender][OperationType.Mint].push(LogData(_nonce, abi.encode(amount)));

        _mint(msg.sender, amount);
        emit mTokenGateway_MintInitiated(msg.sender, amount, _nonce);
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function borrow(uint256 amount) external {
        require(amount > 0, mTokenGateway_AmountNotValid());

        uint256 _nonce = _getNonce(msg.sender, OperationType.Borrow);
        _increaseNonce(msg.sender, OperationType.Borrow);

        logs[msg.sender][OperationType.Borrow].push(LogData(_nonce, abi.encode(amount)));

        emit mTokenGateway_BorrowInitiated(msg.sender, amount, _nonce);
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function repay(uint256 amount) external {
        require(amount > 0, mTokenGateway_AmountNotValid());

        IERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);

        uint256 _nonce = _getNonce(msg.sender, OperationType.Repay);
        _increaseNonce(msg.sender, OperationType.Repay);

        logs[msg.sender][OperationType.Repay].push(LogData(_nonce, abi.encode(amount)));

        emit mTokenGateway_RepayInitiated(msg.sender, amount, _nonce);
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function withdraw(uint256 amount) external {
        require(amount > 0, mTokenGateway_AmountNotValid());

        _burn(msg.sender, amount);

        uint256 _nonce = _getNonce(msg.sender, OperationType.Withdraw);
        _increaseNonce(msg.sender, OperationType.Withdraw);

        logs[msg.sender][OperationType.Withdraw].push(LogData(_nonce, abi.encode(amount)));
        pendingAmounts[msg.sender] += amount;

        emit mTokenGateway_WithdrawInitiated(msg.sender, amount, _nonce);
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function release(bytes calldata journalData, bytes calldata seal) external {
        // verify received data
        _verifyProof(ImageIdIndexes.Release, journalData, seal);

        // decode action data
        (uint256 amount, address user, uint256 nonce) = abi.decode(journalData[96:], (uint256, address, uint256));

        require(amount > 0, mTokenGateway_AmountNotValid());

        uint256 _nonce = _getNonce(user, OperationType.Release);
        require(_nonce == nonce, mTokenGateway_NonceNotValid());

        require(pendingAmounts[msg.sender] >= amount, mTokenGateway_AmountTooBig());
        pendingAmounts[msg.sender] -= amount;

        require(IERC20(underlying).balanceOf(address(this)) >= amount, mTokenGateway_ReleaseCashNotAvailable());

        _increaseNonce(user, OperationType.Release);
        logs[user][OperationType.Release].push(LogData(_nonce, abi.encode(amount)));

        IERC20(underlying).safeTransfer(user, amount);

        emit mTokenGateway_Released(user, amount, _nonce);
    }

    // ----------- PRIVATE ------------

    function _verifyProof(ImageIdIndexes imageType, bytes calldata journalData, bytes calldata seal) private {
        require(journalData.length > 95, mTokenGateway_JournalNotValid());

        // verify it using the ZkVerifier contract
        _verifyInput(journalData, seal, uint256(imageType));
    }

    function _getNonce(address from, OperationType operation) private view returns (uint256) {
        return nonces[from][operation];
    }

    function _increaseNonce(address from, OperationType operation) private {
        nonces[from][operation]++;
    }
}
