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
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {SafeApprove} from "src/libraries/SafeApprove.sol";

import {IBridge} from "src/interfaces/IBridge.sol";
import {IRebalancer} from "src/interfaces/IRebalancer.sol";
import {ImTokenMinimal} from "src/interfaces/ImToken.sol";
import {IAcrossSpokePoolV3} from "src/interfaces/external/across/IAcrossSpokePoolV3.sol";
import {IAcrossReceiverV3} from "src/interfaces/external/across/IAcrossReceiverV3.sol";

import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";

/// @title AcrossBridge
/// @author Merge Layers Inc.
/// @notice Bridge integration for Across V3 used by the rebalancer
contract AccrossBridge is BaseBridge, IBridge, IAcrossReceiverV3, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Decoded Across message payload
    struct DecodedMessage {
        address outputToken;
        uint256 inputAmount;
        uint256 outputAmount;
        address relayer;
        uint32 deadline;
        uint32 exclusivityDeadline;
    }

    // ----------- STORAGE ------------
    /// @notice Precision used for slippage calculations
    uint256 private constant SLIPPAGE_PRECISION = 1e5;

    /// @notice Across spoke pool address
    address public immutable ACROSS_SPOKE_POOL;

    /// @notice Maximum allowed slippage in basis points
    uint256 public immutable MAX_SLIPPAGE;

    /// @notice Rebalancer contract address
    address public immutable REBALANCER;

    /// @notice Whitelisted relayers per destination chain
    mapping(uint32 dstChainId => mapping(address relayer => bool isWhitelisted)) public whitelistedRelayers;

    // ----------- EVENTS ------------
    /// @notice Emitted when funds are rebalanced to a market
    /// @param market The market receiving funds
    /// @param amount The amount rebalanced
    event Rebalanced(address indexed market, uint256 amount);

    /// @notice Emitted when relayer whitelist status is updated
    /// @param sender The caller updating whitelist
    /// @param dstId The destination chain ID
    /// @param delegate The relayer address
    /// @param status The whitelist status
    event WhitelistedRelayerStatusUpdated(
        address indexed sender, uint32 indexed dstId, address indexed delegate, bool status
    );

    // ----------- ERRORS ------------
    /// @notice Error thrown when tokens do not match expected underlying
    error AcrossBridge_TokenMismatch();

    /// @notice Error thrown when caller is not authorized
    error AcrossBridge_NotAuthorized();

    /// @notice Error thrown when feature is not implemented
    error AcrossBridge_NotImplemented();

    /// @notice Error thrown when an address is not valid
    error AcrossBridge_AddressNotValid();

    /// @notice Error thrown when slippage exceeds maximum
    error AcrossBridge_SlippageNotValid();

    /// @notice Error thrown when relayer is not valid
    error AcrossBridge_RelayerNotValid();

    /// @notice Error thrown when receiver market is invalid
    error AcrossBridge_InvalidReceiver();

    /// @notice Error thrown when relayer fee exceeds maximum
    error AcrossBridge_MaxFeeExceeded();

    modifier onlySpokePool() {
        require(msg.sender == ACROSS_SPOKE_POOL, AcrossBridge_NotAuthorized());
        _;
    }

    /// @notice Initializes the Across bridge
    /// @param _roles Address of the roles contract
    /// @param _spokePool Address of the Across spoke pool
    /// @param _rebalancer Address of the rebalancer contract
    constructor(address _roles, address _spokePool, address _rebalancer) BaseBridge(_roles) {
        require(_spokePool != address(0), AcrossBridge_AddressNotValid());
        require(_rebalancer != address(0), AcrossBridge_AddressNotValid());
        ACROSS_SPOKE_POOL = _spokePool;
        MAX_SLIPPAGE = 1e4;
        REBALANCER = _rebalancer;
    }

    // ----------- OWNER ------------
    /// @notice Whitelists or removes a relayer for a destination chain
    /// @param _dstId The destination chain ID
    /// @param _relayer The relayer address to update
    /// @param status Whether the relayer is whitelisted
    function setWhitelistedRelayer(uint32 _dstId, address _relayer, bool status) external onlyBridgeConfigurator {
        // @audit zero checks?
        whitelistedRelayers[_dstId][_relayer] = status;
        emit WhitelistedRelayerStatusUpdated(msg.sender, _dstId, _relayer, status);
    }

    // ----------- EXTERNAL ------------
    /**
     * @notice handles AcrossV3 SpokePool message
     * @param tokenSent the token address received
     * @param amount the token amount
     * @param relayer the relayer submitting the message
     * @param message the custom message sent from source
     */
    function handleV3AcrossMessage(
        address tokenSent,
        uint256 amount,
        address relayer, // relayer is unused
        bytes calldata message
    )
        external
        onlySpokePool
        nonReentrant
    {
        relayer;
        address market = abi.decode(message, (address));
        require(IRebalancer(REBALANCER).isMarketWhitelisted(market), AcrossBridge_InvalidReceiver());
        address _underlying = ImTokenMinimal(market).underlying();
        require(_underlying == tokenSent, AcrossBridge_TokenMismatch());
        if (amount > 0) {
            IERC20(tokenSent).safeTransfer(market, amount);
        }

        emit Rebalanced(market, amount);
    }

    /// @inheritdoc IBridge
    function sendMsg(
        uint256 _extractedAmount,
        address _market,
        uint32 _dstChainId,
        address _token,
        bytes calldata _message,
        bytes calldata /* _bridgeData */
    ) external payable onlyRebalancer {
        // decode message & checks
        DecodedMessage memory msgData = _decodeMessage(_message);
        require(_extractedAmount == msgData.inputAmount, BaseBridge_AmountMismatch());
        require(whitelistedRelayers[_dstChainId][msgData.relayer], AcrossBridge_RelayerNotValid());
        require(msgData.outputAmount >= (msgData.inputAmount * 90) / 100, AcrossBridge_MaxFeeExceeded());

        // retrieve tokens from `Rebalancer`
        IERC20(_token).safeTransferFrom(msg.sender, address(this), msgData.inputAmount);

        if (msgData.inputAmount > msgData.outputAmount) {
            uint256 maxSlippageInputAmount = msgData.inputAmount * MAX_SLIPPAGE / SLIPPAGE_PRECISION;
            require(
                msgData.inputAmount - msgData.outputAmount <= maxSlippageInputAmount, AcrossBridge_SlippageNotValid()
            );
        }

        // approve and send with Across
        _depositV3Now(_message, _token, _dstChainId, _market);
    }

    // ----------- VIEW ------------
    /// @notice Returns whether an address is whitelisted as relayer for a destination chain
    /// @param dstChain The destination chain ID
    /// @param relayer The relayer address
    /// @return isWhitelisted True if relayer is whitelisted
    function isRelayerWhitelisted(uint32 dstChain, address relayer) external view returns (bool) {
        return whitelistedRelayers[dstChain][relayer];
    }

    // ----------- PURE ------------
    /// @inheritdoc IBridge
    function getFee(
        uint32,
        /* _dstChainId */
        bytes calldata,
        /* _message */
        bytes calldata /* _bridgeData */
    )
        external
        pure
        returns (uint256)
    {
        // need to use Across API
        revert AcrossBridge_NotImplemented();
    }

    // ----------- PRIVATE ------------
    /// @notice Deposits funds into Across spoke pool for immediate relay
    /// @param _message Encoded Across message
    /// @param _token Token being transferred
    /// @param _dstChainId Destination chain ID
    /// @param _market Market address encoded in the message
    function _depositV3Now(bytes calldata _message, address _token, uint32 _dstChainId, address _market) private {
        DecodedMessage memory msgData = _decodeMessage(_message);
        // approve and send with Across
        SafeApprove.safeApprove(_token, ACROSS_SPOKE_POOL, msgData.inputAmount);
        IAcrossSpokePoolV3(ACROSS_SPOKE_POOL)
            .depositV3Now( // no need for `msg.value`; fee is taken from amount
                msg.sender, //depositor
                address(this), //recipient
                _token,
                msgData.outputToken,
                msgData.inputAmount,
                msgData.outputAmount, //outputAmount should be set as the inputAmount - relay fees; use Across API
                uint256(_dstChainId),
                msgData.relayer, //exclusiveRelayer
                msgData.deadline, //fillDeadline
                msgData.exclusivityDeadline, //can use Across API/suggested-fees or 0 to disable
                abi.encode(_market)
            );
    }

    /// @notice Decodes the Across message payload
    /// @param _message Encoded message data
    /// @return messageData The decoded message struct
    function _decodeMessage(bytes calldata _message) private pure returns (DecodedMessage memory messageData) {
        (
            address outputToken,
            uint256 inputAmount,
            uint256 outputAmount,
            address relayer,
            uint32 deadline,
            uint32 exclusivityDeadline
        ) = abi.decode(_message, (address, uint256, uint256, address, uint32, uint32));

        messageData = DecodedMessage({
            outputToken: outputToken,
            inputAmount: inputAmount,
            outputAmount: outputAmount,
            relayer: relayer,
            deadline: deadline,
            exclusivityDeadline: exclusivityDeadline
        });
    }
}
