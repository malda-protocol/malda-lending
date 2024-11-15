// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

import {ImTokenOperationTypes} from "./ImToken.sol";

interface IPauser is ImTokenOperationTypes {
    enum PausableType {
        Host,
        Extension
    }

    struct PausableContract {
        address market;
        PausableType contractType;
    }

    error Pauser_EntryNotFound();
    error Pauser_NotAuthorized();
    error Pauser_AddressNotValid();
    error Pauser_AlreadyRegistered();

    event PauseAll();
    event MarketPaused(address indexed market);
    event MarketRemoved(address indexed market);
    event MarketAdded(address indexed market, PausableType marketType);
    event MarketPausedFor(address indexed market, OperationType pauseType);

    /**
     * @notice pauses all operations for a market
     * @param _market the mToken address
     */
    function emergencyPauseMarket(address _market) external;

    /**
     * @notice pauses a specific operation for a market
     * @param _market the mToken address
     * @param _pauseType the operation type
     */
    function emergencyPauseMarketForOperation(address _market, OperationType _pauseType) external;

    /**
     * @notice pauses all operations for all registered markets
     */
    function emergencyPauseAll() external;
}
