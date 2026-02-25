// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {DeploymentScriptBase} from "script/utils/DeploymentScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {Deployer} from "src/utils/Deployer.sol";

/// @title DeployTimelockController
/// @author Merge Layers Inc.
/// @notice Single deployment script that deploys TimelockController
contract DeployTimelockController is DeploymentScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice Config value for deployer
        address deployer;
        /// @notice Config value for minDelay
        uint256 minDelay;
        /// @notice Config value for proposers
        address[] proposers;
        /// @notice Config value for executors
        address[] executors;
        /// @notice Config value for admin
        address admin;
        /// @notice Config value for salt
        string salt;
    }

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when deployer is invalid
    error InvalidDeployer();
    /// @notice Error thrown when proposers is invalid
    error InvalidProposers();
    /// @notice Error thrown when executors is invalid
    error InvalidExecutors();
    /// @notice Error thrown when admin is invalid
    error InvalidAdmin();
    /// @notice Error thrown when salt is invalid
    error InvalidSalt();
    /// @notice Error thrown when timelock address is invalid
    error InvalidTimelockAddress();
    /// @notice Error thrown when min delay is invalid
    error InvalidMinDelay();

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @inheritdoc DeploymentScriptBase
    function _deployAndAssertResult(bytes memory deployConfig) internal override returns (address timelockAddress) {
        // Effects: decode validated runtime config
        DeployConfig memory cfg = abi.decode(deployConfig, (DeployConfig));

        Deployer deployer = Deployer(payable(cfg.deployer));

        // Interactions: precompute deterministic deployment address
        bytes32 salt = keccak256(bytes(cfg.salt));
        timelockAddress = deployer.precompute(salt);
        if (timelockAddress.code.length == 0) {
            bytes memory callData = abi.encodeWithSelector(
                deployer.create.selector,
                salt,
                abi.encodePacked(
                    type(TimelockController).creationCode,
                    abi.encode(cfg.minDelay, cfg.proposers, cfg.executors, cfg.admin)
                )
            );
            Logger.logCalldata("Deployer", cfg.deployer, "create", callData);

            // Interactions: broadcast exact logged calldata payload to deployer
            vm.broadcast();
            (bool success, bytes memory returnData) = cfg.deployer.call(callData);

            // Requirements: external call should succeed.
            if (!success) {
                assembly {
                    revert(add(returnData, 0x20), mload(returnData))
                }
            }

            timelockAddress = abi.decode(returnData, (address));
        }

        // Requirements: timelockAddress should not be the zero address; timelockAddress code length should be greater than zero.
        require(timelockAddress != address(0), InvalidTimelockAddress());
        require(timelockAddress.code.length > 0, InvalidTimelockAddress());

        // Requirements: getMinDelay should equal cfg.minDelay; cfg.admin should have the required role.
        TimelockController timelock = TimelockController(payable(timelockAddress));
        require(timelock.getMinDelay() == cfg.minDelay, InvalidMinDelay());
        require(timelock.hasRole(0x00, cfg.admin), InvalidAdmin());
    }

    /// @inheritdoc ScriptBase
    function _serializeConfig(bytes memory config, string memory namespace_)
        internal
        override
        returns (string memory serialized)
    {
        // Effects: decode validated config for output serialization
        DeployConfig memory cfg = abi.decode(config, (DeployConfig));

        // Effects: write resolved config values under script namespace
        string memory json = namespace_;
        vm.serializeAddress(json, "deployer", cfg.deployer);
        vm.serializeUint(json, "minDelay", cfg.minDelay);
        vm.serializeUint(json, "proposersCount", cfg.proposers.length);
        vm.serializeUint(json, "executorsCount", cfg.executors.length);
        vm.serializeAddress(json, "admin", cfg.admin);
        serialized = vm.serializeString(json, "salt", cfg.salt);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load input config JSON from selected path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        // Effects: read runtime config fields
        cfg.deployer = _readAndLogAddress(json, "deployer");
        cfg.minDelay = _readAndLogUint(json, "minDelay");
        cfg.proposers = _readAndLogAddressArray(json, "proposers");
        cfg.executors = _readAndLogAddressArray(json, "executors");
        cfg.admin = _readAndLogAddress(json, "admin");
        cfg.salt = _readAndLogString(json, "salt");

        // Requirement: all conditions must be satisfied
        require(cfg.deployer != address(0), InvalidDeployer());
        require(cfg.proposers.length > 0, InvalidProposers());
        require(cfg.executors.length > 0, InvalidExecutors());
        require(cfg.admin != address(0), InvalidAdmin());
        require(bytes(cfg.salt).length > 0, InvalidSalt());

        // Effects: return encoded config for base runner
        deployConfig = abi.encode(cfg);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "TimelockController";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployTimelockController.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployTimelockController.output.json";
    }
}
