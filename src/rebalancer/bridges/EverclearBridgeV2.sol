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
import {IFeeAdapterV2} from "src/interfaces/external/everclear/IFeeAdapterV2.sol";

import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";

/// @title Everclear V2 bridge implementation
/// @author Malda Protocol
/// @notice Cross-chain bridge using Everclear V2 protocol for intent-based transfers
contract EverclearBridgeV2 is BaseBridge, IBridge {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    // ----------- STRUCTS ------------
    /// @notice Parameters for creating a new intent with fees
    /// @dev Will be used for initiating a call to
    /// https://github.com/everclearorg/monorepo/blob/dev/packages/contracts/src/interfaces/intent/IFeeAdapterV2.sol#L129
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

    // ----------- STORAGE ------------
    /// @notice Everclear V2 fee adapter contract
    IFeeAdapterV2 public everclearFeeAdapter;

    // ----------- EVENTS ------------
    /// @notice Emitted when a message is sent via Everclear V2
    /// @param dstChainId Destination chain ID
    /// @param market Destination market address
    /// @param amountLD Amount in local decimals
    /// @param id Intent identifier
    event MsgSent(uint256 indexed dstChainId, address indexed market, uint256 amountLD, bytes32 id);

    /// @notice Emitted when excess rebalancing funds are returned to the market
    /// @param market Destination market address
    /// @param toReturn Amount returned
    /// @param extracted Amount originally extracted
    event RebalancingReturnedToMarket(address indexed market, uint256 toReturn, uint256 extracted);

    /// @notice Emitted when the Everclear V2 fee adapter is updated
    /// @param oldAdapter Old Everclear V2 fee adapter address
    /// @param newAdapter New Everclear V2 fee adapter address
    event EverclearFeeAdapterUpdated(address indexed oldAdapter, address indexed newAdapter);

    // ----------- ERRORS ------------
    /// @notice Error thrown when provided token does not match expected asset
    error Everclear_TokenMismatch();
    /// @notice Error thrown when a feature is not implemented
    error Everclear_NotImplemented();
    /// @notice Error thrown when maximum slippage is exceeded
    error Everclear_MaxSlippageExceeded();
    /// @notice Error thrown when provided address is invalid
    error Everclear_AddressNotValid();
    /// @notice Error thrown when provided destination is invalid
    error Everclear_DestinationNotValid();
    /// @notice Error thrown when destination arrays have mismatched length
    error Everclear_DestinationsLengthMismatch();

    // ----------- CONSTRUCTOR ------------
    /// @notice Initializes the Everclear V2 bridge
    /// @param _roles Roles contract address
    /// @param _feeAdapter Everclear V2 fee adapter address
    constructor(address _roles, address _feeAdapter) BaseBridge(_roles) {
        require(_feeAdapter != address(0), Everclear_AddressNotValid());

        everclearFeeAdapter = IFeeAdapterV2(_feeAdapter);
    }

    // ----------- ADMIN ------------
    /// @notice Sets the Everclear V2 fee adapter contract
    /// @param _feeAdapter New Everclear V2 fee adapter address
    function setEverclearFeeAdapter(address _feeAdapter) external onlyBridgeConfigurator {
        // Requirements: the new fee adapter address is not the zero address
        require(_feeAdapter != address(0), Everclear_AddressNotValid());

        address old = address(everclearFeeAdapter);
        // Effects: set the new fee adapter address
        everclearFeeAdapter = IFeeAdapterV2(_feeAdapter);

        // Events: emit the event
        emit EverclearFeeAdapterUpdated(old, _feeAdapter);
    }

    // ----------- EXTERNAL ------------
    /// @inheritdoc IBridge
    function sendMsg(
        uint256 _extractedAmount,
        address _market,
        uint32 _dstChainId,
        address _token,
        bytes calldata _message,
        bytes calldata /* _bridgeData */
    ) external payable onlyRebalancer {
        IntentParams memory params = _decodeIntent(_message);

        // Requirements: the input asset matches the token
        require(params.inputAsset == _token, Everclear_TokenMismatch());

        // Requirements: the extracted amount is greater than or equal to the amount
        require(_extractedAmount >= params.amount, BaseBridge_AmountMismatch());

        // Requirements: the amount is greater than 0
        require(params.amount > 0, BaseBridge_AmountMismatch());

        // Requirements: the receiver matches the market
        require(address(uint160(uint256(params.receiver))) == _market, BaseBridge_AddressNotValid());

        uint256 destinationsLength = params.destinations.length;

        // Requirements: the destinations length is 1
        require(destinationsLength == 1, Everclear_DestinationsLengthMismatch());

        // Requirements: the destination matches the destination chain id
        require(params.destinations[0] == _dstChainId, Everclear_DestinationNotValid());

        // Requirements: the amountOutMin is at least 90% of the amount
        require(params.amountOutMin >= params.amount * 9 / 10, Everclear_MaxSlippageExceeded());

        // Interactions: transfer the tokens from the sender to the contract
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _extractedAmount);

        // Requirements: the extracted amount is greater than the amount plus the fee
        if (_extractedAmount > params.amount + params.feeParams.fee) {
            // Interactions: transfer the excess tokens to the market
            uint256 toReturn = _extractedAmount - params.amount - params.feeParams.fee;
            IERC20(_token).safeTransfer(_market, toReturn);

            // Events: emit the rebalancing returned to market event
            emit RebalancingReturnedToMarket(_market, toReturn, _extractedAmount);
        }

        // Interactions: approve the tokens to the fee adapter
        SafeApprove.safeApprove(params.inputAsset, address(everclearFeeAdapter), params.amount + params.feeParams.fee);

        // Interactions: create a new intent
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

        // Events: emit the message sent event
        emit MsgSent(_dstChainId, _market, params.amount, id);
    }

    // ----------- VIEW ------------
    /// @inheritdoc IBridge
    function getFee(uint32, bytes calldata, bytes calldata) external pure returns (uint256) {
        // need to use Everclear API
        revert Everclear_NotImplemented();
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
        ) = abi.decode(intentData, (uint32[], bytes32, address, bytes32, uint256, uint256, uint48, bytes));

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
    function _extractFeeParams(bytes memory intentData)
        private
        pure
        returns (uint256 fee, uint256 deadline, bytes memory sig)
    {
        uint256 feeParamsOffset = BytesLib.toUint256(intentData, 0x100);
        uint256 feeParamsPtr = feeParamsOffset;

        fee = BytesLib.toUint256(intentData, feeParamsPtr);
        deadline = BytesLib.toUint256(intentData, feeParamsPtr + 32);

        uint256 sigOffset = BytesLib.toUint256(intentData, feeParamsOffset + 64);
        uint256 sigLen = BytesLib.toUint256(intentData, feeParamsOffset + sigOffset);
        sig = BytesLib.slice(intentData, feeParamsOffset + sigOffset + 32, sigLen);
    }
}

