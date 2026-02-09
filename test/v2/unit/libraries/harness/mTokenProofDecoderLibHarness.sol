// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {mTokenProofDecoderLib} from "src/libraries/mTokenProofDecoderLib.sol";

contract mTokenProofDecoderLibHarness {
    function encode(
        address sender,
        address market,
        uint256 accAmountIn,
        uint256 accAmountOut,
        uint32 chainId,
        uint32 dstChainId,
        bool l1Inclusion
    ) external pure returns (bytes memory) {
        return mTokenProofDecoderLib.encodeJournal(
            sender, market, accAmountIn, accAmountOut, chainId, dstChainId, l1Inclusion
        );
    }

    function decode(bytes calldata journalData)
        external
        pure
        returns (
            address sender,
            address market,
            uint256 accAmountIn,
            uint256 accAmountOut,
            uint32 chainId,
            uint32 dstChainId,
            bool l1Inclusion
        )
    {
        return mTokenProofDecoderLib.decodeJournal(journalData);
    }
}
