// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";
import {LZOptions} from "src/libraries/LZOptions.sol";

contract LZOptionsTest is Test {
    function test_newOptions_returnsType3Prefix() external {
        bytes memory options = LZOptions.newOptions();
        assertEq(options, abi.encodePacked(uint16(3)));
    }

    function test_addExecutorLzReceiveOption_appendsData() external {
        bytes memory options = LZOptions.newOptions();
        uint128 gas = 1000;
        uint128 value = 2000;

        bytes memory updated = LZOptions.addExecutorLzReceiveOption(options, gas, value);

        bytes memory data = abi.encodePacked(gas, value);
        uint16 size = uint16(1 + data.length);
        bytes memory expected = abi.encodePacked(options, uint8(1), size, uint8(1), data);

        assertEq(updated, expected);
    }

    function test_addExecutorLzComposeOption_appendsData() external {
        bytes memory options = LZOptions.newOptions();
        uint16 index = 4;
        uint128 gas = 1111;
        uint128 value = 2222;

        bytes memory updated = LZOptions.addExecutorLzComposeOption(options, index, gas, value);

        bytes memory data = abi.encodePacked(index, gas, value);
        uint16 size = uint16(1 + data.length);
        bytes memory expected = abi.encodePacked(options, uint8(1), size, uint8(3), data);

        assertEq(updated, expected);
    }

    function test_addExecutorOrderedExecutionOption_appendsData() external {
        bytes memory options = LZOptions.newOptions();

        bytes memory updated = LZOptions.addExecutorOrderedExecutionOption(options);

        bytes memory data = bytes("");
        uint16 size = uint16(1 + data.length);
        bytes memory expected = abi.encodePacked(options, uint8(1), size, uint8(4), data);

        assertEq(updated, expected);
    }
}
