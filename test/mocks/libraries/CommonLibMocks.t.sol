// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
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
