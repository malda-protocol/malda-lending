// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {mTokenProofDecoderLib} from "src/libraries/mTokenProofDecoderLib.sol";

import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

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

contract mTokenProofDecoderLibTest is BaseTest {
    struct Expected {
        address sender;
        address market;
        uint256 accAmountIn;
        uint256 accAmountOut;
        uint32 chainId;
        uint32 dstChainId;
        bool l1Inclusion;
    }

    mTokenProofDecoderLibHarness internal harness;

    function setUp() public override {
        super.setUp();

        harness = new mTokenProofDecoderLibHarness();
    }

    ////////////////////////////////////////////////////////////
    //                         encode                         //
    ////////////////////////////////////////////////////////////

    function test_fuzz_encode_success(
        address sender,
        address market,
        uint256 accAmountIn,
        uint256 accAmountOut,
        uint32 chainId,
        uint32 dstChainId,
        bool l1Inclusion
    ) public view {
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bytes memory encoded =
            harness.encode(sender, market, accAmountIn, accAmountOut, chainId, dstChainId, l1Inclusion);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(encoded.length, mTokenProofDecoderLib.ENTRY_SIZE, "assertEq failed: values do not match");
        _assertDecoded(
            encoded,
            Expected({
                sender: sender,
                market: market,
                accAmountIn: accAmountIn,
                accAmountOut: accAmountOut,
                chainId: chainId,
                dstChainId: dstChainId,
                l1Inclusion: l1Inclusion
            })
        );
    }

    ////////////////////////////////////////////////////////////
    //                         decode                         //
    ////////////////////////////////////////////////////////////

    function test_unit_decode_revertsWith_mTokenProofDecoderLib_InvalidLength() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory encoded = new bytes(mTokenProofDecoderLib.ENTRY_SIZE - 1);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenProofDecoderLib.mTokenProofDecoderLib_InvalidLength.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.decode(encoded);
    }

    function test_fuzz_decode_revertsWith_mTokenProofDecoderLib_InvalidInclusion(
        address sender,
        address market,
        uint256 accAmountIn,
        uint256 accAmountOut,
        uint32 chainId,
        uint32 dstChainId,
        uint8 inclusionValue
    ) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        inclusionValue = uint8(bound(inclusionValue, 2, type(uint8).max));

        bytes memory encoded = harness.encode(sender, market, accAmountIn, accAmountOut, chainId, dstChainId, false);

        encoded[encoded.length - 1] = bytes1(inclusionValue);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenProofDecoderLib.mTokenProofDecoderLib_InvalidInclusion.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.decode(encoded);
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _assertDecoded(bytes memory encoded, Expected memory expected) internal view {
        (
            address decodedSender,
            address decodedMarket,
            uint256 decodedAccIn,
            uint256 decodedAccOut,
            uint32 decodedChainId,
            uint32 decodedDstChainId,
            bool decodedL1
        ) = harness.decode(encoded);

        assertEq(decodedSender, expected.sender, "assertEq failed: values do not match");
        assertEq(decodedMarket, expected.market, "assertEq failed: values do not match");
        assertEq(decodedAccIn, expected.accAmountIn, "assertEq failed: values do not match");
        assertEq(decodedAccOut, expected.accAmountOut, "assertEq failed: values do not match");
        assertEq(decodedChainId, expected.chainId, "assertEq failed: values do not match");
        assertEq(decodedDstChainId, expected.dstChainId, "assertEq failed: values do not match");
        assertEq(decodedL1, expected.l1Inclusion, "assertEq failed: values do not match");
    }
}
