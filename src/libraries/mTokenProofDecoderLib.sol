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
    uint256 public constant ENTRY_SIZE = 112; // single journal entry size

    error mTokenProofDecoderLib_ChainNotFound();
    error mTokenProofDecoderLib_JournalSizeNotValid();
    error mTokenProofDecoderLib_IndexesSizeNotValid();
    error mTokenProofDecoderLib_IndexItemsNotFound();

    function getByJournalIndexes(bytes memory journal, uint256[] calldata indexes)
        external
        pure
        returns (bytes[] memory finalEntries)
    {
        bytes[] memory entries = abi.decode(journal, (bytes[]));

        uint256 entriesLen = entries.length;
        uint256 indexesLen = indexes.length;
        require(entriesLen > 0, mTokenProofDecoderLib_JournalSizeNotValid());
        require(indexesLen > 0, mTokenProofDecoderLib_IndexesSizeNotValid());

        uint256 validCount;
        for (uint256 i; i < indexesLen;) {
            if (indexes[i] < entriesLen) {
                ++validCount;
            }
            unchecked {
                ++i;
            }
        }

        uint256 j;
        finalEntries = new bytes[](validCount);
        for (uint256 i; i < indexesLen;) {
            if (indexes[i] < entriesLen) {
                finalEntries[j] = entries[indexes[i]];
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    function decodeJournalArray(bytes memory journalArrayData, uint32 _chainIdToMatch)
        external
        pure
        returns (
            address sender,
            address market,
            uint256 accAmountIn,
            uint256 accAmountOut,
            uint32 chainId,
            uint32 dstChainId
        )
    {
        // make sure journal length is valid
        require(journalArrayData.length % ENTRY_SIZE == 0, mTokenProofDecoderLib_JournalSizeNotValid());

        // iterate over journal entries and check the chain id
        for (uint256 i = 0; i < journalArrayData.length; i += ENTRY_SIZE) {
            dstChainId = BytesLib.toUint32(BytesLib.slice(journalArrayData, i + 108, 4), 0);

            // if there's a match, decode and return
            if (dstChainId == _chainIdToMatch) {
                sender = BytesLib.toAddress(BytesLib.slice(journalArrayData, i, 20), 0);
                market = BytesLib.toAddress(BytesLib.slice(journalArrayData, i + 20, 20), 0);
                accAmountIn = BytesLib.toUint256(BytesLib.slice(journalArrayData, i + 40, 32), 0);
                accAmountOut = BytesLib.toUint256(BytesLib.slice(journalArrayData, i + 72, 32), 0);
                chainId = BytesLib.toUint32(BytesLib.slice(journalArrayData, i + 104, 4), 0);
                return (sender, market, accAmountIn, accAmountOut, chainId, dstChainId);
            }
        }

        //revert in case chain id wasn't matched
        revert mTokenProofDecoderLib_ChainNotFound();
    }

    function decodeJournal(bytes memory journalData)
        public
        pure
        returns (
            address sender,
            address market,
            uint256 accAmountIn,
            uint256 accAmountOut,
            uint32 chainId,
            uint32 dstChainId
        )
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
        dstChainId = BytesLib.toUint32(BytesLib.slice(journalData, 108, 4), 0);
    }

    function encodeJournal(
        address sender,
        address market,
        uint256 accAmountIn,
        uint256 accAmountOut,
        uint32 chainId,
        uint32 dstChainId
    ) external pure returns (bytes memory) {
        return abi.encodePacked(sender, market, accAmountIn, accAmountOut, chainId, dstChainId);
    }
}
