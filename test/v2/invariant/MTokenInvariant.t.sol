// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";
import {BaseMTokenTest} from "test/v2/utils/BaseMTokenTest.t.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";

contract MTokenHandler is Test {
    mErc20Host internal mToken;
    address internal actor;
    uint256 public ghostTotalSupply;

    constructor(mErc20Host _mToken, address _actor) {
        mToken = _mToken;
        actor = _actor;
    }

    function mint(uint256 amount) external {
        amount = bound(amount, 1e6, 1e24);
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

        _getTokens(weth, users.alice, 1e24);
        vm.startPrank(users.alice);
        weth.approve(address(mWethHost), type(uint256).max);
        vm.stopPrank();

        handler = new MTokenHandler(mWethHost, users.alice);
        targetContract(address(handler));
    }

    function invariant_totalSupply_matchesGhost() public {
        assertEq(mWethHost.totalSupply(), handler.ghostTotalSupply());
    }
}
