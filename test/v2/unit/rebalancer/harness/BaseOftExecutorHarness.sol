// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {MessagingFee, SendParam} from "src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol";
import {MessagingReceipt} from "src/interfaces/external/layerzero/v2/ILayerZeroEndpointV2.sol";
import {BaseOftMessageExecutor} from "src/rebalancer/bridges/helpers/BaseOftMessageExecutor.sol";

contract BaseOftExecutorHarness is BaseOftMessageExecutor {
    function executeSend(address, address, SendParam calldata, MessagingFee calldata, address, address)
        external
        payable
        override
        returns (MessagingReceipt memory)
    {
        revert("not implemented");
    }

    function pullFromRebalancer(address underlying, uint256 amount, address rebalancer) external {
        _pullFromRebalancer(underlying, amount, rebalancer);
    }

    function approveToken(address token, address spender, uint256 amount) external {
        _approve(token, spender, amount);
    }

    function sendOFT(address oft, SendParam calldata params, MessagingFee calldata fees, address refundAddress)
        external
        payable
        returns (MessagingReceipt memory)
    {
        return _sendOFT(oft, params, fees, refundAddress);
    }

    function fallbackToUnderlying(address market, address underlying, address bridgeContract) external {
        _fallbackToUnderlying(market, underlying, bridgeContract);
    }

    function verifyMinted(address oft, uint256 required) external view {
        _verifyMinted(oft, required);
    }
}
