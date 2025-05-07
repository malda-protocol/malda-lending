// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RebalancerMarketMock {
    address public underlying;

    function setUnderlying(address _underlying) external {
        underlying = _underlying;
    }

    function extractForRebalancing(uint256 amount) external {
        ERC20(underlying).transfer(msg.sender, amount);
    }
}