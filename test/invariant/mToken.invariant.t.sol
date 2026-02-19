// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BaseTest} from "test/utils/BaseTest.t.sol";
import {BaseMTokenTest} from "test/utils/BaseMTokenTest.t.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";

contract MTokenHandler is BaseTest {
    mErc20Host internal mToken;
    address internal actor;
    uint256 public ghostTotalSupply;

    constructor(mErc20Host _mToken, address _actor) {
        mToken = _mToken;
        actor = _actor;
    }

    function mint(uint256 amount) external {
        uint256 balance = IERC20(mToken.underlying()).balanceOf(actor);
        if (balance <= DEFAULT_INFLATION_INCREASE) {
            return;
        }

        amount = bound(amount, DEFAULT_INFLATION_INCREASE + 1, balance);
        vm.startPrank(actor);
        mToken.mint(amount, actor, amount - DEFAULT_INFLATION_INCREASE);
        vm.stopPrank();
        ghostTotalSupply += amount;
    }

    function redeem(uint256 amount) external {
        uint256 balance = mToken.balanceOf(actor);
        if (balance == 0) {
            return;
        }

        amount = bound(amount, 1, balance);
        vm.startPrank(actor);
        mToken.redeem(amount);
        vm.stopPrank();
        ghostTotalSupply -= amount;
    }
}

contract MTokenInvariantTest is BaseMTokenTest {
    MTokenHandler internal handler;

    function setUp() public override {
        super.setUp();

        operator.supportMarket(address(mWethHost));
        oracleOperator.setUnderlyingPrice(DEFAULT_ORACLE_PRICE);
        _getTokens(weth, users.alice, type(uint96).max);
        vm.startPrank(users.alice);
        weth.approve(address(mWethHost), type(uint256).max);
        vm.stopPrank();

        handler = new MTokenHandler(mWethHost, users.alice);
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = MTokenHandler.mint.selector;
        selectors[1] = MTokenHandler.redeem.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_totalSupply_matchesGhost() public view {
        assertEq(
            mWethHost.totalSupply(),
            handler.ghostTotalSupply(),
            "expected mWethHost.totalSupply() to equal handler.ghostTotalSupply()"
        );
    }
}
