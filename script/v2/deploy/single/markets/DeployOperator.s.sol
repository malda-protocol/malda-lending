// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {DeploymentScriptBase} from "script/v2/utils/DeploymentScriptBase.sol";
import {ScriptBase} from "script/v2/utils/ScriptBase.sol";

import {Operator} from "src/Operator/Operator.sol";
import {Deployer} from "src/utils/Deployer.sol";

/// @title DeployOperator
/// @notice Deployment script that deploys Operator using DeploymentScriptBase pattern
contract DeployOperator is DeploymentScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        address deployer;
        address blacklistOperator;
        address oracle;
        address rewardDistributor;
        address roles;
        address owner;
        string implementationSalt;
        string proxySalt;
    }

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    error InvalidDeployer();
    error InvalidBlacklistOperator();
    error InvalidOracle();
    error InvalidRoles();
    error InvalidOwner();
    error InvalidImplementationSalt();
    error InvalidProxySalt();
    error InvalidProxyAddress();

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @inheritdoc DeploymentScriptBase
    function _deployAndAssertResult(bytes memory deployConfig) internal override returns (address operatorAddress) {
        // Effects: decode validated runtime config
        DeployConfig memory cfg = abi.decode(deployConfig, (DeployConfig));

        // Effects: bind configured create3 deployer
        Deployer create3Deployer = Deployer(payable(cfg.deployer));
        bytes32 implementationSalt = _toBytes32Salt(cfg.implementationSalt);
        bytes32 proxySalt = _toBytes32Salt(cfg.proxySalt);

        // Interactions: precompute implementation address
        address implementation = create3Deployer.precompute(implementationSalt);
        if (implementation.code.length == 0) {
            // Interactions: deploy implementation if absent
            vm.startBroadcast();
            implementation = create3Deployer.create(implementationSalt, abi.encodePacked(type(Operator).creationCode));
            vm.stopBroadcast();
        }

        // Effects: build initialization calldata for proxy constructor
        bytes memory initData =
            abi.encodeWithSelector(Operator.initialize.selector, cfg.roles, cfg.blacklistOperator, cfg.owner);

        // Interactions: precompute proxy address
        operatorAddress = create3Deployer.precompute(proxySalt);

        // Effects: branch for first deploy vs rerun
        bool isFreshProxy = operatorAddress.code.length == 0;
        if (isFreshProxy) {
            // Interactions: deploy proxy and execute initializer
            vm.startBroadcast();
            operatorAddress = create3Deployer.create(
                proxySalt,
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode, abi.encode(implementation, cfg.owner, initData)
                )
            );
            vm.stopBroadcast();

            // Interactions: keep legacy parity by setting oracle only on fresh proxy path
            vm.broadcast();
            Operator(operatorAddress).setPriceOracle(cfg.oracle);
        }

        // Requirements: deployed or reused proxy must be valid
        require(operatorAddress != address(0), InvalidProxyAddress());
        require(operatorAddress.code.length > 0, InvalidProxyAddress());

        // Requirements: owner must match configuration
        require(Operator(operatorAddress).owner() == cfg.owner, InvalidOwner());

        // Requirements: fresh deployment path must wire oracle as configured
        if (isFreshProxy) {
            require(Operator(operatorAddress).oracleOperator() == cfg.oracle, InvalidOracle());
        }

        return operatorAddress;
    }

    /// @inheritdoc DeploymentScriptBase
    function _postDeploymentConfiguration(bytes memory, address) internal override {}

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

        // Requirements: validate critical config fields before deployment
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

    function _toBytes32Salt(string memory salt) internal pure returns (bytes32) {
        return keccak256(bytes(salt));
    }
}
