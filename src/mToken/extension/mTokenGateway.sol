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
    uint8 private _underlyingDecimals;

    uint32 public nonce;
    mapping(address => uint256) public accAmountIn;
    mapping(address => uint256) public accAmountOut;

    int32 private constant DEFAULT_NONCE = -1;
    uint32 private constant LINEA_CHAIN_ID = 59144;

    constructor(address payable _owner, address _underlying, address _roles, address zkVerifier_, address _logs)
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
        ZkVerifier.initialize(zkVerifier_);
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
     * @notice Sets the image id
     * @param _imageId the new image id
     */
    function setImageId(bytes32 _imageId) external onlyOwner {
        _setImageId(_imageId);
    }

    // ----------- PUBLIC ------------
    /**
     * @inheritdoc ImTokenGateway
     */
    function supplyOnHost(uint256 amount, address user, address[] calldata allowedCallers)
        external
        override
        notPaused(OperationType.AmountIn)
    {
        // checks
        require(amount > 0, mTokenGateway_AmountNotValid());
        require(user != address(0), mTokenGateway_AddressNotValid());

        IERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);

        // effects
        nonce++;
        accAmountIn[msg.sender] += amount;
        logsOperator.registerLog(
            user,
            OperationType.AmountIn,
            uint32(block.chainid),
            LINEA_CHAIN_ID,
            nonce,
            abi.encodePacked(msg.sender, user, accAmountIn[msg.sender], uint32(block.chainid), allowedCallers)
        );

        emit mTokenGateway_Supplied(
            msg.sender,
            user,
            amount,
            int32(nonce),
            DEFAULT_NONCE,
            accAmountIn[msg.sender],
            uint32(block.chainid),
            LINEA_CHAIN_ID
        );
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function outOnHost(uint256 amount, address user, address[] calldata allowedCallers)
        external
        override
        notPaused(OperationType.AmountOut)
    {
        // checks
        require(amount > 0, mTokenGateway_AmountNotValid());
        require(user != address(0), mTokenGateway_AddressNotValid());

        // effects
        nonce++;
        accAmountOut[msg.sender] += amount;
        logsOperator.registerLog(
            user,
            OperationType.AmountOut,
            uint32(block.chainid),
            LINEA_CHAIN_ID,
            nonce,
            abi.encodePacked(msg.sender, user, accAmountOut[msg.sender], uint32(block.chainid), allowedCallers)
        );

        emit mTokenGateway_OutOnHost(
            msg.sender,
            user,
            amount,
            int32(nonce),
            DEFAULT_NONCE,
            accAmountOut[msg.sender],
            uint32(block.chainid),
            LINEA_CHAIN_ID
        );
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function outHere(bytes calldata journalData, bytes calldata seal, uint256 amount)
        external
        override
        notPaused(OperationType.AmountOutHere)
    {
        // verify received data
        _verifyProof(journalData, seal);

        // decode action data
        // | Offset | Length | Data Type               |
        // |--------|---------|----------------------- |
        // | 0      | 20      | address sender         |
        // | 20     | 20      | address user           |
        // | 40     | 32      | uint256 accAmountOut   |
        // | 72     | 4       | uint32 chainId         |
        // | 76     | 4       | uint32 srcNonce        |
        // | 80     | -       | [] allowedCallers      |
        address _sender = BytesLib.toAddress(BytesLib.slice(journalData, 0, 20), 0);
        address _user = BytesLib.toAddress(BytesLib.slice(journalData, 20, 20), 0);
        uint256 _accAmountOut = BytesLib.toUint256(BytesLib.slice(journalData, 40, 32), 0);
        uint32 _chainId = BytesLib.toUint32(BytesLib.slice(journalData, 72, 4), 0);
        uint32 _srcNonce = BytesLib.toUint32(BytesLib.slice(journalData, 76, 4), 0);
        address[] memory _allowedCallers = _extractCallers(journalData, 80);

        // checks
        _checkSender(msg.sender, _user, _allowedCallers);
        require(amount > 0, mTokenGateway_AmountNotValid());
        require(_accAmountOut - accAmountOut[_sender] >= amount, mTokenGateway_AmountTooBig());
        require(IERC20(underlying).balanceOf(address(this)) >= amount, mTokenGateway_ReleaseCashNotAvailable());

        // effects
        nonce++;
        accAmountOut[_sender] += amount;
        logsOperator.registerLog(_user, OperationType.AmountOutHere, _chainId, uint32(block.chainid), nonce, "");

        // interactions
        IERC20(underlying).safeTransfer(_user, amount);

        emit mTokenGateway_Extracted(
            msg.sender,
            _sender,
            _user,
            amount,
            int32(_srcNonce),
            int32(nonce),
            accAmountOut[_sender],
            _chainId,
            uint32(block.chainid)
        );
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
    function _verifyProof(bytes calldata journalData, bytes calldata seal) private {
        require(journalData.length > 0, mTokenGateway_JournalNotValid());

        // verify it using the ZkVerifier contract
        _verifyInput(journalData, seal);
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
                isAllowedCaller || sender == owner()
                    || rolesOperator.isAllowedFor(sender, rolesOperator.PROOF_FORWARDER()),
                mTokenGateway_CallerNotAllowed()
            );
        }
    }
}
