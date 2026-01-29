// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {mErc20_borrow as LegacyMErc20Borrow} from "test/unit/mErc20/mErc20_borrow.t.sol";
import {mErc20_initialize as LegacyMErc20Initialize} from "test/unit/mErc20/mErc20_initialize.t.sol";
import {mErc20_liquidateHelper as LegacyMErc20LiquidateHelper} from "test/unit/mErc20/mErc20_liquidateHelper.t.sol";
import {mErc20_mint as LegacyMErc20Mint} from "test/unit/mErc20/mErc20_mint.t.sol";
import {mErc20_redeem as LegacyMErc20Redeem} from "test/unit/mErc20/mErc20_redeemAndRedeemUnderlying.t.sol";
import {mErc20_repay as LegacyMErc20Repay} from "test/unit/mErc20/mErc20_repay.t.sol";
import {mErc20_sweepToken as LegacyMErc20SweepToken} from "test/unit/mErc20/mErc20_sweepToken.t.sol";

contract MErc20BorrowV2 is LegacyMErc20Borrow {}

contract MErc20InitializeV2 is LegacyMErc20Initialize {}

contract MErc20LiquidateHelperV2 is LegacyMErc20LiquidateHelper {}

contract MErc20MintV2 is LegacyMErc20Mint {}

contract MErc20RedeemV2 is LegacyMErc20Redeem {}

contract MErc20RepayV2 is LegacyMErc20Repay {}

contract MErc20SweepTokenV2 is LegacyMErc20SweepToken {}
