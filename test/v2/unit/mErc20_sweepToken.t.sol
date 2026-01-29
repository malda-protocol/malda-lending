// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {mErc20} from "src/mToken/mErc20.sol";

import {mToken_Unit_Shared} from "test/unit/shared/mToken_Unit_Shared.t.sol";

contract mErc20_sweepToken is mToken_Unit_Shared {
    function testSweepTokenTransfersNonUnderlying() external {
        uint256 amount = 100;
        _getTokens(dai, address(mWeth), amount);

        uint256 adminBalanceBefore = dai.balanceOf(address(this));
        mWeth.sweepToken(IERC20(address(dai)), amount);

        assertEq(dai.balanceOf(address(mWeth)), 0);
        assertEq(dai.balanceOf(address(this)), adminBalanceBefore + amount);
    }

    function testSweepTokenRevertsOnUnderlying() external {
        vm.expectRevert(mErc20.mErc20_TokenNotValid.selector);
        mWeth.sweepToken(IERC20(address(weth)), 1);
    }
}
