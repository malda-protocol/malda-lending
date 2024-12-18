// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

import {IRoles} from "src/interfaces/IRoles.sol";
import {IBridge} from "src/interfaces/IBridge.sol";
import {IRebalancer} from "src/interfaces/IRebalancer.sol";

contract Rebalancer is IRebalancer {
    // ----------- STORAGE ------------
    IRoles public roles;
    uint256 public nonce;
    mapping(uint256 => mapping(uint256 => Msg)) public logs;
    mapping(address => bool) public whitelistedBridges;

    constructor(address _roles) {
        roles = IRoles(_roles);
    }

    // ----------- OWNER METHODS ------------
    function setWhitelistedBridgeStatus(address _bridge, bool _status) external {
        //TODO: add role check
        whitelistedBridges[_bridge] = _status;
        emit BridgeWhitelistedStatusUpdated(_bridge, _status);
    }

    // ----------- VIEW METHODS ------------
    /**
     * @inheritdoc IRebalancer
     */
    function isBridgeWhitelisted(address bridge) external view returns (bool) {
        return whitelistedBridges[bridge];
    }

    // ----------- EXTERNAL METHODS ------------
    /**
     * @inheritdoc IRebalancer
     */
    function sendMsg(address _bridge, Msg calldata _msg) external {
        require(whitelistedBridges[_bridge], Rebalancer_BridgeNotWhitelisted());

        unchecked {
            ++nonce;
        }
        logs[_msg.dstChainId][nonce] = _msg;

        IBridge(_bridge).sendMsg(_msg.dstChainId, _msg.message, _msg.bridgeData);
        
        emit MsgSent(_bridge, _msg.dstChainId, _msg.message, _msg.bridgeData);
    }
}
