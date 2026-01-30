// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";
import {CommonLib} from "src/libraries/CommonLib.sol";
import {IGasFeesHelper} from "src/interfaces/IGasFeesHelper.sol";
import {GasFeesHelperMock} from "test/v2/mocks/libraries/CommonLibMocks.t.sol";

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
    //                  CheckHostToExtension                  //
    ////////////////////////////////////////////////////////////

    function test_unit_checkHostToExtension_revertsWith_AmountNotValid_revertsOnZeroAmount() public {
        harness.setAllowed(1, true);
        vm.expectRevert(CommonLib.AmountNotValid.selector);
        harness.checkHostToExtension(0, 1, 0);
    }

    function test_unit_checkHostToExtension_revertsWith_ChainNotValid_revertsOnInvalidChain() public {
        vm.expectRevert(CommonLib.ChainNotValid.selector);
        harness.checkHostToExtension(1, 1, 0);
    }

    function test_unit_checkHostToExtension_revertsWith_NotEnoughGasFee_revertsOnInsufficientGasFee() public {
        harness.setAllowed(1, true);
        gasHelper.setFee(1, 10);
        harness.setGasHelper(gasHelper);

        vm.expectRevert(CommonLib.NotEnoughGasFee.selector);
        harness.checkHostToExtension(1, 1, 9);
    }

    function test_unit_checkHostToExtension_success_succeedsWithNoGasHelper() public {
        harness.setAllowed(1, true);
        harness.checkHostToExtension(1, 1, 0);
    }

    function test_unit_checkHostToExtension_success_succeedsWithGasHelper() public {
        harness.setAllowed(1, true);
        gasHelper.setFee(1, 10);
        harness.setGasHelper(gasHelper);

        harness.checkHostToExtension(1, 1, 10);
    }

    ////////////////////////////////////////////////////////////
    //                   CheckLengthMatch2                    //
    ////////////////////////////////////////////////////////////

    function test_unit_checkLengthMatch2_revertsWith_CommonLib_LengthMismatch() public {
        vm.expectRevert(CommonLib.CommonLib_LengthMismatch.selector);
        harness.checkLengthMatch2(1, 2);
    }

    function test_unit_checkLengthMatch2_success_succeeds() public view {
        harness.checkLengthMatch2(2, 2);
    }

    ////////////////////////////////////////////////////////////
    //                   CheckLengthMatch3                    //
    ////////////////////////////////////////////////////////////

    function test_unit_checkLengthMatch3_revertsWith_CommonLib_LengthMismatch() public {
        vm.expectRevert(CommonLib.CommonLib_LengthMismatch.selector);
        harness.checkLengthMatch3(1, 2, 3);
    }

    function test_unit_checkLengthMatch3_success_succeeds() public view {
        harness.checkLengthMatch3(3, 3, 3);
    }

    ////////////////////////////////////////////////////////////
    //                       ComputeSum                       //
    ////////////////////////////////////////////////////////////

    function test_unit_computeSum_success() public view {
        uint256[] memory values = new uint256[](3);
        values[0] = 1;
        values[1] = 2;
        values[2] = 3;
        assertEq(harness.computeSum(values), 6);
    }
}
