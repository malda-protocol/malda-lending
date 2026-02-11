// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {IOftMessageExecutor} from "src/interfaces/IOftMessageExecutor.sol";
import {
    ILayerZeroOFT,
    SendParam,
    MessagingFee,
    OFTLimit,
    OFTReceipt,
    OFTFeeDetail
} from "src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol";
import {MessagingReceipt} from "src/interfaces/external/layerzero/v2/ILayerZeroEndpointV2.sol";

contract LZBridgeMockMarket {
    address public underlying;

    constructor(address _underlying) {
        underlying = _underlying;
    }
}

contract LZBridgeMockOFT is ILayerZeroOFT {
    MessagingFee public quoteFee;
    SendParam public lastSendParams;
    MessagingFee public lastSendFee;
    address public lastRefund;
    address public innerToken;

    constructor(address _innerToken) {
        innerToken = _innerToken;
    }

    function setQuoteFee(uint256 nativeFee, uint256 lzTokenFee) external {
        quoteFee = MessagingFee({nativeFee: nativeFee, lzTokenFee: lzTokenFee});
    }

    function oftVersion() external pure returns (bytes4 interfaceId, uint64 version) {
        return (bytes4(0), 0);
    }

    function token() external view returns (address) {
        return innerToken;
    }

    function approvalRequired() external pure returns (bool) {
        return false;
    }

    function sharedDecimals() external pure returns (uint8) {
        return 18;
    }

    function quoteOFT(SendParam calldata)
        external
        pure
        returns (OFTLimit memory, OFTFeeDetail[] memory, OFTReceipt memory)
    {
        return (OFTLimit({minAmountLD: 0, maxAmountLD: 0}), new OFTFeeDetail[](0), OFTReceipt(0, 0));
    }

    function quoteSend(SendParam calldata, bool) external view returns (MessagingFee memory) {
        return quoteFee;
    }

    function send(SendParam calldata _sendParam, MessagingFee calldata _fee, address _refundAddress)
        external
        payable
        returns (MessagingReceipt memory receipt, OFTReceipt memory oftReceipt)
    {
        lastSendParams = _sendParam;
        lastSendFee = _fee;
        lastRefund = _refundAddress;
        receipt = MessagingReceipt({guid: bytes32("guid"), nonce: 1, fee: _fee});
        oftReceipt = OFTReceipt({amountSentLD: _sendParam.amountLD, amountReceivedLD: _sendParam.amountLD});
    }
}

contract LZBridgeMockExecutor is IOftMessageExecutor {
    function executeSend(address, address, SendParam calldata, MessagingFee calldata fees, address, address)
        external
        payable
        returns (MessagingReceipt memory receipt)
    {
        receipt = MessagingReceipt({guid: bytes32("guid"), nonce: 1, fee: fees});
    }

    function processUncomposed(address, address, address) external payable {}

    function executeCompose(address, address, address) external payable {}
}

contract LZBridgeRevertingExecutor is IOftMessageExecutor {
    error ExecutorRevert();

    function executeSend(address, address, SendParam calldata, MessagingFee calldata, address, address)
        external
        payable
        returns (MessagingReceipt memory)
    {
        revert ExecutorRevert();
    }

    function processUncomposed(address, address, address) external payable {
        revert ExecutorRevert();
    }

    function executeCompose(address, address, address) external payable {
        revert ExecutorRevert();
    }
}
