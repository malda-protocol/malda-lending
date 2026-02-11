// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IGasFeesHelper} from "src/interfaces/IGasFeesHelper.sol";
import {CommonLib} from "src/libraries/CommonLib.sol";

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
