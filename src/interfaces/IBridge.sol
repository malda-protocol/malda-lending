// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

interface IBridge {
    /**
     * @notice computes fee for bridge operation
     * @param _dstChainId destination chain id
     * @param _message operation message data
     * @param _bridgeData specific bridge data
     */
    function getFee(uint256 _dstChainId, bytes memory _message, bytes memory _bridgeData)
        external
        view
        returns (uint256);

    /**
     * @notice rebalance through bridge
     * @param _dstChainId destination chain id
     * @param _message operation message data
     * @param _bridgeData specific bridge data
     */
    function sendMsg(uint256 _dstChainId, bytes memory _message, bytes memory _bridgeData) external payable;
}
