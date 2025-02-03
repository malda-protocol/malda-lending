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
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// contracts
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";
import {mErc20Upgradable} from "src/mToken/mErc20Upgradable.sol";

import {mTokenProofDecoderLib} from "src/libraries/mTokenProofDecoderLib.sol";

import {ImErc20Host} from "src/interfaces/ImErc20Host.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";
import {IRoles} from "src/interfaces/IRoles.sol";

contract mErc20Host is mErc20Upgradable, ZkVerifier, ImErc20Host, ImTokenOperationTypes {
    using SafeERC20 for IERC20;

    // ----------- STORAGE ------------
    mapping(uint32 => mapping(address => uint256)) public accAmountInPerChain;
    mapping(uint32 => mapping(address => uint256)) public accAmountOutPerChain;
    mapping(address => mapping(address => bool)) public allowedCallers;
    mapping(uint32 => bool) public allowedChains;

    /**
     * @notice Initializes the new money market
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
    function initialize(
        address underlying_,
        address operator_,
        address interestRateModel_,
        uint256 initialExchangeRateMantissa_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address payable admin_,
        address zkVerifier_,
        address roles_
    ) external initializer {
        // Initialize the base contract
        proxyInitialize(
            underlying_, operator_, interestRateModel_, initialExchangeRateMantissa_, name_, symbol_, decimals_, admin_
        );

        // Initialize the ZkVerifier
        ZkVerifier.initialize(zkVerifier_);

        rolesOperator = IRoles(roles_);

        // Set the proper admin now that initialization is done
        admin = admin_;
    }

    // ----------- VIEW ------------
    /**
     * @inheritdoc ImErc20Host
     */
    function isCallerAllowed(address sender, address caller) external view returns (bool) {
        return allowedCallers[sender][caller];
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function getProofData(address user, uint32 dstId) external view returns (bytes memory) {
        return mTokenProofDecoderLib.encodeJournal(
            user,
            address(this),
            accAmountInPerChain[dstId][user],
            accAmountOutPerChain[dstId][user],
            uint32(block.chainid),
            dstId
        );
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

    /**
     * @notice Updates an allowed chain status
     * @param _chainId the chain id
     * @param _status the new status
     */
    function updateAllowedChain(uint32 _chainId, bool _status) external {
        if (msg.sender != admin && !rolesOperator.isAllowedFor(msg.sender, rolesOperator.CHAINS_MANAGER())) {
            revert mErc20Host_CallerNotAllowed();
        }
        allowedChains[_chainId] = _status;
        emit mErc20Host_ChainStatusUpdated(_chainId, _status);
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function extractForRebalancing(uint256 amount) external {
        if (!rolesOperator.isAllowedFor(msg.sender, rolesOperator.REBALANCER())) revert mErc20Host_NotRebalancer();
        IERC20(underlying).safeTransfer(msg.sender, amount);
    }

    // ----------- PUBLIC ------------
    /**
     * @inheritdoc ImErc20Host
     */
    function updateAllowedCallerStatus(address caller, bool status) external override {
        allowedCallers[msg.sender][caller] = status;
        emit AllowedCallerUpdated(msg.sender, caller, status);
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function liquidateExternal(
        bytes calldata journalData,
        bytes calldata seal,
        address[] calldata userToLiquidate,
        uint256[] calldata liquidateAmount,
        address[] calldata collateral,
        address receiver
    ) external override {
        // verify received data
        if (!rolesOperator.isAllowedFor(msg.sender, rolesOperator.PROOF_BATCH_FORWARDER())) {
            _verifyProof(journalData, seal);
        }

        bytes[] memory journals = abi.decode(journalData, (bytes[]));
        uint256 length = journals.length;
        require(length == liquidateAmount.length, mErc20Host_LengthMismatch());
        require(length == userToLiquidate.length, mErc20Host_LengthMismatch());
        require(length == collateral.length, mErc20Host_LengthMismatch());

        for (uint256 i; i < length;) {
            _liquidateExternal(journals[i], userToLiquidate[i], liquidateAmount[i], collateral[i], receiver);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function mintExternal(
        bytes calldata journalData,
        bytes calldata seal,
        uint256[] calldata mintAmount,
        address receiver
    ) external override {
        if (!rolesOperator.isAllowedFor(msg.sender, rolesOperator.PROOF_BATCH_FORWARDER())) {
            _verifyProof(journalData, seal);
        }

        bytes[] memory journals = abi.decode(journalData, (bytes[]));
        uint256 length = journals.length;
        require(length == mintAmount.length, mErc20Host_LengthMismatch());

        for (uint256 i; i < length;) {
            _mintExternal(journals[i], mintAmount[i], receiver);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function repayExternal(
        bytes calldata journalData,
        bytes calldata seal,
        uint256[] calldata repayAmount,
        address receiver
    ) external override {
        if (!rolesOperator.isAllowedFor(msg.sender, rolesOperator.PROOF_BATCH_FORWARDER())) {
            _verifyProof(journalData, seal);
        }

        bytes[] memory journals = abi.decode(journalData, (bytes[]));
        uint256 length = journals.length;
        require(length == repayAmount.length, mErc20Host_LengthMismatch());

        for (uint256 i; i < length;) {
            _repayExternal(journals[i], repayAmount[i], receiver);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @inheritdoc ImErc20Host
     * @dev amount represents the number of mTokens to redeem
     */
    function withdrawOnExtension(uint256 amount, uint32 dstChainId) external override {
        require(amount > 0, mErc20Host_AmountNotValid());

        // actions
        uint256 underlyingAmount = _redeem(msg.sender, amount, false);
        accAmountOutPerChain[dstChainId][msg.sender] += underlyingAmount;

        emit mErc20Host_WithdrawOnExtensionChain(msg.sender, dstChainId, amount);
    }

    /**
     * @inheritdoc ImErc20Host
     */
    function borrowOnExtension(uint256 amount, uint32 dstChainId) external override {
        require(amount > 0, mErc20Host_AmountNotValid());

        // actions
        accAmountOutPerChain[dstChainId][msg.sender] += amount;
        _borrow(msg.sender, amount, false);

        emit mErc20Host_BorrowOnExternsionChain(msg.sender, dstChainId, amount);
    }

    // ----------- PRIVATE ------------
    function _verifyProof(bytes calldata journalData, bytes calldata seal) private {
        require(journalData.length > 0, mErc20Host_JournalNotValid());

        // verify it using the ZkVerifier contract
        _verifyInput(journalData, seal);
    }

    function _checkSender(address msgSender, address srcSender) private view {
        if (msgSender != srcSender) {
            require(
                allowedCallers[srcSender][msgSender] || msgSender == admin
                    || rolesOperator.isAllowedFor(msgSender, rolesOperator.PROOF_FORWARDER())
                    || rolesOperator.isAllowedFor(msgSender, rolesOperator.PROOF_BATCH_FORWARDER()),
                mErc20Host_CallerNotAllowed()
            );
        }
    }

    function _liquidateExternal(
        bytes memory singleJournal,
        address userToLiquidate,
        uint256 liquidateAmount,
        address collateral,
        address receiver
    ) internal {
        (address _sender, address _market, uint256 _accAmountIn,, uint32 _chainId, uint32 _dstChainId) =
            mTokenProofDecoderLib.decodeJournal(singleJournal);

        receiver = _sender;

        // base checks
        {
            _checkSender(msg.sender, _sender);
            require(_dstChainId == uint32(block.chainid), mErc20Host_DstChainNotValid());
            require(_market == address(this), mErc20Host_AddressNotValid());
            require(allowedChains[_chainId], mErc20Host_ChainNotValid());
        }
        // operation checks
        {
            require(liquidateAmount > 0, mErc20Host_AmountNotValid());
            require(liquidateAmount <= _accAmountIn - accAmountInPerChain[_chainId][_sender], mErc20Host_AmountTooBig());
            require(userToLiquidate != msg.sender && userToLiquidate != _sender, mErc20Host_CallerNotAllowed());
        }
        collateral = collateral == address(0) ? address(this) : collateral;

        // actions
        accAmountInPerChain[_chainId][_sender] += liquidateAmount;
        _liquidate(receiver, userToLiquidate, liquidateAmount, collateral, false);

        emit mErc20Host_LiquidateExternal(
            msg.sender, _sender, userToLiquidate, receiver, collateral, _chainId, liquidateAmount
        );
    }

    function _mintExternal(bytes memory singleJournal, uint256 mintAmount, address receiver) internal {
        (address _sender, address _market, uint256 _accAmountIn,, uint32 _chainId, uint32 _dstChainId) =
            mTokenProofDecoderLib.decodeJournal(singleJournal);

        receiver = _sender;

        // base checks
        {
            _checkSender(msg.sender, _sender);
            require(_dstChainId == uint32(block.chainid), mErc20Host_DstChainNotValid());
            require(_market == address(this), mErc20Host_AddressNotValid());
            require(allowedChains[_chainId], mErc20Host_ChainNotValid());
        }
        // operation checks
        {
            require(mintAmount > 0, mErc20Host_AmountNotValid());
            require(mintAmount <= _accAmountIn - accAmountInPerChain[_chainId][_sender], mErc20Host_AmountTooBig());
        }

        // actions
        accAmountInPerChain[_chainId][_sender] += mintAmount;
        _mint(receiver, mintAmount, false);

        emit mErc20Host_MintExternal(msg.sender, _sender, receiver, _chainId, mintAmount);
    }

    function _repayExternal(bytes memory singleJournal, uint256 repayAmount, address receiver) internal {
        (address _sender, address _market, uint256 _accAmountIn,, uint32 _chainId, uint32 _dstChainId) =
            mTokenProofDecoderLib.decodeJournal(singleJournal);

        receiver = _sender;

        // base checks
        {
            _checkSender(msg.sender, _sender);
            require(_dstChainId == uint32(block.chainid), mErc20Host_DstChainNotValid());
            require(_market == address(this), mErc20Host_AddressNotValid());
            require(allowedChains[_chainId], mErc20Host_ChainNotValid());
        }
        // operation checks
        {
            require(repayAmount > 0, mErc20Host_AmountNotValid());
            require(repayAmount <= _accAmountIn - accAmountInPerChain[_chainId][_sender], mErc20Host_AmountTooBig());
        }

        // actions
        accAmountInPerChain[_chainId][_sender] += repayAmount;
        _repayBehalf(receiver, repayAmount, false);

        emit mErc20Host_RepayExternal(msg.sender, _sender, receiver, _chainId, repayAmount);
    }
}
