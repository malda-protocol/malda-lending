// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {DeploymentScriptBase} from "script/utils/DeploymentScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {Operator} from "src/Operator/Operator.sol";
import {Deployer} from "src/utils/Deployer.sol";

/// @title DeployOperator
/// @author Merge Layers Inc.
/// @notice Single deployment script that deploys Operator
contract DeployOperator is DeploymentScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice The address of the Deployer.sol contract
        address deployer;
        /// @notice The address of the BlacklistOperator.sol contract
        address blacklistOperator;
        /// @notice The address of the Oracle.sol contract
        address oracle;
        /// @notice The address of the RewardDistributor.sol contract
        address rewardDistributor;
        /// @notice The address of the Roles.sol contract
        address roles;
        /// @notice The address of the owner of the contract
        address owner;
        /// @notice The salt for the implementation contract
        string implementationSalt;
        /// @notice The salt for the proxy contract
        string proxySalt;
    }

    ////////////////////////////////////////////////////////////
    //                        Storage                         //
    ////////////////////////////////////////////////////////////

    /// @notice Tracks whether the current run deployed a new proxy (used by post-deploy parity logic)
    bool private _isFreshProxyDeployment;

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when the deployer address is invalid
    error InvalidDeployer();
    /// @notice Error thrown when the blacklist operator address is invalid
    error InvalidBlacklistOperator();
    /// @notice Error thrown when the oracle address is invalid
    error InvalidOracle();
    /// @notice Error thrown when the roles address is invalid
    error InvalidRoles();
    /// @notice Error thrown when the owner address is invalid
    error InvalidOwner();
    /// @notice Error thrown when the implementation salt is invalid
    error InvalidImplementationSalt();
    /// @notice Error thrown when the proxy salt is invalid
    error InvalidProxySalt();
    /// @notice Error thrown when the proxy address is invalid
    error InvalidProxyAddress();

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @inheritdoc DeploymentScriptBase
    function _deployAndAssertResult(bytes memory deployConfig) internal override returns (address operatorAddress) {
        // Effects: decode validated runtime config
        DeployConfig memory cfg = abi.decode(deployConfig, (DeployConfig));

        // Effects: bind configured create3 deployer
        Deployer deployer = Deployer(payable(cfg.deployer));
        bytes32 implementationSalt = keccak256(bytes(cfg.implementationSalt));
        bytes32 proxySalt = keccak256(bytes(cfg.proxySalt));

        // Interactions: precompute implementation address
        address implementation = deployer.precompute(implementationSalt);
        if (implementation.code.length == 0) {
            // Interactions: deploy implementation if absent
            bytes memory callData = abi.encodeWithSelector(
                deployer.create.selector, implementationSalt, abi.encodePacked(type(Operator).creationCode)
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

            implementation = abi.decode(returnData, (address));
        }

        // Interactions: precompute proxy address
        operatorAddress = deployer.precompute(proxySalt);

        // Effects: branch for first deploy vs rerun
        bool isFreshProxy = operatorAddress.code.length == 0;
        _isFreshProxyDeployment = isFreshProxy;
        if (isFreshProxy) {
            bytes memory callData = abi.encodeWithSelector(
                deployer.create.selector,
                proxySalt,
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(
                        implementation,
                        cfg.owner,
                        abi.encodeWithSelector(
                            Operator.initialize.selector, cfg.roles, cfg.blacklistOperator, cfg.owner
                        )
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

            operatorAddress = abi.decode(returnData, (address));
        }

        // Requirements: operatorAddress should not be the zero address; operatorAddress code length should be greater than zero;
        // owner should equal cfg.owner.
        require(operatorAddress != address(0), InvalidProxyAddress());
        require(operatorAddress.code.length > 0, InvalidProxyAddress());
        require(Operator(operatorAddress).owner() == cfg.owner, InvalidOwner());

        return operatorAddress;
    }

    /// @inheritdoc DeploymentScriptBase
    function _postDeploymentConfiguration(bytes memory deployConfig, address operatorAddress) internal override {
        DeployConfig memory cfg = abi.decode(deployConfig, (DeployConfig));

        if (!_isFreshProxyDeployment) return;

        // Interactions: set oracle only on first proxy deployment
        vm.broadcast();
        Operator(operatorAddress).setPriceOracle(cfg.oracle);

        // Requirement: oracleOperator should equal cfg.oracle.
        require(Operator(operatorAddress).oracleOperator() == cfg.oracle, InvalidOracle());
    }

    /// @inheritdoc ScriptBase
    function _serializeConfig(bytes memory config, string memory namespace_)
        internal
        override
        returns (string memory serialized)
    {
        // Effects: decode final config for output serialization
        DeployConfig memory cfg = abi.decode(config, (DeployConfig));

        // Effects: serialize final resolved config under script namespace
        string memory json = namespace_;
        vm.serializeAddress(json, "deployer", cfg.deployer);
        vm.serializeAddress(json, "blacklistOperator", cfg.blacklistOperator);
        vm.serializeAddress(json, "oracle", cfg.oracle);
        vm.serializeAddress(json, "rewardDistributor", cfg.rewardDistributor);
        vm.serializeAddress(json, "roles", cfg.roles);
        vm.serializeAddress(json, "owner", cfg.owner);
        vm.serializeString(json, "implementationSalt", cfg.implementationSalt);
        serialized = vm.serializeString(json, "proxySalt", cfg.proxySalt);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load config JSON from configured path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;

        // Read config: deployer, dependencies, ownership, and salts
        cfg.deployer = _readAndLogAddress(json, "deployer");
        cfg.blacklistOperator = _readAndLogAddress(json, "blacklistOperator");
        cfg.oracle = _readAndLogAddress(json, "oracle");
        cfg.rewardDistributor = _readAndLogAddress(json, "rewardDistributor");
        cfg.roles = _readAndLogAddress(json, "roles");
        cfg.owner = _readAndLogAddress(json, "owner");
        cfg.implementationSalt = _readAndLogString(json, "implementationSalt");
        cfg.proxySalt = _readAndLogString(json, "proxySalt");

        // Requirement: all conditions must be satisfied
        require(cfg.deployer != address(0), InvalidDeployer());
        require(cfg.blacklistOperator != address(0), InvalidBlacklistOperator());
        require(cfg.oracle != address(0), InvalidOracle());
        require(cfg.roles != address(0), InvalidRoles());
        require(cfg.owner != address(0), InvalidOwner());
        require(bytes(cfg.implementationSalt).length > 0, InvalidImplementationSalt());
        require(bytes(cfg.proxySalt).length > 0, InvalidProxySalt());

        // Effects: return encoded validated config to base runner
        deployConfig = abi.encode(cfg);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "Operator";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployOperator.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployOperator.output.json";
    }
}
