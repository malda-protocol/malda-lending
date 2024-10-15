// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.27;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

// interfaces
import {IZkVerifierImageRegistry} from "../../interfaces/IZkVerifierImageRegistry.sol";

// contracts
import {mErc20} from "../mErc20.sol";
import {Steel} from "risc0/steel/Steel.sol";
import {ZkVerifier} from "../../verifier/ZkVerifier.sol";

contract mErc20Host is mErc20, ZkVerifier {
    // ----------- STORAGE ------------
    enum ImageIdIndexes {
        Mint, //0
        Borrow, //1
        Repay, //2
        Withdraw //3
            //TODO: add rest

    }

    error mErc20Host_AmountNotValid();
    error mErc20Host_JournalNotValid();

    constructor(address payable _admin) mErc20(_admin) {}

    /**
     * @notice Constructs the new money market
     * @param underlying_ The address of the underlying asset
     * @param operator_ The address of the Operator
     * @param interestRateModel_ The address of the interest rate model
     * @param initialExchangeRateMantissa_ The initial exchange rate, scaled by 1e18
     * @param name_ ERC-20 name of this token
     * @param symbol_ ERC-20 symbol of this token
     * @param decimals_ ERC-20 decimal precision of this token
     * @param zkVerifier_ The IRiscZeroVerifier address
     * @param zkVerifierImageRegistry_ The IZkVerifierImageRegistry address
     */
    function initialize(
        address underlying_,
        address operator_,
        address interestRateModel_,
        uint256 initialExchangeRateMantissa_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address zkVerifier_,
        address zkVerifierImageRegistry_
    ) external {
        // Initialize the market
        super.initialize(
            underlying_, operator_, interestRateModel_, initialExchangeRateMantissa_, name_, symbol_, decimals_
        );

        // Initialize the ZkVerifier
        ZkVerifier.initialize(zkVerifier_, zkVerifierImageRegistry_);
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
    // todo: probably need to avoid `_doTransferIn`; check it during tests
    function mintExternal(bytes calldata journalData, bytes calldata seal) external {
        // verify received data
        _verifyProof(ImageIdIndexes.Mint, journalData, seal);

        // decode action data
        uint256 mintAmount = abi.decode(journalData[96:], (uint256));

        // checks
        require(mintAmount > 0, mErc20Host_AmountNotValid());

        // actions
        _mint(mintAmount, false);
    }

    function borrowExternal(bytes calldata journalData, bytes calldata seal) external {
        // verify received data
        _verifyProof(ImageIdIndexes.Borrow, journalData, seal);

        // decode action data
        uint256 borrowAmount = abi.decode(journalData[96:], (uint256));

        // checks
        require(borrowAmount > 0, mErc20Host_AmountNotValid());

        // actions
        _borrow(borrowAmount);
    }

    function repayExternal(bytes calldata journalData, bytes calldata seal) external {
    }

    function withdrawExternal(bytes calldata journalData, bytes calldata seal) external {
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
}
