// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

contract MockApproveRevert {
    function approve(address, uint256) external pure returns (bool) {
        revert("APPROVE_REVERT");
    }
}

contract MockApproveReturnFalse {
    function approve(address, uint256 amount) external pure returns (bool) {
        return amount == 0;
    }
}
