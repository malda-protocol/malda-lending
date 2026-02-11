// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {IMessageTransmitterV2} from "src/interfaces/external/cctp/IMessageTransmitterV2.sol";
import {ITokenMessangerV2} from "src/interfaces/external/cctp/ITokenMessangerV2.sol";

contract MockTokenMessenger is ITokenMessangerV2 {
    address public lastToken;
    uint256 public lastAmount;
    uint32 public lastDst;
    bytes32 public lastReceiver;
    bytes32 public lastDestinationCaller;
    uint256 public lastMaxFee;
    uint32 public lastMinFinalityThreshold;
    bytes public lastPayload;
    address public lastCaller;

    function depositForBurnWithHook(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold,
        bytes calldata hookData
    ) external override {
        lastCaller = msg.sender;
        lastAmount = amount;
        lastDst = destinationDomain;
        lastReceiver = mintRecipient;
        lastToken = burnToken;
        lastDestinationCaller = destinationCaller;
        lastMaxFee = maxFee;
        lastMinFinalityThreshold = minFinalityThreshold;
        lastPayload = hookData;
    }
}

contract MockMessageTransmitter is IMessageTransmitterV2 {
    bool public shouldSucceed = true;
    bytes public lastMessage;
    bytes public lastAttestation;

    function setShouldSucceed(bool val) external {
        shouldSucceed = val;
    }

    function receiveMessage(bytes calldata message, bytes calldata attestation) external override returns (bool) {
        lastMessage = message;
        lastAttestation = attestation;
        return shouldSucceed;
    }
}
