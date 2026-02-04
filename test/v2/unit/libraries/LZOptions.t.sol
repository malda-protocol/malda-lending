// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LZOptions} from "src/libraries/LZOptions.sol";

import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract LZOptionsTest is BaseTest {
    bytes internal options_;

    function setUp() public override {
        super.setUp();

        options_ = LZOptions.newOptions();
    }

    ////////////////////////////////////////////////////////////
    //                       newOptions                       //
    ////////////////////////////////////////////////////////////

    function test_unit_newOptions_success() external {
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(options_, abi.encodePacked(uint16(3)), "expected options_ to equal abi.encodePacked(uint16(3))");
    }

    ////////////////////////////////////////////////////////////
    //               addExecutorLzReceiveOption               //
    ////////////////////////////////////////////////////////////

    function test_fuzz_addExecutorLzReceiveOption_success(uint128 gas, uint128 value) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~

        bytes memory updated = LZOptions.addExecutorLzReceiveOption(options_, gas, value);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        bytes memory data = abi.encodePacked(gas, value);
        uint16 size = uint16(1 + data.length);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bytes memory expected = abi.encodePacked(options_, uint8(1), size, uint8(1), data);

        assertEq(updated, expected, "expected updated to equal expected");
    }

    ////////////////////////////////////////////////////////////
    //               addExecutorLzComposeOption               //
    ////////////////////////////////////////////////////////////

    function test_fuzz_addExecutorLzComposeOption_success(uint16 index, uint128 gas, uint128 value) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~

        bytes memory updated = LZOptions.addExecutorLzComposeOption(options_, index, gas, value);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        bytes memory data = abi.encodePacked(index, gas, value);
        uint16 size = uint16(1 + data.length);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bytes memory expected = abi.encodePacked(options_, uint8(1), size, uint8(3), data);

        assertEq(updated, expected, "expected updated to equal expected");
    }

    ////////////////////////////////////////////////////////////
    //           addExecutorOrderedExecutionOption            //
    ////////////////////////////////////////////////////////////

    function test_unit_addExecutorOrderedExecutionOption_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~

        bytes memory updated = LZOptions.addExecutorOrderedExecutionOption(options_);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        bytes memory data = bytes("");
        uint16 size = uint16(1 + data.length);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bytes memory expected = abi.encodePacked(options_, uint8(1), size, uint8(4), data);

        assertEq(updated, expected, "expected updated to equal expected");
    }
}
