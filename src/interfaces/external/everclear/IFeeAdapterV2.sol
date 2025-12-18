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


interface IFeeAdapterV2 {
    struct FeeParams {
        uint256 fee;
        uint256 deadline;
        bytes sig;
    }

    // taken from: https://github.com/everclearorg/monorepo/blob/dev/packages/contracts/src/interfaces/common/IEverclearV2.sol#L55
    struct Intent {
        bytes32 initiator;
        bytes32 receiver;
        bytes32 inputAsset;
        bytes32 outputAsset;
        uint32 origin;
        uint64 nonce;
        uint48 timestamp;
        uint48 ttl;
        uint256 amount;
        uint256 amountOutMin;
        uint32[] destinations;
        bytes data;
    }

    // https://github.com/everclearorg/monorepo/blob/dev/packages/contracts/src/interfaces/intent/IFeeAdapterV2.sol#L129
    /**
    * @notice Creates a new intent with fees
    * @param _destinations Array of destination domains, preference ordered
    * @param _receiver Address of the receiver on the destination chain
    * @param _inputAsset Address of the input asset
    * @param _outputAsset Address of the output asset
    * @param _amount Amount of input asset to use for the intent
    * @param _amountOutMin Amount expected in the outputAsset
    * @param _ttl Time-to-live for the intent in seconds
    * @param _data Additional data for the intent
    * @param _feeParams Fee parameters including fee amount, deadline, and signature
    * @return _intentId The ID of the created intent
    * @return _intent The created intent object
    */
    function newIntent(
        uint32[] memory _destinations,
        bytes32 _receiver,
        address _inputAsset,
        bytes32 _outputAsset,
        uint256 _amount,
        uint256 _amountOutMin,
        uint48 _ttl,
        bytes calldata _data,
        FeeParams calldata _feeParams
    ) external payable returns (bytes32, Intent memory);
    }

