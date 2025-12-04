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

import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";

interface IFeeAdapterV2 {
  struct FeeParams {
    uint256 fee;
    uint256 deadline;
    bytes sig;
  }

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


contract EverclearBridgeV2 is BaseBridge, IBridge {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    // ----------- STORAGE ------------
    IFeeAdapterV2 public everclearFeeAdapter;

    struct IntentParams {
        uint32[] destinations;
        bytes32 receiver;
        address inputAsset;
        bytes32 outputAsset;
        uint256 amount;
        uint256 amountOutMin;
        uint48 ttl;
        bytes data;
        IFeeAdapterV2.FeeParams feeParams;
    }

    // ----------- EVENTS ------------
    event MsgSent(uint256 indexed dstChainId, address indexed market, uint256 amountLD, bytes32 id);
    event RebalancingReturnedToMarket(address indexed market, uint256 toReturn, uint256 extracted);
    event EverclearFeeAdapterUpdated(address indexed oldAdapter, address indexed newAdapter);

    // ----------- ERRORS ------------
    error Everclear_TokenMismatch();
    error Everclear_NotImplemented();
    error Everclear_MaxSlippageExceeded();
    error Everclear_AddressNotValid();
    error Everclear_DestinationNotValid();
    error Everclear_DestinationsLengthMismatch();

    constructor(address _roles, address _feeAdapter) BaseBridge(_roles) {
        require(_feeAdapter != address(0), Everclear_AddressNotValid());

        everclearFeeAdapter = IFeeAdapterV2(_feeAdapter);
    }

    // ----------- ADMIN ------------
    function setEverclearFeeAdapter(address _feeAdapter) external onlyBridgeConfigurator {
        if (_feeAdapter == address(0)) revert Everclear_AddressNotValid();
        address old = address(everclearFeeAdapter);
        everclearFeeAdapter = IFeeAdapterV2(_feeAdapter);
        emit EverclearFeeAdapterUpdated(old, _feeAdapter);
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

        // Check that slippage is reasonable (max 10% slippage)
        require(params.amountOutMin >= params.amount * 9 / 10, Everclear_MaxSlippageExceeded());
             
        // retrieve tokens from `Rebalancer`
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _extractedAmount);

        if (_extractedAmount > params.amount + params.feeParams.fee) {
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
            params.amountOutMin,
            params.ttl,
            params.data,
            params.feeParams
        );
        emit MsgSent(_dstChainId, _market, params.amount, id);
    }

    // ----------- INTERNAL ------------
    /**
     * @notice Decodes an intent message returned by the Everclear intents API into structured parameters.
     * @dev 
     * - The input `message` is the raw ABI-encoded calldata of a `FeeAdapterV2.newIntent` call.
     * - The first 4 bytes are the function selector, which are skipped.
     * - The remaining bytes encode the primary intent parameters followed by `FeeParams`.
     * - Because `FeeParams` is a dynamic struct appended at the end, its data must be located by
     *   reading its offset and decoding separately.
     * 
     * Layout of `FeeAdapterV2.newIntent` calldata after the selector:
     * ```
     * destinations (uint32[])   @ offset 0x00
     * receiver (bytes32)        @ offset 0x20
     * inputAsset (address)      @ offset 0x40
     * outputAsset (bytes32)     @ offset 0x60
     * amount (uint256)          @ offset 0x80
     * amountOutMin (uint256)    @ offset 0xa0
     * ttl (uint48)              @ offset 0xc0
     * data (bytes)              @ offset 0xe0
     * feeParams (FeeParams)     @ offset 0x100 (9th arg → pointer)
     * ```
     * Since each static argument occupies a 32-byte slot, the pointer to `feeParams`
     * lives at offset `0x100` (256 bytes) after the selector is removed.
     * 
     * @param message ABI-encoded calldata for `FeeAdapterV2.newIntent`.
     * @return Decoded `IntentParams` struct with both core parameters and nested `FeeParams`.
     */
    function _decodeIntent(bytes memory message) internal pure returns (IntentParams memory) {
        // message contains data obtained from `https://api.everclear.org/intents` call
        // data can be decoded into `FeeAdapterV2.newIntent` call params

        // skip selector
        bytes memory intentData = BytesLib.slice(message, 4, message.length - 4);
        (
            uint32[] memory destinations,
            bytes32 receiver,
            address inputAsset,
            bytes32 outputAsset,
            uint256 amount,
            uint256 amountOutMin,
            uint48 ttl,
            bytes memory data
        ) = abi.decode(
            intentData, (uint32[], bytes32, address, bytes32, uint256, uint256, uint48, bytes)
        );

        (uint256 fee, uint256 deadline, bytes memory sig) = _extractFeeParams(intentData);
        IFeeAdapterV2.FeeParams memory feeParams = IFeeAdapterV2.FeeParams(fee, deadline, sig);

        return IntentParams(destinations, receiver, inputAsset, outputAsset, amount, amountOutMin, ttl, data, feeParams);
    }


    /**
     * @notice Extracts the nested `FeeParams` struct from ABI-encoded `intentData`.
     * @dev 
     * - `FeeParams` is the 9th parameter of `FeeAdapterV2.newIntent` and therefore stored as a pointer at offset `0x100`.
     * - The selector has already been removed, so the pointer is read at byte position `0x100` (256 bytes).
     * - The pointer gives the offset to the start of the `FeeParams` struct relative to the start of intentData.
     * - Within `FeeParams`, the layout is:
     *   ```
     *   fee      (uint256) @ +0x00
     *   deadline (uint256) @ +0x20
     *   sig      (bytes)   @ +0x40 (stored as offset → length → data)
     *   ```
     * - The `sig` field is dynamic, so we read its offset (at +0x40) relative to the `FeeParams` base,
     *   then read the length at that offset, then slice out the actual signature bytes.
     *
     * @param intentData ABI-encoded calldata without selector, containing intent arguments.
     * @return fee The fee value.
     * @return deadline The signature deadline.
     * @return sig The validator/relayer signature.
     */
    function _extractFeeParams(bytes memory intentData) private pure returns (uint256 fee, uint256 deadline, bytes memory sig) {
        uint256 feeParamsOffset = BytesLib.toUint256(intentData, 0x100);
        uint256 feeParamsPtr = feeParamsOffset; 

        fee = BytesLib.toUint256(intentData, feeParamsPtr);
        deadline = BytesLib.toUint256(intentData, feeParamsPtr + 32);

        uint256 sigOffset = BytesLib.toUint256(intentData, feeParamsOffset + 64);
        uint256 sigLen = BytesLib.toUint256(intentData, feeParamsOffset + sigOffset);
        sig = BytesLib.slice(intentData, feeParamsOffset + sigOffset + 32, sigLen);

    }
}

