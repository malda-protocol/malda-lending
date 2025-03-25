// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {BytesLib} from "src/libraries/BytesLib.sol";

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

library mTokenProofDecoderLib {
    uint256 public constant ENTRY_SIZE = 113; // 112 + 1 for L1inclusion

    error mTokenProofDecoderLib_ChainNotFound();

    function decodeJournal(bytes memory journalData)
        internal
        pure
        returns (
            address sender,
            address market,
            uint256 accAmountIn,
            uint256 accAmountOut,
            uint32 chainId,
            uint32 dstChainId,
            bool L1inclusion
        )
    {
        // decode action data
        // | Offset | Length | Data Type               |
        // |--------|---------|----------------------- |
        // | 0      | 20      | address sender         |
        // | 20     | 20      | address market         |
        // | 40     | 32      | uint256 accAmountIn    |
        // | 72     | 32      | uint256 accAmountOut   |
        // | 104    | 4       | uint32 chainId         |
        // | 108    | 4       | uint32 dstChainId      |
        // | 112    | 1       | bool L1inclusion       |
        sender = BytesLib.toAddress(BytesLib.slice(journalData, 0, 20), 0);
        market = BytesLib.toAddress(BytesLib.slice(journalData, 20, 20), 0);
        accAmountIn = BytesLib.toUint256(BytesLib.slice(journalData, 40, 32), 0);
        accAmountOut = BytesLib.toUint256(BytesLib.slice(journalData, 72, 32), 0);
        chainId = BytesLib.toUint32(BytesLib.slice(journalData, 104, 4), 0);
        dstChainId = BytesLib.toUint32(BytesLib.slice(journalData, 108, 4), 0);
        L1inclusion = BytesLib.toUint8(BytesLib.slice(journalData, 112, 1), 0) == 1;
    }

    function encodeJournal(
        address sender,
        address market,
        uint256 accAmountIn,
        uint256 accAmountOut,
        uint32 chainId,
        uint32 dstChainId,
        bool L1inclusion
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(sender, market, accAmountIn, accAmountOut, chainId, dstChainId, L1inclusion);
    }
}
