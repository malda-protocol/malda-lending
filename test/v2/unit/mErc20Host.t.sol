// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {mErc20Host_admin as LegacyMErc20HostAdmin} from "test/unit/mErc20Host/mErc20Host_admin.t.sol";
import {mErc20Host_borrow as LegacyMErc20HostBorrow} from "test/unit/mErc20Host/mErc20Host_borrow.t.sol";
import {mErc20Host_liquidate as LegacyMErc20HostLiquidate} from "test/unit/mErc20Host/mErc20Host_liquidate.t.sol";
import {mErc20Host_mint as LegacyMErc20HostMint} from "test/unit/mErc20Host/mErc20Host_mint.t.sol";
import {
    mErc20Host_redeem as LegacyMErc20HostRedeem
} from "test/unit/mErc20Host/mErc20Host_redeemAndRedeemUnderlying.t.sol";
import {mErc20Host_repay as LegacyMErc20HostRepay} from "test/unit/mErc20Host/mErc20Host_repay.t.sol";

contract MErc20HostAdminV2 is LegacyMErc20HostAdmin {}

contract MErc20HostBorrowV2 is LegacyMErc20HostBorrow {}

contract MErc20HostLiquidateV2 is LegacyMErc20HostLiquidate {}

contract MErc20HostMintV2 is LegacyMErc20HostMint {}

contract MErc20HostRedeemV2 is LegacyMErc20HostRedeem {}

contract MErc20HostRepayV2 is LegacyMErc20HostRepay {}
