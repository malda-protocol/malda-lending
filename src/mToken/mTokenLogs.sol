// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

// interfaces
import {IRoles} from "src/interfaces/IRoles.sol";
import {ImTokenLogs} from "src/interfaces/ImTokenLogs.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

contract mTokenLogs is ImTokenLogs, ImTokenOperationTypes {
    // ----------- STORAGE ------------
    IRoles public roles;
    // user -> chainId -> opType -> nonce -> data
    mapping(address => mapping(uint256 => mapping(OperationType => mapping(uint256 => LogData)))) public journals;

    constructor(address _roles) {
        require(_roles != address(0), mTokenLogs_AddressNotValid());
        roles = IRoles(_roles);
    }

    // ----------- VIEW ------------
    /**
     * @inheritdoc ImTokenLogs
     */
    function getLog(address user, OperationType opType, uint256 nonce)
        external
        view
        override
        returns (uint256 chainId, bytes memory)
    {
        LogData memory journal = journals[user][block.chainid][opType][nonce];
        return (journal.chainId, journal.data);
    }

    /**
     * @inheritdoc ImTokenLogs
     */
    function getLogForChain(address user, OperationType opType, uint256 nonce, uint256 chainId)
        external
        view
        override
        returns (uint256, bytes memory)
    {
        LogData memory journal = journals[user][chainId][opType][nonce];
        return (journal.chainId, journal.data);
    }

    // ----------- PUBLIC ------------
    /**
     * @inheritdoc ImTokenLogs
     */
    function registerLog(
        address user,
        OperationType opType,
        uint256 srcChainId,
        uint256 dstChainId,
        uint256 nonce,
        bytes memory data
    ) external {
        // only allowed role
        require(roles.isAllowedFor(msg.sender, roles.LOGS_ADD()), mTokenLogs_NotAllowed());
        journals[user][srcChainId][opType][nonce] = LogData(dstChainId, data);

        emit JournalRegistered(user, opType, nonce, srcChainId, dstChainId);
    }
}
