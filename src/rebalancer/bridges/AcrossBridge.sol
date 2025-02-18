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

import {IBridge} from "src/interfaces/IBridge.sol";
import {ImTokenMinimal} from "src/interfaces/ImToken.sol";
import {IAcrossSpokePoolV3} from "src/interfaces/external/across/IAcrossSpokePoolV3.sol";

import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";

contract AccrossBridge is BaseBridge, IBridge {
    using SafeERC20 for IERC20;

    // ----------- STORAGE ------------
    address public immutable acrossSpokePool;

    struct DecodedMessage {
        address market;
        uint256 inputAmount;
        uint256 outputAmount;
        address relayer;
        uint32 deadline;
        uint32 exclusivityDeadline;
    }

    // ----------- EVENTS ------------
    event Rebalanced(address indexed market, uint256 amount);

    // ----------- ERRORS ------------
    error AcrossBridge_TokenMismatch();
    error AcrossBridge_NotAuthorized();
    error AcrossBridge_NotImplemented();
    error AcrossBridge_AddressNotValid();

    constructor(address _roles, address _spokePool) BaseBridge(_roles) {
        require(_spokePool != address(0), AcrossBridge_AddressNotValid());
        acrossSpokePool = _spokePool;
    }

    modifier onlySpokePool() {
        require(msg.sender == acrossSpokePool, AcrossBridge_NotAuthorized());
        _;
    }

    // ----------- VIEW ------------
    /**
     * @inheritdoc IBridge
     */
    function getFee(uint32, bytes memory, bytes memory) external pure returns (uint256) {
        // need to use Across API
        revert AcrossBridge_NotImplemented();
    }

    // ----------- EXTERNAL ------------
    /**
     * @inheritdoc IBridge
     */
    function sendMsg(uint32 _dstChainId, address _token, bytes memory _message, bytes memory)
        external
        payable
        onlyRebalancer
    {
        // decode message & checks
        DecodedMessage memory msgData = _decodeMessage(_message);

        // retrieve tokens from `Rebalancer`
        IERC20(_token).safeTransferFrom(msg.sender, address(this), msgData.inputAmount);

        // approve and send with Across
        SafeApprove.safeApprove(_token, address(acrossSpokePool), msgData.inputAmount);
        IAcrossSpokePoolV3(acrossSpokePool).depositV3Now( // no need for `msg.value`; fee is taken from amount
            msg.sender, //depositor
            address(this), //recipient
            _token,
            address(0), //outputToken is automatically resolved to the same token on destination
            msgData.inputAmount,
            msgData.outputAmount, //outputAmount should be set as the inputAmount - relay fees; use Across API
            uint256(_dstChainId),
            msgData.relayer, //exclusiveRelayer
            msgData.deadline, //fillDeadline
            msgData.exclusivityDeadline, //can use Across API/suggested-fees or 0 to disable
            abi.encode(msgData.market)
        );
    }

    /**
     * @notice handles AcrossV3 SpokePool message
     * @param tokenSent the token address received
     * @param amount the token amount
     * @param message the custom message sent from source
     */
    function handleV3AcrossMessage(
        address tokenSent,
        uint256 amount,
        address, // relayer is unused
        bytes memory message
    ) external onlySpokePool {
        address market = abi.decode(message, (address));
        address _underlying = ImTokenMinimal(market).underlying();
        require(_underlying == tokenSent, AcrossBridge_TokenMismatch());
        if (amount > 0) {
            IERC20(tokenSent).safeTransfer(market, amount);
        }

        emit Rebalanced(market, amount);
    }

    // ----------- PRIVATE ------------
    function _decodeMessage(bytes memory _message) private pure returns (DecodedMessage memory) {
        (
            address market,
            uint256 inputAmount,
            uint256 outputAmount,
            address relayer,
            uint32 deadline,
            uint32 exclusivityDeadline
        ) = abi.decode(_message, (address, uint256, uint256, address, uint32, uint32));

        return DecodedMessage(market, inputAmount, outputAmount, relayer, deadline, exclusivityDeadline);
    }
}
