// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {CCTPHelper} from "src/rebalancer/bridges/cctp/CCTPHelper.sol";

contract CCTPHelperHarness is CCTPHelper {
    constructor(address _tokenMessenger, address _messageTransmitter)
        CCTPHelper(_tokenMessenger, _messageTransmitter)
    {}

    function exposedCreateAndBurn(
        address _token,
        uint256 _amount,
        uint32 _dstDomain,
        bytes32 _receiver,
        bytes calldata _payload,
        uint32 _srcDomain
    ) external returns (CCTPMessage memory msgData, bytes memory encoded) {
        return createAndBurn(_token, _amount, _dstDomain, _receiver, _payload, _srcDomain);
    }

    function exposedHandleDestinationMsg(bytes calldata cctpMessage, bytes calldata attestation)
        external
        returns (CCTPMessage memory msgData)
    {
        return handleDestinationMsg(cctpMessage, attestation);
    }

    function setAcceptedToken(address token, bool allowed) external {
        acceptedTokens[token] = allowed;
    }
}
