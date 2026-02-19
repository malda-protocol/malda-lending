// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {MessagingFee, MessagingReceipt} from "src/interfaces/external/layerzero/v2/ILayerZeroEndpointV2.sol";
import {ILayerZeroOFT, SendParam} from "src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol";
import {IOftMessageExecutor} from "src/interfaces/IOftMessageExecutor.sol";

contract DummyMarket {
    address public underlying;

    constructor(address underlying_) {
        underlying = underlying_;
    }
}

contract RevertingExecutor {
    error ExecutorRevert();

    function executeSend(address, address, SendParam calldata, MessagingFee calldata, address, address)
        external
        payable
        returns (MessagingReceipt memory)
    {
        revert ExecutorRevert();
    }
}

contract ComposeRevertingExecutor {
    error ComposeRevert();

    function executeCompose(address, address, address) external payable {
        revert ComposeRevert();
    }

    function processUncomposed(address, address, address) external payable {}
}

contract ProcessRevertingExecutor {
    error ProcessRevert();

    function executeCompose(address, address, address) external payable {}

    function processUncomposed(address, address, address) external payable {
        revert ProcessRevert();
    }
}

/// @notice Minimal executor used by fork tests to execute real OFT sends via delegatecall.
/// @dev This intentionally avoids using production executors (which have additional invariants) because the goal
///      of the fork suite is to validate LZUnifiedBridge's checks + integrations against real OFT contracts.
contract LZSendExecutor is IOftMessageExecutor {
    using SafeERC20 for IERC20;

    event ComposeExecuted(address indexed market, address indexed underlying, address indexed bridgeContract);
    event UncomposedProcessed(address indexed market, address indexed underlying, address indexed bridgeContract);

    function executeSend(
        address underlying,
        address bridgeContract,
        SendParam calldata params,
        MessagingFee calldata fees,
        address rebalancer,
        address refundAddress
    ) external payable returns (MessagingReceipt memory receipt) {
        IERC20(underlying).safeTransferFrom(rebalancer, address(this), params.amountLD);

        if (bridgeContract != underlying) {
            IERC20(underlying).approve(bridgeContract, params.amountLD);
        }

        // solhint-disable-next-line check-send-result
        (receipt,) = ILayerZeroOFT(bridgeContract).send{value: fees.nativeFee}(params, fees, refundAddress);
    }

    function processUncomposed(address market, address underlying, address bridgeContract) external payable {
        emit UncomposedProcessed(market, underlying, bridgeContract);
    }

    function executeCompose(address market, address underlying, address bridgeContract) external payable {
        emit ComposeExecuted(market, underlying, bridgeContract);
    }
}
