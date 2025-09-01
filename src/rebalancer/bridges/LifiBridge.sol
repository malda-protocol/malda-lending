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

import {SafeApprove} from "src/libraries/SafeApprove.sol";

import {IBridge} from "src/interfaces/IBridge.sol";

import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";

interface ILiFiLIFuel  {
    function startBridgeTokensViaLIFuel(ILiFi.BridgeData calldata) external payable;
    function swapAndStartBridgeTokensViaLIFuel(ILiFi.BridgeData calldata, bytes calldata /* LibSwap.SwapData[] */) external payable;
}

interface ILiFi {
    struct BridgeData {
        bytes32 transactionId;
        string  bridge;                // LIFuel
        string  integrator;            // Malda
        address referrer;              // optional
        address sendingAssetId;        // source chain token
        address receiver;              
        uint256 minAmount;             // amount to bridge (or to refuel with for LIFuel)
        uint256 destinationChainId;    // EVM chain id (not domain id)
        bool    hasSourceSwaps;        // false here
        bool    hasDestinationCall;    // false for LIFuel
    }
}

//https://etherscan.io/address/0x66861f292099cAF644F4A8b6091De49BEC5E8a15#code
contract LifiBridge is BaseBridge, IBridge, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ----------- STORAGE ------------
    address public immutable lifiDiamond;
    
    //TBD: limit which Diamond selectors this contract can call when using `forwardToDiamond`
    mapping(bytes4 => bool) public allowedSelectors; 
    
    // ----------- EVENTS ------------
    event Refueled(address indexed market, uint256 amount, uint256 dstChainId);
    event DiamondCallForwarded(bytes4 indexed selector, address indexed token, uint256 amount, uint256 value);

    // ----------- ERRORS ------------
    error LiFiBridge_AddressNotValid();
    error LiFiBridge_NotImplemented();
    error LiFiBridge_SelectorNotAllowed();

    constructor(address _roles, address _lifiDiamond) BaseBridge(_roles) {
        if (_lifiDiamond == address(0)) revert LiFiBridge_AddressNotValid();
        lifiDiamond = _lifiDiamond;

        // Allow the two LI.Fuel entry points by default
        allowedSelectors[ILiFiLIFuel.startBridgeTokensViaLIFuel.selector] = true;
        allowedSelectors[ILiFiLIFuel.swapAndStartBridgeTokensViaLIFuel.selector] = true;
    }

    // ----------- OWNER ------------
    function setAllowedSelector(bytes4 selector, bool allowed) external onlyBridgeConfigurator {
        allowedSelectors[selector] = allowed;
    }

     // ----------- VIEW ------------
    /// @inheritdoc IBridge
    function getFee(uint32, bytes memory, bytes memory) external pure returns (uint256) {
        // fees/quotes off-chain via API/SDK
        revert LiFiBridge_NotImplemented();
    }

    // ----------- EXTERNAL ------------
    /// @inheritdoc IBridge
    function sendMsg(
        uint256 _extractedAmount,
        address _market,
        uint32 _dstChainId,
        address _token,
        bytes memory,
        bytes memory
    ) external payable onlyRebalancer nonReentrant {

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _extractedAmount);

        SafeApprove.safeApprove(_token, address(lifiDiamond), _extractedAmount);
        ILiFi.BridgeData memory bd = ILiFi.BridgeData({
            transactionId: keccak256(abi.encode(block.chainid, address(this), _market, _token, _extractedAmount, _dstChainId, block.timestamp)),
            bridge: "LIFuel",
            integrator: "Malda",
            referrer: address(0),
            sendingAssetId: _token,
            receiver: _market,                    
            minAmount: _extractedAmount, //TODO: check min output
            destinationChainId: uint256(_dstChainId),
            hasSourceSwaps: false,
            hasDestinationCall: false
        });

        ILiFiLIFuel(lifiDiamond).startBridgeTokensViaLIFuel(bd);
    }

    /**
     function forwardToDiamond(
        address token,
        uint256 amount,
        uint256 value,
        bytes calldata diamondCalldata
    ) external payable onlyRebalancer nonReentrant {
        require(diamondCalldata.length >= 4, "no selector");
        bytes4 sel;
        assembly { 
            sel := calldataload(diamondCalldata.offset) 
        }
        if (!allowedSelectors[sel]) revert LiFiBridge_SelectorNotAllowed();

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(token).safeApprove(lifiDiamond, amount);

        (bool ok, bytes memory ret) = lifiDiamond.call{value: value}(diamondCalldata);
        require(ok, _bubble(ret));
    }

    // ----------- INTERNAL ------------
    function _bubble(bytes memory ret) private pure returns (string memory) {
        if (ret.length < 68) return "Diamond call failed";
        assembly { ret := add(ret, 0x04) }
        return abi.decode(ret, (string));
    }
    */


}