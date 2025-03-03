// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// contracts
import {IRoles} from "src/interfaces/IRoles.sol";
import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

import {mTokenProofDecoderLib} from "src/libraries/mTokenProofDecoderLib.sol";

import {ZkVerifier} from "src/verifier/ZkVerifier.sol";

contract mTokenGateway is OwnableUpgradeable, ZkVerifier, ImTokenGateway, ImTokenOperationTypes {
    using SafeERC20 for IERC20;

    // ----------- STORAGE -----------
    /**
     * @inheritdoc ImTokenGateway
     */
    IRoles public rolesOperator;

    mapping(OperationType => bool) public paused;

    /**
     * @inheritdoc ImTokenGateway
     */
    address public underlying;

    mapping(address => uint256) public accAmountIn;
    mapping(address => uint256) public accAmountOut;
    mapping(address => mapping(address => bool)) public allowedCallers;

    uint32 private constant LINEA_CHAIN_ID = 59144;

    ///@dev gas fee for `supplyOnHost`
    uint256 public gasFee;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address payable _owner, address _underlying, address _roles, address zkVerifier_)
        external
        initializer
    {
        __Ownable_init(_owner);
        underlying = _underlying;
        rolesOperator = IRoles(_roles);

        // Initialize the ZkVerifier
        ZkVerifier.initialize(zkVerifier_);
    }

    modifier notPaused(OperationType _type) {
        require(!paused[_type], mTokenGateway_Paused(_type));
        _;
    }

    // ----------- VIEW ------------
    /**
     * @inheritdoc ImTokenGateway
     */
    function isPaused(OperationType _type) external view returns (bool) {
        return paused[_type];
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function isCallerAllowed(address sender, address caller) external view returns (bool) {
        return allowedCallers[sender][caller];
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function getProofData(address user, uint32) external view returns (bytes memory) {
        return mTokenProofDecoderLib.encodeJournal(
            user, address(this), accAmountIn[user], accAmountOut[user], uint32(block.chainid), LINEA_CHAIN_ID
        );
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

        emit mTokenGateway_PausedState(_type, state);
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

    /**
     * @inheritdoc ImTokenGateway
     */
    function extractForRebalancing(uint256 amount) external {
        if (!rolesOperator.isAllowedFor(msg.sender, rolesOperator.REBALANCER())) revert mTokenGateway_NotRebalancer();
        IERC20(underlying).safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Sets the gas fee
     * @param amount the new gas fee
     */
    function setGasFee(uint256 amount) external onlyOwner {
        gasFee = amount;
        emit mTokenGateway_GasFeeUpdated(amount);
    }

    /**
     * @notice Withdraw gas received so far
     * @param receiver the receiver address
     */
    function withdrawGasFees(address payable receiver) external onlyOwner {
        uint256 balance = address(this).balance;
        receiver.transfer(balance);
    }

    // ----------- PUBLIC ------------
    /**
     * @inheritdoc ImTokenGateway
     */
    function updateAllowedCallerStatus(address caller, bool status) external override {
        allowedCallers[msg.sender][caller] = status;
        emit AllowedCallerUpdated(msg.sender, caller, status);
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function supplyOnHost(uint256 amount, bytes4 lineaSelector)
        external
        payable
        override
        notPaused(OperationType.AmountIn)
    {
        // checks
        require(amount > 0, mTokenGateway_AmountNotValid());
        require(msg.value >= gasFee, mTokenGateway_NotEnoughGasFee());

        IERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);

        // effects
        accAmountIn[msg.sender] += amount;

        emit mTokenGateway_Supplied(
            msg.sender,
            accAmountIn[msg.sender],
            accAmountOut[msg.sender],
            amount,
            uint32(block.chainid),
            LINEA_CHAIN_ID,
            lineaSelector
        );
    }

    /**
     * @inheritdoc ImTokenGateway
     */
    function outHere(bytes calldata journalData, bytes calldata seal, uint256[] calldata amounts, address receiver)
        external
        notPaused(OperationType.AmountOutHere)
    {
        // verify received data
        if (!rolesOperator.isAllowedFor(msg.sender, rolesOperator.PROOF_BATCH_FORWARDER())) {
            _verifyProof(journalData, seal);
        }

        bytes[] memory journals = abi.decode(journalData, (bytes[]));
        uint256 length = journals.length;
        require(length == amounts.length, mTokenGateway_LengthNotValid());

        for (uint256 i; i < journals.length;) {
            _outHere(journals[i], amounts[i], receiver);

            unchecked {
                ++i;
            }
        }
    }

    function _outHere(bytes memory journalData, uint256 amount, address receiver) internal {
        (address _sender, address _market,, uint256 _accAmountOut, uint32 _chainId, uint32 _dstChainId) =
            mTokenProofDecoderLib.decodeJournal(journalData);

        // temporary overwrite; will be removed in future implementations
        receiver = _sender;

        // checks
        _checkSender(msg.sender, _sender);
        require(_market == address(this), mTokenGateway_AddressNotValid());
        require(_chainId == LINEA_CHAIN_ID, mTokenGateway_ChainNotValid()); // allow only Host
        require(_dstChainId == uint32(block.chainid), mTokenGateway_ChainNotValid());
        require(amount > 0, mTokenGateway_AmountNotValid());
        require(_accAmountOut - accAmountOut[_sender] >= amount, mTokenGateway_AmountTooBig());
        require(IERC20(underlying).balanceOf(address(this)) >= amount, mTokenGateway_ReleaseCashNotAvailable());

        // effects
        accAmountOut[_sender] += amount;

        // interactions
        IERC20(underlying).safeTransfer(_sender, amount);

        emit mTokenGateway_Extracted(
            msg.sender,
            _sender,
            receiver,
            accAmountIn[_sender],
            accAmountOut[_sender],
            amount,
            uint32(_chainId),
            uint32(block.chainid)
        );
    }

    // ----------- PRIVATE ------------
    function _verifyProof(bytes calldata journalData, bytes calldata seal) private {
        require(journalData.length > 0, mTokenGateway_JournalNotValid());

        // verify it using the ZkVerifier contract
        _verifyInput(journalData, seal);
    }

    function _checkSender(address msgSender, address srcSender) private view {
        if (msgSender != srcSender) {
            require(
                allowedCallers[srcSender][msgSender] || msgSender == owner()
                    || rolesOperator.isAllowedFor(msgSender, rolesOperator.PROOF_FORWARDER())
                    || rolesOperator.isAllowedFor(msgSender, rolesOperator.PROOF_BATCH_FORWARDER()),
                mTokenGateway_CallerNotAllowed()
            );
        }
    }
}
