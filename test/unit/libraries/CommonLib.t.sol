// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {CommonLib} from "src/libraries/CommonLib.sol";
import {IGasFeesHelper} from "src/interfaces/IGasFeesHelper.sol";

contract GasFeesHelperMock is IGasFeesHelper {
    mapping(uint32 dstChainId => uint256 fee) public fees;

    function setFee(uint32 chainId, uint256 fee) external {
        fees[chainId] = fee;
    }

    function gasFees(uint32 dstChainId) external view returns (uint256 fee) {
        return fees[dstChainId];
    }
}

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

contract CommonLibTest is Test {
    CommonLibHarness internal harness;
    GasFeesHelperMock internal gasHelper;

    function setUp() public {
        harness = new CommonLibHarness();
        gasHelper = new GasFeesHelperMock();
    }

    function testCheckHostToExtensionRevertsOnZeroAmount() public {
        harness.setAllowed(1, true);
        vm.expectRevert(CommonLib.AmountNotValid.selector);
        harness.checkHostToExtension(0, 1, 0);
    }

    function testCheckHostToExtensionRevertsOnInvalidChain() public {
        vm.expectRevert(CommonLib.ChainNotValid.selector);
        harness.checkHostToExtension(1, 1, 0);
    }

    function testCheckHostToExtensionRevertsOnInsufficientGasFee() public {
        harness.setAllowed(1, true);
        gasHelper.setFee(1, 10);
        harness.setGasHelper(gasHelper);

        vm.expectRevert(CommonLib.NotEnoughGasFee.selector);
        harness.checkHostToExtension(1, 1, 9);
    }

    function testCheckHostToExtensionSucceedsWithNoGasHelper() public {
        harness.setAllowed(1, true);
        harness.checkHostToExtension(1, 1, 0);
    }

    function testCheckHostToExtensionSucceedsWithGasHelper() public {
        harness.setAllowed(1, true);
        gasHelper.setFee(1, 10);
        harness.setGasHelper(gasHelper);

        harness.checkHostToExtension(1, 1, 10);
    }

    function testCheckLengthMatch2Reverts() public {
        vm.expectRevert(CommonLib.CommonLib_LengthMismatch.selector);
        harness.checkLengthMatch2(1, 2);
    }

    function testCheckLengthMatch2Succeeds() public view {
        harness.checkLengthMatch2(2, 2);
    }

    function testCheckLengthMatch3Reverts() public {
        vm.expectRevert(CommonLib.CommonLib_LengthMismatch.selector);
        harness.checkLengthMatch3(1, 2, 3);
    }

    function testCheckLengthMatch3Succeeds() public view {
        harness.checkLengthMatch3(3, 3, 3);
    }

    function testComputeSum() public view {
        uint256[] memory values = new uint256[](3);
        values[0] = 1;
        values[1] = 2;
        values[2] = 3;
        assertEq(harness.computeSum(values), 6);
    }
}
