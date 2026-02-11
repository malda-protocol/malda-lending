// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {SafeApprove} from "src/libraries/SafeApprove.sol";

contract SafeApproveHarness {
    using SafeApprove for address;

    function callSafeApprove(address token, address spender, uint256 value) external {
        token.safeApprove(spender, value);
    }
}
