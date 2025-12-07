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

/// @title Everclear bridge implementation
/// @author Malda Protocol
/// @notice Cross-chain bridge using Everclear protocol for intent-based transfers
contract EverclearBridge is BaseBridge, IBridge {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    // ----------- STRUCTS ------------
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

    // ----------- STORAGE ------------
    /// @notice Everclear fee adapter contract
    IFeeAdapter public everclearFeeAdapter;

    // ----------- EVENTS ------------
    /// @notice Emitted when a message is sent via Everclear
    /// @param dstChainId Destination chain ID
    /// @param market Market address
    /// @param amountLD Amount in local decimals
    /// @param id Intent identifier
    event MsgSent(uint256 indexed dstChainId, address indexed market, uint256 amountLD, bytes32 id);

    /// @notice Emitted when excess rebalancing funds are returned to the market
    /// @param market Market address
    /// @param toReturn Amount returned
    /// @param extracted Amount originally extracted
    event RebalancingReturnedToMarket(address indexed market, uint256 toReturn, uint256 extracted);

    // ----------- ERRORS ------------
    /// @notice Error thrown when provided token does not match expected asset
    error Everclear_TokenMismatch();

    /// @notice Error thrown when a feature is not implemented
    error Everclear_NotImplemented();

    /// @notice Error thrown when maximum fee is exceeded
    error Everclear_MaxFeeExceeded();

    /// @notice Error thrown when provided address is invalid
    error Everclear_AddressNotValid();

    /// @notice Error thrown when provided destination is invalid
    error Everclear_DestinationNotValid();

    /// @notice Error thrown when destination arrays have mismatched length
    error Everclear_DestinationsLengthMismatch();

    /// @notice Initializes the Everclear bridge
    /// @param _roles Roles contract address
    /// @param _feeAdapter Everclear fee adapter address
    constructor(address _roles, address _feeAdapter) BaseBridge(_roles) {
        require(_feeAdapter != address(0), Everclear_AddressNotValid());

        everclearFeeAdapter = IFeeAdapter(_feeAdapter);
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

        require(params.inputAsset == _token, Everclear_TokenMismatch());
        require(_extractedAmount >= params.amount, BaseBridge_AmountMismatch());
        require(params.amount > 0, BaseBridge_AmountMismatch());

        require(address(uint160(uint256(params.receiver))) == _market, BaseBridge_AddressNotValid());

        uint256 destinationsLength = params.destinations.length;

        require(destinationsLength == 1, Everclear_DestinationsLengthMismatch());
        require(params.destinations[0] == _dstChainId, Everclear_DestinationNotValid());

        require(params.maxFee <= params.amount / 10, Everclear_MaxFeeExceeded());

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
            0, //max fee
            0, //ttl
            params.data,
            params.feeParams
        );
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
     * - The input `message` is the raw ABI-encoded calldata of a `FeeAdapter.newIntent` call.
     * - The first 4 bytes are the function selector, which are skipped.
     * - The remaining bytes encode the primary intent parameters followed by `FeeParams`.
     * - Because `FeeParams` is a dynamic struct appended at the end, its data must be located by
     *   reading its offset and decoding separately.
     *
     * Layout of `FeeAdapter.newIntent` calldata after the selector:
     * ```
     * destinations (uint32[])   at offset 0x00
     * receiver (bytes32)        at offset 0x20
     * inputAsset (address)      at offset 0x40
     * outputAsset (bytes32)     at offset 0x60
     * amount (uint256)          at offset 0x80
     * maxFee (uint24)           at offset 0xa0
     * ttl (uint48)              at offset 0xc0
     * data (bytes)              at offset 0xe0
     * feeParams (FeeParams)     at offset 0x100 (9th arg → pointer)
     * ```
     * Since each static argument occupies a 32-byte slot, the pointer to `feeParams`
     * lives at offset `0x100` (256 bytes) after the selector is removed.
     *
     * @param message ABI-encoded calldata for `FeeAdapter.newIntent`.
     * @return Decoded `IntentParams` struct with both core parameters and nested `FeeParams`.
     */
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
        ) = abi.decode(intentData, (uint32[], bytes32, address, bytes32, uint256, uint24, uint48, bytes));

        (uint256 fee, uint256 deadline, bytes memory sig) = _extractFeeParams(intentData);
        IFeeAdapter.FeeParams memory feeParams = IFeeAdapter.FeeParams(fee, deadline, sig);

        return IntentParams({
            destinations: destinations,
            receiver: receiver,
            inputAsset: inputAsset,
            outputAsset: outputAsset,
            amount: amount,
            maxFee: maxFee,
            ttl: ttl,
            data: data,
            feeParams: feeParams
        });
    }

    /**
     * @notice Extracts the nested `FeeParams` struct from ABI-encoded `intentData`.
     * @dev
     * - `FeeParams` is the 9th parameter of `FeeAdapter.newIntent` and therefore stored as a pointer at offset `0x100`.
     * - The selector has already been removed, so the pointer is read at byte position `0x100` (256 bytes).
     * - The pointer gives the offset to the start of the `FeeParams` struct relative to the start of intentData.
     * - Within `FeeParams`, the layout is:
     *   ```
     *   fee      (uint256) at +0x00
     *   deadline (uint256) at +0x20
     *   sig      (bytes)   at +0x40 (stored as offset → length → data)
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
        uint256 feeParamsOffset = BytesLib.toUint256(intentData, 0x120);
        uint256 feeParamsPtr = feeParamsOffset;

        fee = BytesLib.toUint256(intentData, feeParamsPtr);
        deadline = BytesLib.toUint256(intentData, feeParamsPtr + 32);

        uint256 sigOffset = BytesLib.toUint256(intentData, feeParamsOffset + 64);
        uint256 sigLen = BytesLib.toUint256(intentData, feeParamsOffset + sigOffset);
        sig = BytesLib.slice(intentData, feeParamsOffset + sigOffset + 32, sigLen);
    }
}
