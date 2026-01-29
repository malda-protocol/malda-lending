// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {DeployerTest as LegacyDeployerTest} from "test/unit/utils/Deployer.t.sol";
import {ExponentialNoErrorTest as LegacyExponentialNoErrorTest} from "test/unit/utils/ExponentialNoError.t.sol";
import {WrapAndSupplyTest as LegacyWrapAndSupplyTest} from "test/unit/utils/WrapAndSupply.t.sol";

contract DeployerTestV2 is LegacyDeployerTest {}

contract ExponentialNoErrorTestV2 is LegacyExponentialNoErrorTest {}

contract WrapAndSupplyTestV2 is LegacyWrapAndSupplyTest {}
