// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

interface IRebalancer {
    // ----------- STORAGE ------------
    struct Msg {
        uint256 dstChainId;
        bytes message;
        bytes bridgeData;
    }
    // ----------- EVENTS ------------

    event BridgeWhitelistedStatusUpdated(address indexed bridge, bool status);
    event MsgSent(address indexed bridge, uint256 indexed dstChainId, bytes message, bytes bridgeData);

    // ----------- ERRORS ------------
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
     * @param msg the message data
     */
    function sendMsg(address bridge, Msg calldata msg) external;
}
