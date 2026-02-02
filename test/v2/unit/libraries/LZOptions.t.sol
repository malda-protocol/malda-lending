// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LZOptions} from "src/libraries/LZOptions.sol";

import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract LZOptionsTest is BaseTest {
    ////////////////////////////////////////////////////////////
    //                       newOptions                       //
    ////////////////////////////////////////////////////////////

    function test_unit_newOptions_success() external {
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bytes memory options = LZOptions.newOptions();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(options, abi.encodePacked(uint16(3)));
    }

    ////////////////////////////////////////////////////////////
    //               addExecutorLzReceiveOption               //
    ////////////////////////////////////////////////////////////

    function test_fuzz_addExecutorLzReceiveOption_success(uint128 gas, uint128 value) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory options = LZOptions.newOptions();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bytes memory updated = LZOptions.addExecutorLzReceiveOption(options, gas, value);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        bytes memory data = abi.encodePacked(gas, value);
        uint16 size = uint16(1 + data.length);
        bytes memory expected = abi.encodePacked(options, uint8(1), size, uint8(1), data);

        assertEq(updated, expected);
    }

    ////////////////////////////////////////////////////////////
    //               addExecutorLzComposeOption               //
    ////////////////////////////////////////////////////////////

    function test_fuzz_addExecutorLzComposeOption_success(uint16 index, uint128 gas, uint128 value) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory options = LZOptions.newOptions();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bytes memory updated = LZOptions.addExecutorLzComposeOption(options, index, gas, value);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        bytes memory data = abi.encodePacked(index, gas, value);
        uint16 size = uint16(1 + data.length);
        bytes memory expected = abi.encodePacked(options, uint8(1), size, uint8(3), data);

        assertEq(updated, expected);
    }

    ////////////////////////////////////////////////////////////
    //           addExecutorOrderedExecutionOption            //
    ////////////////////////////////////////////////////////////

    function test_unit_addExecutorOrderedExecutionOption_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory options = LZOptions.newOptions();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bytes memory updated = LZOptions.addExecutorOrderedExecutionOption(options);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        bytes memory data = bytes("");
        uint16 size = uint16(1 + data.length);
        bytes memory expected = abi.encodePacked(options, uint8(1), size, uint8(4), data);

        assertEq(updated, expected);
    }
}
