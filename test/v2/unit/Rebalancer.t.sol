// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Rebalancer_methods as LegacyRebalancerMethods} from "test/unit/Rebalancer/Rebalancer_methods.t.sol";
import {Rebalancer_admin as LegacyRebalancerAdmin} from "test/unit/Rebalancer/Rebalancer_admin.t.sol";

contract RebalancerMethodsV2 is LegacyRebalancerMethods {}

contract RebalancerAdminV2 is LegacyRebalancerAdmin {}
