// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

interface IRebalanceMarket {
    function extractForRebalancing(uint256 amount) external;
}

interface IRebalancer {
    // ----------- STORAGE ------------
    struct Msg {
        uint32 dstChainId;
        address token;
        bytes message;
        bytes bridgeData;
    }
    // ----------- EVENTS ------------

    event BridgeWhitelistedStatusUpdated(address indexed bridge, bool status);
    event MsgSent(
        address indexed bridge, uint256 indexed dstChainId, address indexed token, bytes message, bytes bridgeData
    );
    event EthSaved(uint256 amount);

    // ----------- ERRORS ------------
    error Rebalancer_NotAuthorized();
    error Rebalancer_MarketNotValid();
    error Rebalancer_RequestNotValid();
    error Rebalancer_AddressNotValid();
    error Rebalancer_BridgeNotWhitelisted();

    // ----------- VIEW METHODS ------------
    /**
     * @notice returns current nonce
     */
    function nonce() external view returns (uint256);

    /**
     * @notice returns if a bridge implementation is whitelisted
     */
    function isBridgeWhitelisted(address bridge) external view returns (bool);

    // ----------- EXTERNAL METHODS ------------
    /**
     * @notice sends a bridge message
     * @param bridge the whitelisted bridge address
     * @param _market the market to rebalance from address
     * @param _amount the amount to rebalance
     * @param msg the message data
     */
    function sendMsg(address bridge, address _market, uint256 _amount, Msg calldata msg) external payable;
}
