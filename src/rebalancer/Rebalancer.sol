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
import {IOperator} from "src/interfaces/IOperator.sol";
import {ImTokenMinimal, ImToken} from "src/interfaces/ImToken.sol";
import {IRebalancer, IRebalanceMarket} from "src/interfaces/IRebalancer.sol";

import {SafeApprove} from "src/libraries/SafeApprove.sol";

contract Rebalancer is IRebalancer {
    // ----------- STORAGE ------------
    IRoles public roles;
    uint256 public nonce;
    mapping(uint32 => mapping(uint256 => Msg)) public logs;
    mapping(address => bool) public whitelistedBridges;

    address public saveAddress;

    constructor(address _roles, address _saveAddress) {
        roles = IRoles(_roles);
        saveAddress = _saveAddress;
    }

    // ----------- OWNER METHODS ------------
    function setWhitelistedBridgeStatus(address _bridge, bool _status) external {
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert Rebalancer_NotAuthorized();
        require(_bridge != address(0), Rebalancer_AddressNotValid());
        whitelistedBridges[_bridge] = _status;
        emit BridgeWhitelistedStatusUpdated(_bridge, _status);
    }

    function saveEth() external {
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert Rebalancer_NotAuthorized();

        uint256 amount = address(this).balance;
        // no need to check return value
        saveAddress.call{value: amount}("");
        emit EthSaved(amount);
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
        if (!roles.isAllowedFor(msg.sender, roles.REBALANCER_EOA())) revert Rebalancer_NotAuthorized();
        require(whitelistedBridges[_bridge], Rebalancer_BridgeNotWhitelisted());
        address _underlying = ImTokenMinimal(_market).underlying();
        require(_underlying == _msg.token, Rebalancer_RequestNotValid());

        // retrieve amounts (make sure to check min and max for that bridge)
        address operator = ImToken(_market).operator();
        bool isListed = IOperator(operator).isMarketListed(_market);
        require (isListed, Rebalancer_MarketNotValid());
        IRebalanceMarket(_market).extractForRebalancing(_amount);

        unchecked {
            ++nonce;
        }
        logs[_msg.dstChainId][nonce] = _msg;

        SafeApprove.safeApprove(_msg.token, _bridge, _amount);
        IBridge(_bridge).sendMsg{value: msg.value}(_msg.dstChainId, _msg.token, _msg.message, _msg.bridgeData);

        emit MsgSent(_bridge, _msg.dstChainId, _msg.token, _msg.message, _msg.bridgeData);
    }
}
