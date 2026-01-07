// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {EmptyOperator} from "src/Operator/EmptyOperator.sol";

contract EmptyOperatorTest is Test {
    function testIsOperatorReturnsTrue() public {
        EmptyOperator emptyOperator = new EmptyOperator();
        assertTrue(emptyOperator.isOperator());
    }
}
