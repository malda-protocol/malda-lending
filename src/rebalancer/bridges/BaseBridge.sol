// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

import {IRoles} from "src/interfaces/IRoles.sol";

abstract contract BaseBridge {
    // ----------- STORAGE ------------
    IRoles public roles;
    uint256 public minTransfer;
    uint256 public maxTransfer;

    error BaseBridge_NotAuthorized();
    error BaseBridge_AmountNotValid();

    event MinTransferSizeUpdated(uint256 _old, uint256 _new);
    event MaxTransferSizeUpdated(uint256 _old, uint256 _new);

    constructor(address _roles) {
        roles = IRoles(_roles);
        minTransfer = 50_000 * 1e18;
    }

    modifier onlyBridgeConfigurator() {
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert BaseBridge_NotAuthorized();
        _;
    }

    modifier onlyRebalancer() {
        if (!roles.isAllowedFor(msg.sender, roles.REBALANCER())) revert BaseBridge_NotAuthorized();
        _;
    }

    // ----------- OWNER ------------
    /**
     * @notice Set the minimum transfer size
     * @param _newMin the new value
     */
    function setMinTransferSize(uint256 _newMin) external onlyBridgeConfigurator {
        if (_newMin >= maxTransfer) revert BaseBridge_AmountNotValid();
        minTransfer = _newMin;
        emit MinTransferSizeUpdated(minTransfer, _newMin);
    }

    /**
     * @notice Set the minimum transfer size
     * @param _newMax the new value
     */
    function setMaxTransferSize(uint256 _newMax) external onlyBridgeConfigurator {
        if (_newMax <= minTransfer) revert BaseBridge_AmountNotValid();
        maxTransfer = _newMax;
        emit MaxTransferSizeUpdated(maxTransfer, _newMax);
    }
}
