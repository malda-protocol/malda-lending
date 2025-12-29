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

import {BytesLib} from "src/libraries/BytesLib.sol";
import {SafeApprove} from "src/libraries/SafeApprove.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IMessageTransmitterV2} from "src/interfaces/external/cctp/IMessageTransmitterV2.sol";
import {ITokenMessangerV2} from "src/interfaces/external/cctp/ITokenMessangerV2.sol";

/// @title CCTPHelper
/// @author Malda Protocol
/// @notice Helper for building/sending/receiving CCTP v2 messages and encoding/decoding hook payloads.
abstract contract CCTPHelper {
    using BytesLib for bytes;
    using SafeERC20 for IERC20;

    // ----------- STORAGE ------------

    /// @notice Struct used to encode and decode the app-level hook payload carried by CCTP v2.
    struct CCTPMessage {
        bytes32 token; // ERC20 token address left-padded to 32 bytes
        uint256 amount;
        uint32 srcChain; // CCTP domain on source
        uint32 dstChain; // CCTP domain on destination
        uint64 nonce; // always 0 for v2; kept for compatibility
        bytes32 from; // msg.sender on source (left-padded)
        bytes32 receiver; // receiver/caller bytes32
        bytes payload; // opaque app payload
    }

    /// @notice Circle TokenMessenger (v2) used to burn tokens and attach hook data.
    address public immutable TOKEN_MESSENGER; // ITokenMessangerV2

    /// @notice Circle MessageTransmitter (v2) used to validate and receive messages with attestations.
    address public immutable MESSAGE_TRANSMITTER; // IMessageTransmitterV2

    /// @notice Token allowlist for burns via CCTP.
    mapping(address token => bool isAccepted) public acceptedTokens;

    // ----------- EVENTS ------------

    /// @notice Emitted after a burn is initiated via TokenMessenger.
    /// @param token The ERC20 token burned.
    /// @param amount The amount burned.
    /// @param dstDomain The destination CCTP domain.
    /// @param recipient The destination recipient (bytes32).
    /// @param nonce Always 0 for CCTP v2 (kept for compatibility).
    /// @param payload Hook payload passed to Circle.
    event BurnInitiated(
        address indexed token,
        uint256 amount,
        uint32 dstDomain,
        bytes32 indexed recipient,
        uint64 indexed nonce,
        bytes payload
    );

    /// @notice Emitted when an app-level message payload is constructed and encoded.
    /// @param token Token address (bytes32 encoded).
    /// @param amount Amount burned.
    /// @param srcDomain Source CCTP domain.
    /// @param dstDomain Destination CCTP domain.
    /// @param nonce Always 0 for CCTP v2 (kept for compatibility).
    /// @param from Sender (bytes32 encoded).
    /// @param receiver Receiver (bytes32).
    /// @param payload App payload.
    /// @param encodedMessage Encoded packed representation produced by `_encodeMsg`.
    event MessageCreated(
        bytes32 indexed token,
        uint256 amount,
        uint32 indexed srcDomain,
        uint32 indexed dstDomain,
        uint64 nonce,
        bytes32 from,
        bytes32 receiver,
        bytes payload,
        bytes encodedMessage
    );

    /// @notice Emitted after a message is received/validated by Circle and decoded into the app payload.
    /// @param nonce Always 0 for CCTP v2 (kept for compatibility).
    /// @param srcDomain Source CCTP domain.
    /// @param dstDomain Destination CCTP domain.
    /// @param amount Amount received.
    /// @param receiver Receiver (bytes32).
    /// @param payload App payload.
    event MessageReceived(
        uint64 indexed nonce,
        uint32 indexed srcDomain,
        uint32 indexed dstDomain,
        uint256 amount,
        bytes32 receiver,
        bytes payload
    );

    // ----------- ERRORS ------------

    error CCTPHelper_AmountZero();
    error CCTPHelper_AddressZero();
    error CCTPHelper_TokenNotAccepted();
    error CCTPHelper_ReceiveFailed();
    error CCTPHelper_LengthMismatch();
    error CCTPHelper_PayloadMismatch();
    error CCTPHelper_MsgTooShort();

    constructor(address _tokenMessenger, address _messageTransmitter) {
        require(_tokenMessenger != address(0), CCTPHelper_AddressZero());
        require(_messageTransmitter != address(0), CCTPHelper_AddressZero());
        TOKEN_MESSENGER = _tokenMessenger;
        MESSAGE_TRANSMITTER = _messageTransmitter;
    }

    // ----------- INTERNAL ------------

    /// @notice Burns tokens via CCTP v2 and returns the decoded message struct plus its encoded representation.
    /// @param _token Token to burn.
    /// @param _amount Amount to burn.
    /// @param _dstDomain Destination CCTP domain.
    /// @param _receiver Receiver bytes32 (typically the bridge address encoded).
    /// @param _payload App payload to attach as hook data.
    /// @param _srcDomain Source CCTP domain.
    /// @return msgData Parsed message struct (nonce is 0 for v2).
    /// @return encoded Packed encoding of `msgData` produced by `_encodeMsg`.
    function createAndBurn(
        address _token,
        uint256 _amount,
        uint32 _dstDomain,
        bytes32 _receiver,
        bytes calldata _payload,
        uint32 _srcDomain
    ) internal returns (CCTPMessage memory msgData, bytes memory encoded) {
        uint64 nonce = _burnSrc(_token, _amount, _dstDomain, _receiver, _payload);

        // store payload in memory inside the struct
        bytes memory payloadMem = _payload;

        msgData = CCTPMessage({
            token: _toBytes32(_token),
            amount: _amount,
            srcChain: _srcDomain,
            dstChain: _dstDomain,
            nonce: nonce,
            from: _toBytes32(msg.sender),
            receiver: _receiver,
            payload: payloadMem
        });

        encoded = _encodeMsg(msgData);

        emit MessageCreated(
            msgData.token,
            msgData.amount,
            msgData.srcChain,
            msgData.dstChain,
            msgData.nonce,
            msgData.from,
            msgData.receiver,
            msgData.payload,
            encoded
        );
    }

    /// @notice Validates a CCTP message+attestation via Circle and decodes the embedded hook payload into a CCTPMessage.
    /// @param cctpMessage Raw CCTP message bytes.
    /// @param attestation Circle attestation proving message validity.
    /// @return msgData Decoded app-level message extracted from the hook payload.
    function handleDestinationMsg(bytes calldata cctpMessage, bytes calldata attestation)
        internal
        returns (CCTPMessage memory msgData)
    {
        bool success = IMessageTransmitterV2(MESSAGE_TRANSMITTER).receiveMessage(cctpMessage, attestation);
        require(success, CCTPHelper_ReceiveFailed());

        bytes memory msgBytes = cctpMessage;
        require(msgBytes.length >= 148, CCTPHelper_MsgTooShort());

        // Message body starts after the 148-byte CCTP message header
        bytes memory messageBody = msgBytes.slice(148, msgBytes.length - 148);
        require(messageBody.length >= 228, CCTPHelper_MsgTooShort());

        // Hook payload starts after the 228-byte message body header
        bytes memory hookData = messageBody.slice(228, messageBody.length - 228);

        msgData = _decodeMsg(hookData);

        emit MessageReceived(
            msgData.nonce, msgData.srcChain, msgData.dstChain, msgData.amount, msgData.receiver, msgData.payload
        );
    }

    /// @notice Converts an address to a left-padded bytes32 representation.
    /// @param addr Address to convert.
    /// @return Encoded bytes32.
    function _toBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    // ----------- PRIVATE ------------

    function _burnSrc(address _token, uint256 _amount, uint32 _dstDomain, bytes32 _receiver, bytes calldata _payload)
        private
        returns (uint64 nonce)
    {
        require(_amount != 0, CCTPHelper_AmountZero());
        require(_receiver != bytes32(0), CCTPHelper_AddressZero());
        require(acceptedTokens[_token], CCTPHelper_TokenNotAccepted());

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        SafeApprove.safeApprove(_token, TOKEN_MESSENGER, _amount);

        // @dev set to 0 to enforce that Circle cannot charge any CCTP fee on this path
        // the burn only succeeds on lanes where the minimum Standard Transfer fee is currently zero
        uint256 maxFee = 0;

        // @dev behaves as a standard transfer with zero fee (equivalent of 'use the lowest fast threshold 1000')
        // rely on Circle current configuration where the standard mode on this lane is free
        uint32 minFinalityThreshold = 0;

        // @dev if set to zero, any address can call receiveMessage
        bytes32 destinationCaller = bytes32(0);

        ITokenMessangerV2(TOKEN_MESSENGER)
            .depositForBurnWithHook(
                _amount, _dstDomain, _receiver, _token, destinationCaller, maxFee, minFinalityThreshold, _payload
            );

        // @dev CCTP V2 does not expose a nonce anymore
        // Keep it here for backwards compatibility with V1 in terms of flow and structure
        nonce = 0;

        emit BurnInitiated(_token, _amount, _dstDomain, _receiver, nonce, _payload);
    }

    /**
     * Encodes a CCTPMessage into a compact, packed byte format.
     *
     * Layout (all fields big-endian where applicable):
     *
     *  - [  0 ..   0] : uint8    payloadId (fixed = 1)
     *  - [  1 ..  32] : bytes32  token         (ERC20 address left-padded to 32 bytes)
     *  - [ 33 ..  64] : uint256  amount
     *  - [ 65 ..  68] : uint32   srcChain     (CCTP domain / chain id)
     *  - [ 69 ..  72] : uint32   dstChain
     *  - [ 73 ..  80] : uint64   nonce        (0 for CCTP v2; kept for compatibility)
     *  - [ 81 .. 112] : bytes32  from         (sender address left-padded)
     *  - [113 .. 144] : bytes32  receiver     (receiver address or arbitrary 32 bytes)
     *  - [145 .. 146] : uint16   payloadLen   (length of `payload` below)
     *  - [147 .. end] : bytes    payload      (opaque app-level payload)
     *
     * Minimum length with empty payload is therefore 147 bytes.
     */
    function _encodeMsg(CCTPMessage memory message) private pure returns (bytes memory) {
        return abi.encodePacked(
            uint8(1),
            message.token,
            message.amount,
            message.srcChain,
            message.dstChain,
            message.nonce,
            message.from,
            message.receiver,
            uint16(message.payload.length),
            message.payload
        );
    }

    /**
     * Decodes bytes produced by `_encodeMsg` back into a CCTPMessage.
     *
     * Expects exactly the layout documented above:
     *  - Reverts with CCTPHelper_MsgTooShort if the buffer is shorter than
     *    the fixed header (147 bytes).
     *  - Reverts with CCTPHelper_PayloadMismatch if `payloadId != 1`.
     *  - Reverts with CCTPHelper_LengthMismatch if the trailing bytes length
     *    does not match the embedded `payloadLen`.
     *
     * Numeric fields are read as big-endian from the high bits of a 32-byte word:
     *  - uint32 values are taken from the highest 4 bytes of the word (shr(224, ...)).
     *  - uint64 values are taken from the highest 8 bytes of the word (shr(192, ...)).
     *  - uint16 values are taken from the highest 2 bytes of the word (shr(240, ...)).
     *
     * The `payload` bytes are copied verbatim into a new bytes array.
     */
    function _decodeMsg(bytes memory encoded) private pure returns (CCTPMessage memory message) {
        require(encoded.length >= 147, CCTPHelper_MsgTooShort());

        uint256 offset = 0;

        // payloadId
        uint8 payloadId = uint8(encoded[0]);
        require(payloadId == 1, CCTPHelper_PayloadMismatch());
        offset = 1;

        // token (32 bytes)
        bytes32 token = encoded.toBytes32(offset);
        offset += 32;

        // amount (32 bytes)
        uint256 amount = encoded.toUint256(offset);
        offset += 32;

        // srcChain (uint32)
        uint32 srcChain = encoded.toUint32(offset);
        offset += 4;

        // dstChain (uint32)
        uint32 dstChain = encoded.toUint32(offset);
        offset += 4;

        // nonce (uint64)
        uint64 nonce = encoded.toUint64(offset);
        offset += 8;

        // from (bytes32)
        bytes32 from = encoded.toBytes32(offset);
        offset += 32;

        // receiver (bytes32)
        bytes32 receiver = encoded.toBytes32(offset);
        offset += 32;

        // payloadLen (uint16)
        uint16 payloadLen = encoded.toUint16(offset);
        offset += 2;

        // check length: encoded must be EXACTLY offset + payloadLen
        require(encoded.length == offset + payloadLen, CCTPHelper_LengthMismatch());

        // payload
        bytes memory payload = encoded.slice(offset, payloadLen);

        message = CCTPMessage({
            token: token,
            amount: amount,
            srcChain: srcChain,
            dstChain: dstChain,
            nonce: nonce,
            from: from,
            receiver: receiver,
            payload: payload
        });
    }
}
