// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|                          
*/

import {ImTokenOperationTypes} from "./ImToken.sol";

interface ImTokenLogs {
    // ----------- STRUCTS -----------

    struct LogData {
        uint256 chainId;
        bytes data;
    }

    event JournalRegistered(
        address indexed user,
        ImTokenOperationTypes.OperationType opType,
        uint256 nonce,
        uint256 srcChainId,
        uint256 dstChainId
    );

    error mTokenLogs_NotAllowed();
    error mTokenLogs_AddressNotValid();

    // ----------- VIEW -----------
    /**
     * @notice returns registered journal for a specific chain
     * @param user the account address
     * @param opType the operation type
     * @param nonce the nonce value
     */
    function getLog(address user, ImTokenOperationTypes.OperationType opType, uint256 nonce)
        external
        view
        returns (uint256 dstChainId, bytes memory);

    /**
     * @notice returns registered journal for a specific chain
     * @param user the account address
     * @param opType the operation type
     * @param nonce the nonce value
     * @param chainId the source chain id type
     */
    function getLogForChain(address user, ImTokenOperationTypes.OperationType opType, uint256 nonce, uint256 chainId)
        external
        view
        returns (uint256 dstChainId, bytes memory);

    // ----------- PUBLIC -----------
    /**
     * @notice registers a journal data
     * @param user the account address
     * @param opType the operation type
     * @param srcChainId the source chain id type
     * @param dstChainId the destination chain id type
     * @param nonce the nonce value
     * @param data the encoded journal data
     */
    function registerLog(
        address user,
        ImTokenOperationTypes.OperationType opType,
        uint256 srcChainId,
        uint256 dstChainId,
        uint256 nonce,
        bytes memory data
    ) external;
}
