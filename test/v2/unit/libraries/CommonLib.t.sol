// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {CommonLib} from "src/libraries/CommonLib.sol";
import {IGasFeesHelper} from "src/interfaces/IGasFeesHelper.sol";

import {GasFeesHelperMock} from "test/v2/mocks/libraries/CommonLibMocks.t.sol";
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract CommonLibHarness {
    mapping(uint32 chainId => bool allowed) internal allowedChains;
    IGasFeesHelper internal gasHelper;

    function setAllowed(uint32 chainId, bool allowed) external {
        allowedChains[chainId] = allowed;
    }

    function setGasHelper(IGasFeesHelper helper) external {
        gasHelper = helper;
    }

    function checkHostToExtension(uint256 amount, uint32 dstChainId, uint256 msgValue) external view {
        CommonLib.checkHostToExtension(amount, dstChainId, msgValue, allowedChains, gasHelper);
    }

    function checkLengthMatch2(uint256 l1, uint256 l2) external pure {
        CommonLib.checkLengthMatch(l1, l2);
    }

    function checkLengthMatch3(uint256 l1, uint256 l2, uint256 l3) external pure {
        CommonLib.checkLengthMatch(l1, l2, l3);
    }

    function computeSum(uint256[] calldata values) external pure returns (uint256) {
        return CommonLib.computeSum(values);
    }
}

contract CommonLibTest is BaseTest {
    CommonLibHarness internal harness;
    GasFeesHelperMock internal gasHelper;

    function setUp() public override {
        super.setUp();

        harness = new CommonLibHarness();
        gasHelper = new GasFeesHelperMock();
    }

    ////////////////////////////////////////////////////////////
    //                  checkHostToExtension                  //
    ////////////////////////////////////////////////////////////

    function test_fuzz_checkHostToExtension_revertsWith_AmountNotValid(uint32 dstChainId, uint256 msgValue) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        harness.setAllowed(dstChainId, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CommonLib.AmountNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.checkHostToExtension(0, dstChainId, msgValue);
    }

    function test_fuzz_checkHostToExtension_revertsWith_ChainNotValid(uint32 dstChainId, uint256 amount) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, 1, type(uint256).max);
        harness.setAllowed(dstChainId, false);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CommonLib.ChainNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.checkHostToExtension(amount, dstChainId, 0);
    }

    function test_fuzz_checkHostToExtension_revertsWith_NotEnoughGasFee(uint32 dstChainId, uint256 amount, uint256 fee)
        public
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, 1, type(uint256).max);
        fee = bound(fee, 1, type(uint256).max);

        harness.setAllowed(dstChainId, true);
        gasHelper.setFee(dstChainId, fee);
        harness.setGasHelper(gasHelper);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CommonLib.NotEnoughGasFee.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.checkHostToExtension(amount, dstChainId, fee - 1);
    }

    function test_fuzz_checkHostToExtension_success_whenNoGasHelper(uint32 dstChainId, uint256 amount, uint256 msgValue)
        public
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, 1, type(uint256).max);
        harness.setAllowed(dstChainId, true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.checkHostToExtension(amount, dstChainId, msgValue);
    }

    function test_fuzz_checkHostToExtension_success_whenGasHelperConfigured(
        uint32 dstChainId,
        uint256 amount,
        uint256 fee,
        uint256 msgValue
    ) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, 1, type(uint256).max);
        fee = bound(fee, 0, type(uint256).max);
        msgValue = bound(msgValue, fee, type(uint256).max);

        harness.setAllowed(dstChainId, true);
        gasHelper.setFee(dstChainId, fee);
        harness.setGasHelper(gasHelper);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.checkHostToExtension(amount, dstChainId, msgValue);
    }

    ////////////////////////////////////////////////////////////
    //                   checkLengthMatch2                   //
    ////////////////////////////////////////////////////////////

    function test_fuzz_checkLengthMatch2_revertsWith_CommonLib_LengthMismatch(uint256 l1, uint256 l2) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(l1 != l2);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CommonLib.CommonLib_LengthMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.checkLengthMatch2(l1, l2);
    }

    function test_fuzz_checkLengthMatch2_success(uint256 length) public view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        harness.checkLengthMatch2(length, length);
    }

    ////////////////////////////////////////////////////////////
    //                   checkLengthMatch3                   //
    ////////////////////////////////////////////////////////////

    function test_fuzz_checkLengthMatch3_revertsWith_CommonLib_LengthMismatch(uint256 l1, uint256 l2, uint256 l3)
        public
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(l1 != l2 || l2 != l3);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CommonLib.CommonLib_LengthMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.checkLengthMatch3(l1, l2, l3);
    }

    function test_fuzz_checkLengthMatch3_success(uint256 length) public view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        harness.checkLengthMatch3(length, length, length);
    }

    ////////////////////////////////////////////////////////////
    //                       computeSum                       //
    ////////////////////////////////////////////////////////////

    function test_fuzz_computeSum_success(uint256[] memory values) public view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 expected;
        for (uint256 i; i < values.length; ++i) {
            if (type(uint256).max - expected < values[i]) {
                vm.assume(false);
            }
            expected += values[i];
        }

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 sum = harness.computeSum(values);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(sum, expected);
    }
}
