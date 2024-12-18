// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

//interfaces
import {IRoles} from "src/interfaces/IRoles.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//contracts
import {mTokenLogs} from "src/mToken/mTokenLogs.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {mErc20Immutable} from "src/mToken/mErc20Immutable.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";
import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {ZkVerifierImageRegistry} from "src/verifier/ZkVerifierImageRegistry.sol";

import {Base_Unit_Test} from "../../Base_Unit_Test.t.sol";

import {ERC20Mock} from "../../mocks/ERC20Mock.sol";
import {Risc0VerifierMock} from "../../mocks/Risc0VerifierMock.sol";

abstract contract mToken_Unit_Shared is Base_Unit_Test {
    // ----------- STORAGE ------------
    mErc20Host public mWethHost;
    mErc20Host public mDaiHost;
    mErc20Immutable public mWeth;
    mTokenGateway public mWethExtension;
    mTokenLogs public operationsLog;

    Risc0VerifierMock public verifierMock;
    ZkVerifierImageRegistry public verifierImageRegistry;

    struct Commitment {
        uint256 id;
        bytes32 digest;
        bytes32 configID;
    }

    function setUp() public virtual override {
        super.setUp();

        verifierMock = new Risc0VerifierMock();
        vm.label(address(verifierMock), "verifierMock");

        verifierImageRegistry = new ZkVerifierImageRegistry(address(this));
        vm.label(address(verifierImageRegistry), "verifierImageRegistry");

        operationsLog = new mTokenLogs(address(roles));
        vm.label(address(operationsLog), "mTokenLogs");

        mWeth = new mErc20Immutable(
            address(weth),
            address(operator),
            address(interestModel),
            1e18,
            "Market WETH",
            "mWeth",
            18,
            payable(address(this))
        );
        vm.label(address(mWeth), "mWeth");

        mWethHost = new mErc20Host(
            address(weth),
            address(operator),
            address(interestModel),
            1e18,
            "Market WETH",
            "mWeth",
            18,
            payable(address(this)),
            address(verifierMock),
            address(verifierImageRegistry),
            address(operationsLog)
        );
        vm.label(address(mWethHost), "mWethHost");

        mDaiHost = new mErc20Host(
            address(dai),
            address(operator),
            address(interestModel),
            1e18,
            "Market DAI",
            "mDai",
            18,
            payable(address(this)),
            address(verifierMock),
            address(verifierImageRegistry),
            address(operationsLog)
        );
        vm.label(address(mDaiHost), "mDaiHost");

        mWethExtension = new mTokenGateway(
            payable(address(this)),
            address(weth),
            address(roles),
            address(verifierMock),
            address(verifierImageRegistry),
            address(operationsLog)
        );

        // post deployment roles
        roles.allowFor(address(mWethHost), roles.LOGS_ADD(), true);
        roles.allowFor(address(mDaiHost), roles.LOGS_ADD(), true);
        roles.allowFor(address(mWethExtension), roles.LOGS_ADD(), true);
    }
    // ----------- HELPERS ------------

    function _createJournal() internal pure returns (bytes memory) {
        return "";
    }

    function _createJournal(uint256 amount) internal pure returns (bytes memory) {
        return abi.encodePacked(amount);
    }

    function _createJournal(uint256 amount, address user) internal pure returns (bytes memory) {
        return abi.encodePacked(amount, user);
    }

    function _createJournal(uint256 amount, address user, uint32 nonce) internal view returns (bytes memory) {
        return abi.encodePacked(amount, user, nonce, uint32(block.chainid));
    }

    function _createLiquidationJournal(uint256 amount, address user, uint32 nonce)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(amount, address(this), user, address(0), nonce, uint32(block.chainid));
    }

    function _createLiquidationJournal(uint256 amount, address liquidator, address user, uint32 nonce)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(amount, liquidator, user, address(0), nonce, uint32(block.chainid));
    }

    function _createLiquidationJournal(
        uint256 amount,
        address liquidator,
        address user,
        address collateral,
        uint32 nonce
    ) internal view returns (bytes memory) {
        return abi.encodePacked(amount, liquidator, user, collateral, nonce, uint32(block.chainid));
    }

    function _createCommitmentWithDstChain(uint256 amount, address user, uint32 chainId)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(amount, user, chainId);
    }

    function _createCommitmentWithDstChain(uint256 amount, address user, uint32 nonce, uint32 chainId)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(amount, user, nonce, chainId);
    }

    function _borrowPrerequisites(address mToken, uint256 supplyAmount) internal {
        address underlying = mErc20Immutable(mToken).underlying();
        _getTokens(ERC20Mock(underlying), address(this), supplyAmount);
        IERC20(underlying).approve(mToken, supplyAmount);
        mErc20Immutable(mToken).mint(supplyAmount);
    }

    function _borrowGatewayPrerequisites(address mGateway, uint256 supplyAmount) internal {
        address underlying = mTokenGateway(mGateway).underlying();
        _getTokens(ERC20Mock(underlying), address(this), supplyAmount);
        IERC20(underlying).approve(mGateway, supplyAmount);
        mTokenGateway(mGateway).mintOnHost(supplyAmount);
    }

    function _repayPrerequisites(address mToken, uint256 supplyAmount, uint256 borrowAmount) internal {
        _borrowPrerequisites(mToken, supplyAmount);
        mErc20Immutable(mToken).borrow(borrowAmount);
    }

    // ----------- MODIFIERS ------------
    modifier whenPaused(address mToken, ImTokenOperationTypes.OperationType pauseType) {
        operator.setPaused(mToken, pauseType, true);
        _;
    }

    modifier whenNotPaused(address mToken, ImTokenOperationTypes.OperationType pauseType) {
        operator.setPaused(mToken, pauseType, false);
        _;
    }

    modifier whenMarketIsListed(address mToken) {
        operator.supportMarket(mToken);
        _;
    }

    modifier whenSupplyCapReached(address mToken, uint256 amount) {
        address[] memory mTokens = new address[](1);
        uint256[] memory caps = new uint256[](1);
        mTokens[0] = mToken;
        caps[0] = amount - 1;
        operator.setMarketSupplyCaps(mTokens, caps);
        _;
    }

    modifier whenBorrowCapReached(address mToken, uint256 amount) {
        address[] memory mTokens = new address[](1);
        uint256[] memory caps = new uint256[](1);
        mTokens[0] = mToken;
        caps[0] = amount - 1;
        operator.setMarketBorrowCaps(mTokens, caps);
        _;
    }

    modifier whenImageIdExists() {
        verifierImageRegistry.addImageId(bytes32("0x1233"));
        verifierImageRegistry.addImageId(bytes32("0x1234"));
        verifierImageRegistry.addImageId(bytes32("0x1235"));
        verifierImageRegistry.addImageId(bytes32("0x1236"));
        verifierImageRegistry.addImageId(bytes32("0x1237"));
        verifierImageRegistry.addImageId(bytes32("0x1238"));
        verifierImageRegistry.addImageId(bytes32("0x1239"));
        verifierImageRegistry.addImageId(bytes32("0x1240"));
        verifierImageRegistry.addImageId(bytes32("0x1241"));
        verifierImageRegistry.addImageId(bytes32("0x1242"));
        verifierImageRegistry.addImageId(bytes32("0x1243"));
        verifierImageRegistry.addImageId(bytes32("0x1244"));
        verifierImageRegistry.addImageId(bytes32("0x1245"));
        verifierImageRegistry.addImageId(bytes32("0x12455"));
        verifierImageRegistry.addImageId(bytes32("0x12456"));
        verifierImageRegistry.addImageId(bytes32("0x12457"));
        verifierImageRegistry.addImageId(bytes32("0x12458"));
        _;
    }

    modifier whenMarketEntered(address mToken) {
        address[] memory mTokens = new address[](1);
        mTokens[0] = mToken;
        operator.enterMarkets(mTokens);
        operator.setCollateralFactor(mToken, DEFAULT_COLLATERAL_FACTOR);
        _;
    }
}
