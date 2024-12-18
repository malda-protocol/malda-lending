// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {BytesLib} from "src/libraries/BytesLib.sol";

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

library mTokenProofDecoderLib {
    function decodeJournal(bytes memory journalData)
        external
        pure
        returns (address sender, address market, uint256 accAmountIn, uint256 accAmountOut, uint32 chainId)
    {
        // decode action data
        // | Offset | Length | Data Type               |
        // |--------|---------|----------------------- |
        // | 0      | 20      | address sender         |
        // | 20     | 40      | address market         |
        // | 40     | 32      | uint256 accAmountIn    |
        // | 72     | 32      | uint256 accAmountOut   |
        // | 104    | 4       | uint32 chainId         |
        sender = BytesLib.toAddress(BytesLib.slice(journalData, 0, 20), 0);
        market = BytesLib.toAddress(BytesLib.slice(journalData, 20, 20), 0);
        accAmountIn = BytesLib.toUint256(BytesLib.slice(journalData, 40, 32), 0);
        accAmountOut = BytesLib.toUint256(BytesLib.slice(journalData, 72, 32), 0);
        chainId = BytesLib.toUint32(BytesLib.slice(journalData, 104, 4), 0);
    }

    function encodeJournal(address sender, address market, uint256 accAmountIn, uint256 accAmountOut, uint32 chainId)
        external
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(sender, market, accAmountIn, accAmountOut, chainId);
    }
}
