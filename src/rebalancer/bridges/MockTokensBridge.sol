// Copyright (c) 2025 Merge Layers Inc.
//
// This source code is licensed under the Business Source License 1.1
// (the "License"); you may not use this file except in compliance with the
// License. You may obtain a copy of the License at
//
//     https://github.com/malda-protocol/malda-lending/blob/main/LICENSE-BSL
//
// See the License for the specific language governing permissions and
// limitations under the License.

// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


import {IBridge} from "src/interfaces/IBridge.sol";

import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";

contract MockTokensBridge is BaseBridge, IBridge, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address[] tokens;

    event MockTokensBridgeMintAndBurn(address indexed _market, address indexed _token, uint256 amount, uint32 crtChainId, uint32 dstChainId);

    constructor(address _roles, address[] memory _tokens) BaseBridge(_roles) {
        for (uint256 i; i< _tokens.length; ++i) {
            tokens.push(_tokens[i]);
        }
    }

    /**
     * @inheritdoc IBridge
     */
    function getFee(uint32, bytes memory, bytes memory) external pure returns (uint256) {
        return 0;
    }

    function sendMsg(
        uint256 _extractedAmount,
        address _market,
        uint32 _dstChainId,
        address _token,
        bytes memory _message,
        bytes memory
    ) external payable onlyRebalancer {
        uint256 amount = abi.decode(_message, (uint256));
        require(_extractedAmount == amount, BaseBridge_AmountMismatch());

        IERC20(_token).safeTransferFrom(msg.sender, address(this), amount);

        emit MockTokensBridgeMintAndBurn(_market, _token, amount, uint32(block.chainid), _dstChainId);
    }

    function triggerMintTest(address _market, address _token, uint32 _dstChainId, uint256 _amount) external onlyRebalancer {
        emit MockTokensBridgeMintAndBurn(_market, _token, _amount, uint32(block.chainid), _dstChainId);
    }
}