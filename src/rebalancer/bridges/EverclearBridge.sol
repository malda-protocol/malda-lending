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

import {SafeApprove} from "src/libraries/SafeApprove.sol";
import {BytesLib} from "src/libraries/BytesLib.sol";

import {IBridge} from "src/interfaces/IBridge.sol";
import {IFeeAdapter} from "src/interfaces/external/everclear/IFeeAdapter.sol";

import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";

contract EverclearBridge is BaseBridge, IBridge {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    // ----------- STORAGE ------------
    IFeeAdapter public everclearFeeAdapter;

    struct IntentParams {
        uint32[] destinations;
        bytes32 receiver;
        address inputAsset;
        bytes32 outputAsset;
        uint256 amount;
        uint24 maxFee;
        uint48 ttl;
        bytes data;
        IFeeAdapter.FeeParams feeParams;
    }

    // ----------- EVENTS ------------
    event MsgSent(uint256 indexed dstChainId, address indexed market, uint256 amountLD, bytes32 id);
    event RebalancingReturnedToMarket(address indexed market, uint256 toReturn, uint256 extracted);

    // ----------- ERRORS ------------
    error Everclear_TokenMismatch();
    error Everclear_NotImplemented();
    error Everclear_MaxFeeExceeded();
    error Everclear_AddressNotValid();
    error Everclear_DestinationNotValid();
    error Everclear_DestinationsLengthMismatch();

    constructor(address _roles, address _feeAdapter) BaseBridge(_roles) {
        require(_feeAdapter != address(0), Everclear_AddressNotValid());

        everclearFeeAdapter = IFeeAdapter(_feeAdapter);
    }

    // ----------- VIEW ------------
    /**
     * @inheritdoc IBridge
     */
    function getFee(uint32, bytes memory, bytes memory) external pure returns (uint256) {
        // need to use Everclear API
        revert Everclear_NotImplemented();
    }

    // ----------- EXTERNAL ------------
    function sendMsg(
        uint256 _extractedAmount,
        address _market,
        uint32 _dstChainId,
        address _token,
        bytes memory _message,
        bytes memory // unused
    ) external payable onlyRebalancer {
        IntentParams memory params = _decodeIntent(_message);

        require(params.inputAsset == _token, Everclear_TokenMismatch());
        require(_extractedAmount >= params.amount, BaseBridge_AmountMismatch());
        require(params.amount > 0 , BaseBridge_AmountMismatch());

        require(address(uint160(uint256(params.receiver))) == _market, BaseBridge_AddressNotValid());

        uint256 destinationsLength = params.destinations.length;

        require(destinationsLength == 1, Everclear_DestinationsLengthMismatch());
        require (params.destinations[0] == _dstChainId, Everclear_DestinationNotValid());

        require(params.maxFee <= params.amount / 10, Everclear_MaxFeeExceeded());
             
        // retrieve tokens from `Rebalancer`
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _extractedAmount);

        if (_extractedAmount > params.amount) {
            uint256 toReturn = _extractedAmount - params.amount - params.feeParams.fee;
            IERC20(_token).safeTransfer(_market, toReturn);
            emit RebalancingReturnedToMarket(_market, toReturn, _extractedAmount);
        }

        SafeApprove.safeApprove(params.inputAsset, address(everclearFeeAdapter), params.amount + params.feeParams.fee);
        (bytes32 id,) = everclearFeeAdapter.newIntent(
            params.destinations,
            params.receiver,
            params.inputAsset,
            params.outputAsset,
            params.amount,
            0, //max fee
            0, //ttl
            params.data,
            params.feeParams
        );
        emit MsgSent(_dstChainId, _market, params.amount, id);
    }

    // ----------- INTERNAL ------------
    function _decodeIntent(bytes memory message) internal pure returns (IntentParams memory) {
        // message contains data obtained from `https://api.everclear.org/intents` call
        // data can be decoded into `FeeAdapter.newIntent` call params

        // skip selector
        bytes memory intentData = BytesLib.slice(message, 4, message.length - 4);
        (
            uint32[] memory destinations,
            bytes32 receiver,
            address inputAsset,
            bytes32 outputAsset,
            uint256 amount,
            uint24 maxFee,
            uint48 ttl,
            bytes memory data
        ) = abi.decode(
            intentData, (uint32[], bytes32, address, bytes32, uint256, uint24, uint48, bytes)
        );

        (uint256 fee, uint256 deadline, bytes memory sig) = _extractFeeParams(intentData);
        IFeeAdapter.FeeParams memory feeParams = IFeeAdapter.FeeParams(fee, deadline, sig);

        return IntentParams(destinations, receiver, inputAsset, outputAsset, amount, maxFee, ttl, data, feeParams);
    }

    function _extractFeeParams(bytes memory intentData) private pure returns (uint256 fee, uint256 deadline, bytes memory sig) {
        uint256 feeParamsOffset = BytesLib.toUint256(intentData, 0x120);
        uint256 feeParamsPtr = feeParamsOffset; 

        fee = BytesLib.toUint256(intentData, feeParamsPtr);
        deadline = BytesLib.toUint256(intentData, feeParamsPtr + 32);

        uint256 sigOffset = BytesLib.toUint256(intentData, feeParamsOffset + 64);
        uint256 sigLen = BytesLib.toUint256(intentData, feeParamsOffset + sigOffset);
        sig = BytesLib.slice(intentData, feeParamsOffset + sigOffset + 32, sigLen);

    }
}
