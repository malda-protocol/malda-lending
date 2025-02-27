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
import {ImTokenMinimal} from "src/interfaces/ImToken.sol";
import {IRebalancer, IRebalanceMarket} from "src/interfaces/IRebalancer.sol";

import {SafeApprove} from "src/libraries/SafeApprove.sol";

contract Rebalancer is IRebalancer {
    // ----------- STORAGE ------------
    IRoles public roles;
    uint256 public nonce;
    mapping(uint32 => mapping(uint256 => Msg)) public logs;
    mapping(address => bool) public whitelistedBridges;

    struct TransferInfo {
        uint256 size;
        uint256 timestamp;
    }
    mapping(uint32 => mapping(address => uint256)) public maxTransferSizes;
    mapping(uint32 => mapping(address => uint256)) public minTransferSizes;
    mapping(uint32 => mapping(address => TransferInfo)) public currentTransferSize;
    uint256 public transferTimeWindow;

    constructor(address _roles) {
        roles = IRoles(_roles);
        transferTimeWindow = 86400;
    }

    // ----------- OWNER METHODS ------------
    function setWhitelistedBridgeStatus(address _bridge, bool _status) external {
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert Rebalancer_NotAuthorized();
        require(_bridge != address(0), Rebalancer_AddressNotValid());
        whitelistedBridges[_bridge] = _status;
        emit BridgeWhitelistedStatusUpdated(_bridge, _status);
    }

     function setMinTransferSize(uint32 _dstChainId, address _token, uint256 _limit) external {
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert Rebalancer_NotAuthorized();
        minTransferSizes[_dstChainId][_token] = _limit;
        emit MinTransferSizeUpdated(_dstChainId, _token, _limit);
    }

    function setMaxTransferSize(uint32 _dstChainId, address _token, uint256 _limit) external {
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert Rebalancer_NotAuthorized();
        maxTransferSizes[_dstChainId][_token] = _limit;
        emit MaxTransferSizeUpdated(_dstChainId, _token, _limit);
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
    function sendMsg(address _bridge, address _market, uint256 _amount, Msg calldata _msg) external payable {
        // param checks
        if (!roles.isAllowedFor(msg.sender, roles.REBALANCER_EOA())) revert Rebalancer_NotAuthorized();
        require(whitelistedBridges[_bridge], Rebalancer_BridgeNotWhitelisted());
        address _underlying = ImTokenMinimal(_market).underlying();
        require(_underlying == _msg.token, Rebalancer_RequestNotValid());

        // min transfer size check
        require(_amount > minTransferSizes[_msg.dstChainId][_msg.token], Rebalancer_TransferSizeMinNotMet()); 

        // max transfer size checks
        TransferInfo memory transferInfo = currentTransferSize[_msg.dstChainId][_msg.token];
        uint256 transferSizeDeadline = transferInfo.timestamp + transferTimeWindow;
        if (transferSizeDeadline < block.timestamp) {
            currentTransferSize[_msg.dstChainId][_msg.token] = TransferInfo(_amount, block.timestamp);
        } else {
            currentTransferSize[_msg.dstChainId][_msg.token].size += _amount;
        }
        require(transferInfo.size + _amount < maxTransferSizes[_msg.dstChainId][_msg.token], Rebalancer_TransferSizeExcedeed()); 

        // retrieve amounts (make sure to check min and max for that bridge)
        IRebalanceMarket(_market).extractForRebalancing(_amount);

        // log
        unchecked {
            ++nonce;
        }
        logs[_msg.dstChainId][nonce] = _msg;

        // approve and trigger send
        SafeApprove.safeApprove(_msg.token, _bridge, _amount);
        IBridge(_bridge).sendMsg{value: msg.value}(_msg.dstChainId, _msg.token, _msg.message, _msg.bridgeData);

        emit MsgSent(_bridge, _msg.dstChainId, _msg.token, _msg.message, _msg.bridgeData);
    }
}
