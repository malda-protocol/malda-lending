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
import {IEverclearSpoke} from "src/interfaces/external/everclear/IEverclearSpoke.sol";

import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";

contract EverclearBridge is BaseBridge, IBridge {
    using SafeERC20 for IERC20;

    // ----------- STORAGE ------------
    mapping(uint256 dstChainId => uint32 eId) public chainToEid;

    IEverclearSpoke public everclearSpoke;

    // ----------- EVENTS ------------
    event ChainIdSet(uint256 indexed chainId, uint256 indexed eId);
    event MsgSent(uint256 indexed dstChainId, address indexed market, uint256 amountLD, bytes32 id);

    // ----------- ERRORS ------------
    error Everclear_NotImplemented();

    constructor(address _roles, address _spoke) BaseBridge(_roles) {
        everclearSpoke = IEverclearSpoke(_spoke);
    }

    // ----------- OWNER ------------
    /**
     * @notice updates cross chain peer
     * @param _chainId the block.chain id
     * @param _eId the Everclear endpoint id
     */
    function updateChainToEid(uint256 _chainId, uint32 _eId) external onlyBridgeConfigurator {
        chainToEid[_chainId] = _eId;
        emit ChainIdSet(_chainId, _eId);
    }

    // ----------- VIEW ------------
    /**
     * @inheritdoc IBridge
     */
    function getFee(uint256, bytes memory, bytes memory) external pure returns (uint256) {
        // need to use Everclear API
        revert Everclear_NotImplemented();
    }

    // ----------- EXTERNAL ------------
    /**
     * @inheritdoc IBridge
     */
    function sendMsg(uint256 _dstChainId, address _token, bytes memory _message, bytes memory)
        external
        payable
        onlyRebalancer
    {
        // decode message & checks
        (address market, address outputAsset, uint256 amount, bytes memory data) =
            abi.decode(_message, (address, address, uint256, bytes));
        require(amount >= minTransfer && amount <= maxTransfer, BaseBridge_AmountNotValid());

        // retrieve tokens from `Rebalancer`
        IERC20(_token).safeTransferFrom(msg.sender, address(this), amount);

        // approve and send with Everclear
        uint32[] memory destinations = new uint32[](1);
        destinations[0] = chainToEid[_dstChainId];
        SafeApprove.safeApprove(_token, address(everclearSpoke), amount);
        (bytes32 _intentId,) = everclearSpoke.newIntent(destinations, market, _token, outputAsset, amount, 0, 0, data);
        emit MsgSent(_dstChainId, market, amount, _intentId);
    }
}
