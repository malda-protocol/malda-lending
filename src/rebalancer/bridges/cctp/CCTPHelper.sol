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

contract CCTPHelper {
    using BytesLib for bytes;
    using SafeERC20 for IERC20;

    // ----------- STORAGE ------------
    struct CCTPMessage {
        bytes32 token; // usdc
        uint256 amount;
        uint32 srcChain;
        uint32 dstChain;
        uint64 nonce;
        bytes32 from;
        bytes32 receiver;
        bytes payload;
    }

    address public immutable tokenMessenger; // ITokenMessangerV2
    address public immutable messageTransmitter; // IMessageTransmitterV2
    mapping(address => bool) public acceptedTokens;

    // ----------- EVENTS ------------
    event BurnInitiated(
        address indexed token,
        uint256 amount,
        uint32 dstDomain,
        bytes32 indexed recipient,
        uint64 indexed nonce,
        bytes payload
    );

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

    event MessageReceived(
        uint64 indexed nonce,
        uint32 indexed srcDomain,
        uint32 indexed dstDomain,
        uint256 amount,
        bytes32 receiver,
        bytes payload
    );

    // ----------- ERRORS ------------
    error CCTPHeloer_AmountZero();
    error CCTPHeloer_AddressZero();
    error CCTPHeloer_TokenNotAccepted();
    error CCTPHeloer_ReceiveFailed();
    error CCTPHeloer_LengthMismatch();
    error CCTPHeloer_PayloadMismatch();
    error CCTPHeloer_MsgTooShort();

    constructor(address _tokenMessenger, address _messageTransmitter) {
        require(_tokenMessenger != address(0), CCTPHeloer_AddressZero());
        require(_messageTransmitter != address(0), CCTPHeloer_AddressZero());
        tokenMessenger = _tokenMessenger;
        messageTransmitter = _messageTransmitter;
    }

    // ----------- INTERNAL ------------
    function createAndBurn(
        address _token,
        uint256 _amount,
        uint32 _dstDomain,
        bytes32 _receiver,
        bytes memory _payload,
        uint32 _srcDomain
    ) internal returns (CCTPMessage memory msgData, bytes memory encoded) {
        uint64 nonce = _burnSrc(
            _token,
            _amount,
            _dstDomain,
            _receiver,
            _payload
        );

        msgData = CCTPMessage({
            token: _toBytes32(_token),
            amount: _amount,
            srcChain: _srcDomain,
            dstChain: _dstDomain,
            nonce: nonce,
            from: _toBytes32(msg.sender),
            receiver: _receiver,
            payload: _payload
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

    function handleDestinationMsg(
        bytes calldata cctpMessage,
        bytes calldata attestation
    ) internal returns (CCTPMessage memory msgData) {
        bool success = IMessageTransmitterV2(messageTransmitter).receiveMessage(
            cctpMessage,
            attestation
        );
        if (!success) revert CCTPHeloer_ReceiveFailed();

        bytes memory msgBytes = cctpMessage;
        if (msgBytes.length < 148) revert CCTPHeloer_MsgTooShort();
        bytes memory messageBody = msgBytes.slice(148, msgBytes.length - 148);

        if (messageBody.length < 228) revert CCTPHeloer_MsgTooShort();
        bytes memory hookData = messageBody.slice(228, messageBody.length - 228);

        msgData = _decodeMsg(hookData);

        emit MessageReceived(
            msgData.nonce,
            msgData.srcChain,
            msgData.dstChain,
            msgData.amount,
            msgData.receiver,
            msgData.payload
        );
    }

    function _toBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    // ----------- PRIVATE ------------
    function _burnSrc(
        address _token,
        uint256 _amount,
        uint32 _dstDomain,
        bytes32 _receiver,
        bytes memory _payload
    ) private returns (uint64 nonce) {
        if (_amount == 0) revert CCTPHeloer_AmountZero();
        if (_receiver == bytes32(0)) revert CCTPHeloer_AddressZero();
        if (!acceptedTokens[_token]) revert CCTPHeloer_TokenNotAccepted();

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        SafeApprove.safeApprove(_token, tokenMessenger, 0);
        SafeApprove.safeApprove(_token, tokenMessenger, _amount);

        uint256 maxFee = 0;
        uint32 minFinalityThreshold = 0;
        bytes32 destinationCaller = bytes32(0);

        ITokenMessangerV2(tokenMessenger).depositForBurnWithHook(
            _amount,
            _dstDomain,
            _receiver,
            _token,
            destinationCaller,
            maxFee,
            minFinalityThreshold,
            _payload
        );

        nonce = 0;

        emit BurnInitiated(_token, _amount, _dstDomain, _receiver, nonce, _payload);
    }

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

    function _decodeMsg(bytes memory encoded) private pure returns (CCTPMessage memory message) {
        if (encoded.length < 147) revert CCTPHeloer_MsgTooShort();

        uint256 offset;

        uint8 payloadId = uint8(encoded[0]);
        if (payloadId != 1) revert CCTPHeloer_PayloadMismatch();
        offset = 1;

        bytes32 token;
        uint256 amount;
        uint32 srcChain;
        uint32 dstChain;
        uint64 nonce;
        bytes32 from;
        bytes32 receiver;
        uint16 payloadLen;

        assembly { token := mload(add(encoded, add(0x20, offset))) }
        offset += 32;

        assembly { amount := mload(add(encoded, add(0x20, offset))) }
        offset += 32;

        assembly { srcChain := shr(224, mload(add(encoded, add(0x20, offset)))) }
        offset += 4;

        assembly { dstChain := shr(224, mload(add(encoded, add(0x20, offset)))) }
        offset += 4;

        assembly { nonce := shr(192, mload(add(encoded, add(0x20, offset)))) }
        offset += 8;

        assembly { from := mload(add(encoded, add(0x20, offset))) }
        offset += 32;

        assembly { receiver := mload(add(encoded, add(0x20, offset))) }
        offset += 32;

        assembly { payloadLen := shr(240, mload(add(encoded, add(0x20, offset)))) }
        offset += 2;

        if (encoded.length != offset + payloadLen) revert CCTPHeloer_LengthMismatch();

        bytes memory payload = new bytes(payloadLen);
        for (uint256 i = 0; i < payloadLen; ) {
            payload[i] = encoded[offset + i];
            unchecked { ++i; }
        }

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
