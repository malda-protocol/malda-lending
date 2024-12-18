// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

//interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//contracts
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {mErc20Immutable} from "src/mToken/mErc20Immutable.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";
import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";

import {Base_Unit_Test} from "../../Base_Unit_Test.t.sol";

import {ERC20Mock} from "../../mocks/ERC20Mock.sol";
import {Risc0VerifierMock} from "../../mocks/Risc0VerifierMock.sol";

abstract contract mToken_Unit_Shared is Base_Unit_Test {
    // ----------- STORAGE ------------
    mErc20Host public mWethHost;
    mErc20Host public mDaiHost;
    mErc20Immutable public mWeth;
    mTokenGateway public mWethExtension;

    Risc0VerifierMock public verifierMock;

    struct Commitment {
        uint256 id;
        bytes32 digest;
        bytes32 configID;
    }

    function setUp() public virtual override {
        super.setUp();

        verifierMock = new Risc0VerifierMock();
        vm.label(address(verifierMock), "verifierMock");

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
            address(verifierMock)
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
            address(verifierMock)
        );
        vm.label(address(mDaiHost), "mDaiHost");

        mWethExtension = new mTokenGateway(payable(address(this)), address(weth), address(roles), address(verifierMock));

        mDaiHost.setImageId("0x123");
        mWethHost.setImageId("0x123");
        mWethExtension.setImageId("0x123");
    }
    // ----------- HELPERS ------------

    function _createAccumulatedAmountJournal(address sender, address market, uint256 accAmount)
        internal
        view
        returns (bytes memory)
    {
        // decode action data
        // | Offset | Length | Data Type               |
        // |--------|---------|----------------------- |
        // | 0      | 20      | address sender         |
        // | 20     | 40      | address market         |
        // | 40     | 32      | uint256 accAmountIn    |
        // | 72     | 32      | uint256 accAmountOut   |
        // | 104    | 4       | uint32 chainId         |
        return abi.encodePacked(sender, market, accAmount, accAmount, uint32(block.chainid));
    }

    function _borrowPrerequisites(address mToken, uint256 supplyAmount) internal {
        address underlying = mErc20Immutable(mToken).underlying();
        _getTokens(ERC20Mock(underlying), address(this), supplyAmount);
        IERC20(underlying).approve(mToken, supplyAmount);
        mErc20Immutable(mToken).mint(supplyAmount);
    }

    // function _borrowGatewayPrerequisites(address mGateway, uint256 supplyAmount) internal {
    //     address underlying = mTokenGateway(mGateway).underlying();
    //     _getTokens(ERC20Mock(underlying), address(this), supplyAmount);
    //     IERC20(underlying).approve(mGateway, supplyAmount);
    //     mTokenGateway(mGateway).mintOnHost(supplyAmount);
    // }

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

    modifier whenMarketEntered(address mToken) {
        address[] memory mTokens = new address[](1);
        mTokens[0] = mToken;
        operator.enterMarkets(mTokens);
        operator.setCollateralFactor(mToken, DEFAULT_COLLATERAL_FACTOR);
        _;
    }
}
