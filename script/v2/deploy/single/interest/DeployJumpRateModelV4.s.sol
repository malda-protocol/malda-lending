// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {DeploymentScriptBase} from "script/utils/DeploymentScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {JumpRateModelV4} from "src/interest/JumpRateModelV4.sol";
import {Deployer} from "src/utils/Deployer.sol";

/// @title DeployJumpRateModelV4
/// @author Merge Layers Inc.
/// @notice Single deployment script that deploys JumpRateModelV4
contract DeployJumpRateModelV4 is DeploymentScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice Config value for deployer
        address deployer;
        /// @notice Config value for kink
        uint256 kink;
        /// @notice Config value for name
        string name;
        /// @notice Config value for blocksPerYear
        uint256 blocksPerYear;
        /// @notice Config value for baseRatePerYear
        uint256 baseRatePerYear;
        /// @notice Config value for multiplierPerYear
        uint256 multiplierPerYear;
        /// @notice Config value for jumpMultiplierPerYear
        uint256 jumpMultiplierPerYear;
        /// @notice Config value for owner
        address owner;
        /// @notice Config value for salt
        string salt;
    }

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when deployer is invalid
    error InvalidDeployer();
    /// @notice Error thrown when kink is invalid
    error InvalidKink();
    /// @notice Error thrown when name is invalid
    error InvalidName();
    /// @notice Error thrown when blocks per year is invalid
    error InvalidBlocksPerYear();
    /// @notice Error thrown when multiplier per year is invalid
    error InvalidMultiplierPerYear();
    /// @notice Error thrown when jump multiplier per year is invalid
    error InvalidJumpMultiplierPerYear();
    /// @notice Error thrown when owner is invalid
    error InvalidOwner();
    /// @notice Error thrown when salt is invalid
    error InvalidSalt();
    /// @notice Error thrown when jump rate model address is invalid
    error InvalidJumpRateModelAddress();

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @inheritdoc DeploymentScriptBase
    function _deployAndAssertResult(bytes memory deployConfig)
        internal
        override
        returns (address jumpRateModelAddress)
    {
        // Effects: decode validated runtime config
        DeployConfig memory cfg = abi.decode(deployConfig, (DeployConfig));

        Deployer deployer = Deployer(payable(cfg.deployer));

        // Interactions: precompute deterministic deployment address
        bytes32 salt = keccak256(bytes(cfg.salt));
        jumpRateModelAddress = deployer.precompute(salt);
        if (jumpRateModelAddress.code.length == 0) {
            bytes memory callData = abi.encodeWithSelector(
                deployer.create.selector,
                salt,
                abi.encodePacked(
                    type(JumpRateModelV4).creationCode,
                    abi.encode(
                        cfg.blocksPerYear,
                        cfg.baseRatePerYear,
                        cfg.multiplierPerYear,
                        cfg.jumpMultiplierPerYear,
                        cfg.kink,
                        cfg.owner,
                        cfg.name
                    )
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

            jumpRateModelAddress = abi.decode(returnData, (address));
        }

        // Requirements: jumpRateModelAddress should not be the zero address; jumpRateModelAddress code length should be greater
        // than zero.
        require(jumpRateModelAddress != address(0), InvalidJumpRateModelAddress());
        require(jumpRateModelAddress.code.length > 0, InvalidJumpRateModelAddress());

        JumpRateModelV4 jumpRateModel = JumpRateModelV4(jumpRateModelAddress);
        // Requirements: owner should equal cfg.owner; name should equal cfg.name; blocksPerYear should equal cfg.blocksPerYear.
        require(jumpRateModel.owner() == cfg.owner, InvalidOwner());
        require(keccak256(bytes(jumpRateModel.name())) == keccak256(bytes(cfg.name)), InvalidName());
        require(jumpRateModel.blocksPerYear() == cfg.blocksPerYear, InvalidBlocksPerYear());
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
        vm.serializeUint(json, "kink", cfg.kink);
        vm.serializeString(json, "name", cfg.name);
        vm.serializeUint(json, "blocksPerYear", cfg.blocksPerYear);
        vm.serializeUint(json, "baseRatePerYear", cfg.baseRatePerYear);
        vm.serializeUint(json, "multiplierPerYear", cfg.multiplierPerYear);
        vm.serializeUint(json, "jumpMultiplierPerYear", cfg.jumpMultiplierPerYear);
        vm.serializeAddress(json, "owner", cfg.owner);
        serialized = vm.serializeString(json, "salt", cfg.salt);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load input config JSON from selected path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        // Effects: read runtime config fields
        cfg.deployer = _readAndLogAddress(json, "deployer");
        cfg.kink = _readAndLogUint(json, "kink");
        cfg.name = _readAndLogString(json, "name");
        cfg.blocksPerYear = _readAndLogUint(json, "blocksPerYear");
        cfg.baseRatePerYear = _readAndLogUint(json, "baseRatePerYear");
        cfg.multiplierPerYear = _readAndLogUint(json, "multiplierPerYear");
        cfg.jumpMultiplierPerYear = _readAndLogUint(json, "jumpMultiplierPerYear");
        cfg.owner = _readAndLogAddress(json, "owner");
        cfg.salt = _readAndLogString(json, "salt");

        // Requirement: all conditions must be satisfied
        require(cfg.deployer != address(0), InvalidDeployer());
        require(cfg.kink > 0, InvalidKink());
        require(bytes(cfg.name).length > 0, InvalidName());
        require(cfg.blocksPerYear > 0, InvalidBlocksPerYear());
        require(cfg.multiplierPerYear > 0, InvalidMultiplierPerYear());
        require(cfg.jumpMultiplierPerYear > 0, InvalidJumpMultiplierPerYear());
        require(cfg.owner != address(0), InvalidOwner());
        require(bytes(cfg.salt).length > 0, InvalidSalt());

        // Effects: return encoded config for base runner
        deployConfig = abi.encode(cfg);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "JumpRateModelV4";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployJumpRateModelV4.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployJumpRateModelV4.output.json";
    }
}
