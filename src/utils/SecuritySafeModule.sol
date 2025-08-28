// Copyright (c) 2025 Merge Layers Inc.
//
// This source code is licensed under the Business Source License 1.1
// (the "License"); you may not use this file except in compliance with the
// License. You may obtain a copy of the License at
//
//     https://github.com/malda-protocol/malda-lending/blob/main/LICENSE-BSL
//
// See the License for the specific language governing permissions and
// limitations under the License.
//
// This file contains code derived from or inspired by Compound V2,
// originally licensed under the BSD 3-Clause License. See LICENSE-COMPOUND-V2
// for original license terms and attributions.

// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

import {IPauser} from "src/interfaces/IPauser.sol";
import {IBlacklister} from "src/interfaces/IBlacklister.sol";
import {IOperator} from "src/interfaces/IOperator.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";
import {ImErc20Host} from "src/interfaces/ImErc20Host.sol";

enum Operation {
    Call,
    DelegateCall
}

interface ISafeExecutor {
    /**
     * @notice Execute `operation` (0: Call, 1: DelegateCall) to `to` with `value` (Native Token)
     * @param to Destination address of module transaction.
     * @param value Ether value of module transaction.
     * @param data Data payload of module transaction.
     * @param operation Operation type of module transaction.
     * @return success Boolean flag indicating if the call succeeded.
     */
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes memory data,
        Operation operation
    ) external returns (bool success);
}

