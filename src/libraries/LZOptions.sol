// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|
*/

// @dev lib for lzCompose and similar extraOptions LZ allows
/// @title LZOptions
/// @author Malda Protocol
/// @notice LZ Options implementation
library LZOptions {
    uint16 internal constant TYPE_3 = 3;

    uint8 internal constant WORKER_ID = 1;
    uint8 internal constant OPTION_TYPE_LZRECEIVE = 1;
    uint8 internal constant OPTION_TYPE_LZCOMPOSE = 3;
    uint8 internal constant OPTION_TYPE_ORDERED_EXECUTION = 4;

    function newOptions() internal pure returns (bytes memory) {
        return abi.encodePacked(TYPE_3);
    }

    function addExecutorLzReceiveOption(bytes memory options, uint128 gas, uint128 value)
        internal
        pure
        returns (bytes memory)
    {
        // data = gas (16) + value (16) = 32 bytes
        bytes memory data = abi.encodePacked(gas, value);
        // size = 1 (optionType) + 32 (data) = 33 = 0x0021
        uint16 size = uint16(1 + data.length);

        return abi.encodePacked(options, WORKER_ID, size, OPTION_TYPE_LZRECEIVE, data);
    }

    function addExecutorLzComposeOption(bytes memory options, uint16 index, uint128 gas, uint128 value)
        internal
        pure
        returns (bytes memory)
    {
        // data = index (2) + gas (16) + value (16) = 34 bytes
        bytes memory data = abi.encodePacked(index, gas, value);
        // size = 1 (optionType) + 34 (data) = 35 = 0x0023
        uint16 size = uint16(1 + data.length);

        return abi.encodePacked(options, WORKER_ID, size, OPTION_TYPE_LZCOMPOSE, data);
    }

    function addExecutorOrderedExecutionOption(bytes memory options) internal pure returns (bytes memory) {
        bytes memory data = bytes("");
        uint16 size = uint16(1 + data.length);
        return abi.encodePacked(options, WORKER_ID, size, OPTION_TYPE_ORDERED_EXECUTION, data);
    }
}
