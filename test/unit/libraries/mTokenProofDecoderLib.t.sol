// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
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

contract mTokenProofDecoderLibTest is Test {
    mTokenProofDecoderLibHarness internal harness;

    function setUp() public {
        harness = new mTokenProofDecoderLibHarness();
    }

    function testEncodeDecodeRoundTrip() public view {
        bytes memory encoded = harness.encode(address(0x1234), address(0x5678), 123, 456, 10, 20, true);

        assertEq(encoded.length, mTokenProofDecoderLib.ENTRY_SIZE);

        (
            address decodedSender,
            address decodedMarket,
            uint256 decodedAccIn,
            uint256 decodedAccOut,
            uint32 decodedChainId,
            uint32 decodedDstChainId,
            bool decodedL1
        ) = harness.decode(encoded);

        assertEq(decodedSender, address(0x1234));
        assertEq(decodedMarket, address(0x5678));
        assertEq(decodedAccIn, 123);
        assertEq(decodedAccOut, 456);
        assertEq(decodedChainId, 10);
        assertEq(decodedDstChainId, 20);
        assertEq(decodedL1, true);
    }

    function testDecodeRevertsOnInvalidInclusion() public {
        bytes memory encoded = harness.encode(address(0x1234), address(0x5678), 1, 2, 1, 2, false);

        encoded[encoded.length - 1] = bytes1(uint8(2));

        vm.expectRevert(mTokenProofDecoderLib.mTokenProofDecoderLib_InvalidInclusion.selector);
        harness.decode(encoded);
    }
}
