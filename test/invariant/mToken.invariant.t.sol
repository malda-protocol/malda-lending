// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
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
        amount = bound(amount, 1, type(uint96).max);
        vm.startPrank(actor);
        mToken.mint(amount, actor, amount - 1);
        vm.stopPrank();
        ghostTotalSupply += amount;
    }

    function redeem(uint256 amount) external {
        uint256 balance = mToken.balanceOf(actor);
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

        _getTokens(weth, users.alice, type(uint96).max);
        vm.startPrank(users.alice);
        weth.approve(address(mWethHost), type(uint256).max);
        vm.stopPrank();

        handler = new MTokenHandler(mWethHost, users.alice);
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