contract SecuritySafeModule {
    // ----------- STORAGE ------------
    address public guardian;
    address public pauserContract;
    address public blacklisterContract;
    address public operatorContract;

    uint256 public constant LOWER_BY = 5000; //5%
    uint256 public constant MATH_PRECISION = 1e5;


    // ----------- ERRORS ------------
    error SecuritySafeModule_NotAuthorized();
    error SecuritySafeModule_AddressNotValid();
    error SecuritySafeModule_BlacklistFailed();
    error SecuritySafeModule_WhitelistFailed();
    error SecuritySafeModule_PauseFailed();
    error SecuritySafeModule_CapFailed();

    /**
     * @notice Deploy the SecuritySafeModule contract
     * @param _guardian The address of the guardian, who has exclusive access to emergency operations
     * @param _pauser The address of the Pauser contract
     * @param _blacklister The address of the Blacklister contracy
     * @param _operator The address of the Operator contract
     */
    constructor(address _guardian, address _pauser, address _blacklister, address _operator) {
        require(_guardian != address(0), SecuritySafeModule_AddressNotValid());
        require(_pauser != address(0), SecuritySafeModule_AddressNotValid());
        require(_blacklister != address(0), SecuritySafeModule_AddressNotValid());
        require(_operator != address(0), SecuritySafeModule_AddressNotValid());
        guardian = _guardian;
        pauserContract = _pauser;
        blacklisterContract = _blacklister;
        operatorContract = _operator;
    }

    /**
     * @dev Restricts function access to the guardian only
     */
    modifier onlyGuardian() {
        require(msg.sender == guardian, SecuritySafeModule_NotAuthorized());
        _;
    }

    // ----------- PAUSE OPERATIONS ------------
    /**
     * @notice Pause a specific market in case of emergency
     * @param safe The Gnosis Safe instance used for execution
     * @param market The address of the market to be paused
     */
    function executePauseForMarket(ISafeExecutor safe, address market) public onlyGuardian {
        bytes memory data =  abi.encodeWithSelector(IPauser.emergencyPauseMarket.selector, market);
        require(safe.execTransactionFromModule(pauserContract, 0, data, Operation.Call), SecuritySafeModule_PauseFailed());
    }

    /**
    * @notice Pause all markets globally in case of emergency
    * @param safe The Gnosis Safe instance used for execution
    */
    function executePauseAll(ISafeExecutor safe) public onlyGuardian {
        bytes memory data =  abi.encodeWithSelector(IPauser.emergencyPauseAll.selector);
        require(safe.execTransactionFromModule(pauserContract, 0, data, Operation.Call), SecuritySafeModule_PauseFailed());
    }

    /**
    * @notice Pause a specific type of operation on a market
    * @param safe The Gnosis Safe instance used for execution
    * @param market The address of the market to pause
    * @param pauseType The type of operation to pause
    */
    function executePauseOperation(ISafeExecutor safe, address market, IPauser.OperationType pauseType) public onlyGuardian {
        bytes memory data =  abi.encodeWithSelector(IPauser.emergencyPauseMarketFor.selector, market, pauseType);
        require(safe.execTransactionFromModule(pauserContract, 0, data, Operation.Call), SecuritySafeModule_PauseFailed());
    }

    /**
     * @notice Pause a specific type of operation across multiple markets
     * @param safe The Gnosis Safe instance used for execution.
     * @param markets The addresses of the markets to pause
     * @param pauseType The type of operation to pause
     */
    function executePauseOperation(ISafeExecutor safe, address[] memory markets, IPauser.OperationType pauseType) public onlyGuardian {
        uint256 length = markets.length;
        bytes memory data;
        for (uint256 i; i < length; ++i) {
            data =  abi.encodeWithSelector(IPauser.emergencyPauseMarketFor.selector, markets[i], pauseType);
            require(safe.execTransactionFromModule(pauserContract, 0, data, Operation.Call), SecuritySafeModule_PauseFailed());
        }
    }

    /**
     * @notice Pause multiple operation types for a specific market
     * @param safe The Gnosis Safe instance used for execution
     * @param market The address of the market to pause
     * @param pauseTypes The list of operation types to pause
     */
    function executePauseOperation(ISafeExecutor safe, address market, ImTokenOperationTypes.OperationType[] memory pauseTypes) public onlyGuardian {
        uint256 length = pauseTypes.length;
        bytes memory data;
        for (uint256 i; i < length; ++i) {
            data =  abi.encodeWithSelector(IPauser.emergencyPauseMarketFor.selector, market, pauseTypes[i]);
            require(safe.execTransactionFromModule(pauserContract, 0, data, Operation.Call), SecuritySafeModule_PauseFailed());
        }
    }

    // ----------- BLACKLIST OPERATIONS ------------
    /**
     * @notice Blacklist a specific address
     * @param safe The Gnosis Safe instance used for execution
     * @param toBlacklist The address to be blacklisted
     */
    function executeBlacklist(ISafeExecutor safe, address toBlacklist) public onlyGuardian {
        bytes memory data =  abi.encodeWithSelector(IBlacklister.blacklist.selector, toBlacklist);
        require(safe.execTransactionFromModule(blacklisterContract, 0, data, Operation.Call), SecuritySafeModule_BlacklistFailed());
    }

    /**
     * @notice Blacklist multiple addresses in batch
     * @param safe The Gnosis Safe instance used for execution
     * @param list The list of addresses to be blacklisted
     */
    function executeBlacklist(ISafeExecutor safe, address[] memory list) public onlyGuardian {
        uint256 length = list.length;
        bytes memory data;
        for (uint256 i; i < length; ++i) {
            data =  abi.encodeWithSelector(IBlacklister.blacklist.selector, list[i]);
            require(safe.execTransactionFromModule(blacklisterContract, 0, data, Operation.Call), SecuritySafeModule_BlacklistFailed());
        }
    }

    // ----------- MARKET OPERATIONS ------------
    /**
     * @notice Reduce borrow caps by 5% for the given markets
     * @param safe The Gnosis Safe instance used for execution
     * @param markets The addresses of the markets whose borrow caps will be reduced
    */
    function lowerBorrowCap(ISafeExecutor safe, address[] memory markets) public onlyGuardian {
        uint256 len = markets.length;
        uint256[] memory newCaps = new uint256[](len);

        for (uint256 i; i < len; ++i) {
            uint256 crtCap = IOperator(operatorContract).borrowCaps(markets[i]);
            uint256 loweredCap = crtCap - crtCap * LOWER_BY / MATH_PRECISION;
            newCaps[i] = loweredCap;
        }

        bytes memory data =  abi.encodeWithSelector(IOperator.setMarketBorrowCaps.selector, markets, newCaps);
        require(safe.execTransactionFromModule(operatorContract, 0, data, Operation.Call), SecuritySafeModule_CapFailed());
    }

    /**
     * @notice Reduce supply caps by 5% for the given markets
     * @param safe The Gnosis Safe instance used for execution
     * @param markets The addresses of the markets whose supply caps will be reduced
     */
    function lowerSupplyCap(ISafeExecutor safe, address[] memory markets) public onlyGuardian {
        uint256 len = markets.length;
        uint256[] memory newCaps = new uint256[](len);

        for (uint256 i; i < len; ++i) {
            uint256 crtCap = IOperator(operatorContract).supplyCaps(markets[i]);
            uint256 loweredCap = crtCap - crtCap * LOWER_BY / MATH_PRECISION;
            newCaps[i] = loweredCap;
        }

        bytes memory data =  abi.encodeWithSelector(IOperator.setMarketSupplyCaps.selector, markets, newCaps);
        require(safe.execTransactionFromModule(operatorContract, 0, data, Operation.Call), SecuritySafeModule_CapFailed());
    }

    /**
     * @notice Removes an extension chain from whitelist from a specific market
     * @param safe The Gnosis Safe instance used for execution.
     * @param market The address of the market to remove chain from
     * @param chainId The chain id to remove from whitelist
     */
    function removeExtensionChainWhitelist(ISafeExecutor safe, address market, uint32 chainId) public onlyGuardian() {
        bytes memory data =  abi.encodeWithSelector(ImErc20Host.updateAllowedChain.selector, chainId, false);
        require(safe.execTransactionFromModule(market, 0, data, Operation.Call), SecuritySafeModule_WhitelistFailed());
    }

    /**
     * @notice Removes an extension chain from whitelist for all markets
     * @param safe The Gnosis Safe instance used for execution.
     * @param markets The addresses of the markets to remove chain from
     * @param chainId The chain id to remove from whitelist
     */
    function batchRemoveExtensionChainWhitelist(ISafeExecutor safe, address[] memory markets, uint32 chainId) public onlyGuardian() {
        uint256 len = markets.length;
        bytes memory data;
        for (uint256 i; i < len; ++i) {
            data =  abi.encodeWithSelector(ImErc20Host.updateAllowedChain.selector, chainId, false);
            require(safe.execTransactionFromModule(markets[i], 0, data, Operation.Call), SecuritySafeModule_WhitelistFailed());
        }
    }
}