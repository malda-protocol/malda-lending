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

contract MockApproveReturnTrue {
    uint256 public calls;
    address public firstSpender;
    uint256 public firstAmount;
    address public secondSpender;
    uint256 public secondAmount;

    function approve(address spender, uint256 amount) external returns (bool) {
        calls++;
        if (calls == 1) {
            firstSpender = spender;
            firstAmount = amount;
        } else if (calls == 2) {
            secondSpender = spender;
            secondAmount = amount;
        }

        return true;
    }
}

contract MockApproveNoReturn {
    uint256 public calls;
    address public firstSpender;
    uint256 public firstAmount;
    address public secondSpender;
    uint256 public secondAmount;

    function approve(address spender, uint256 amount) external {
        calls++;
        if (calls == 1) {
            firstSpender = spender;
            firstAmount = amount;
        } else if (calls == 2) {
            secondSpender = spender;
            secondAmount = amount;
        }
    }
}
