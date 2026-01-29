// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";
import {LZOptions} from "src/libraries/LZOptions.sol";

contract LZOptionsTest is BaseTest {
    ////////////////////////////////////////////////////////////
    //                        NewOptions                        //
    ////////////////////////////////////////////////////////////

    function test_unitNewOptions_success_returnsType3Prefix() external {
        bytes memory options = LZOptions.newOptions();
        assertEq(options, abi.encodePacked(uint16(3)));
    }

    ////////////////////////////////////////////////////////////
    //                AddExecutorLzReceiveOption                //
    ////////////////////////////////////////////////////////////

    function test_unitAddExecutorLzReceiveOption_success_appendsData() external {
        bytes memory options = LZOptions.newOptions();
        uint128 gas = 1000;
        uint128 value = 2000;

        bytes memory updated = LZOptions.addExecutorLzReceiveOption(options, gas, value);

        bytes memory data = abi.encodePacked(gas, value);
        uint16 size = uint16(1 + data.length);
        bytes memory expected = abi.encodePacked(options, uint8(1), size, uint8(1), data);

        assertEq(updated, expected);
    }

    ////////////////////////////////////////////////////////////
    //                AddExecutorLzComposeOption                //
    ////////////////////////////////////////////////////////////

    function test_unitAddExecutorLzComposeOption_success_appendsData() external {
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

    ////////////////////////////////////////////////////////////
    //            AddExecutorOrderedExecutionOption             //
    ////////////////////////////////////////////////////////////

    function test_unitAddExecutorOrderedExecutionOption_success_appendsData() external {
        bytes memory options = LZOptions.newOptions();

        bytes memory updated = LZOptions.addExecutorOrderedExecutionOption(options);

        bytes memory data = bytes("");
        uint16 size = uint16(1 + data.length);
        bytes memory expected = abi.encodePacked(options, uint8(1), size, uint8(4), data);

        assertEq(updated, expected);
    }
}
