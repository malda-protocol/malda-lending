// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {
    BatchSubmitter_constructor as LegacyBatchSubmitterConstructor
} from "test/unit/BatchSubmitter/BatchSubmitter_constructor.t.sol";
import {
    BatchSubmitter_methods as LegacyBatchSubmitterMethods
} from "test/unit/BatchSubmitter/BatchSubmitter_methods.t.sol";

contract BatchSubmitterConstructorV2 is LegacyBatchSubmitterConstructor {}

contract BatchSubmitterMethodsV2 is LegacyBatchSubmitterMethods {}
