// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {DeploymentScriptBase} from "script/utils/DeploymentScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {Deployer} from "src/utils/Deployer.sol";

/// @title DeployExtensionMarket
/// @author Merge Layers Inc.
/// @notice Single deployment script that deploys mTokenGateway implementation + proxy
contract DeployExtensionMarket is DeploymentScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice Config value for deployer
        address deployer;
        /// @notice Config value for blacklister
        address blacklister;
        /// @notice Config value for underlyingToken
        address underlyingToken;
        /// @notice Config value for name
        string name;
        /// @notice Config value for owner
        address owner;
        /// @notice Config value for zkVerifier
        address zkVerifier;
        /// @notice Config value for roles
        address roles;
        /// @notice Config value for implementationSalt
        string implementationSalt;
        /// @notice Config value for proxySalt
        string proxySalt;
    }

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when deployer is invalid
    error InvalidDeployer();
    /// @notice Error thrown when blacklister is invalid
    error InvalidBlacklister();
    /// @notice Error thrown when underlying token is invalid
    error InvalidUnderlyingToken();
    /// @notice Error thrown when name is invalid
    error InvalidName();
    /// @notice Error thrown when owner is invalid
    error InvalidOwner();
    /// @notice Error thrown when zk verifier is invalid
    error InvalidZkVerifier();
    /// @notice Error thrown when roles is invalid
    error InvalidRoles();
    /// @notice Error thrown when implementation salt is invalid
    error InvalidImplementationSalt();
    /// @notice Error thrown when proxy salt is invalid
    error InvalidProxySalt();
    /// @notice Error thrown when proxy address is invalid
    error InvalidProxyAddress();

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @inheritdoc DeploymentScriptBase
    function _deployAndAssertResult(bytes memory deployConfig) internal override returns (address marketAddress) {
        DeployConfig memory cfg = abi.decode(deployConfig, (DeployConfig));

        Deployer deployer = Deployer(payable(cfg.deployer));

        // Interactions: precompute deterministic deployment address
        bytes32 implementationSalt = keccak256(bytes(cfg.implementationSalt));
        address implementation = deployer.precompute(implementationSalt);
        if (implementation.code.length == 0) {
            bytes memory callData =
                abi.encodeWithSelector(deployer.create.selector, implementationSalt, type(mTokenGateway).creationCode);
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

        // Interactions: precompute deterministic deployment address
        bytes32 proxySalt = keccak256(bytes(cfg.proxySalt));
        marketAddress = deployer.precompute(proxySalt);
        if (marketAddress.code.length == 0) {
            bytes memory callData = abi.encodeWithSelector(
                deployer.create.selector,
                proxySalt,
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(
                        implementation,
                        cfg.owner,
                        abi.encodeWithSelector(
                            mTokenGateway.initialize.selector,
                            payable(cfg.owner),
                            cfg.underlyingToken,
                            cfg.roles,
                            cfg.blacklister,
                            cfg.zkVerifier
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

            marketAddress = abi.decode(returnData, (address));
        }

        // Requirements: marketAddress should not be the zero address; marketAddress code length should be greater than zero.
        require(marketAddress != address(0), InvalidProxyAddress());
        require(marketAddress.code.length > 0, InvalidProxyAddress());

        mTokenGateway market = mTokenGateway(payable(marketAddress));
        // Requirement: all conditions must be satisfied
        require(market.owner() == cfg.owner, InvalidOwner());
        require(market.underlying() == cfg.underlyingToken, InvalidUnderlyingToken());
        require(address(market.rolesOperator()) == cfg.roles, InvalidRoles());
        require(address(market.verifier()) == cfg.zkVerifier, InvalidZkVerifier());
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
        vm.serializeAddress(json, "blacklister", cfg.blacklister);
        vm.serializeAddress(json, "underlyingToken", cfg.underlyingToken);
        vm.serializeString(json, "name", cfg.name);
        vm.serializeAddress(json, "owner", cfg.owner);
        vm.serializeAddress(json, "zkVerifier", cfg.zkVerifier);
        vm.serializeAddress(json, "roles", cfg.roles);
        vm.serializeString(json, "implementationSalt", cfg.implementationSalt);
        serialized = vm.serializeString(json, "proxySalt", cfg.proxySalt);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load input config JSON from selected path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        // Effects: read runtime config fields
        cfg.deployer = _readAndLogAddress(json, "deployer");
        cfg.blacklister = _readAndLogAddress(json, "blacklister");
        cfg.underlyingToken = _readAndLogAddress(json, "underlyingToken");
        cfg.name = _readAndLogString(json, "name");
        cfg.owner = _readAndLogAddress(json, "owner");
        cfg.zkVerifier = _readAndLogAddress(json, "zkVerifier");
        cfg.roles = _readAndLogAddress(json, "roles");
        cfg.implementationSalt = _readAndLogString(json, "implementationSalt");
        cfg.proxySalt = _readAndLogString(json, "proxySalt");

        // Requirement: all conditions must be satisfied
        require(cfg.deployer != address(0), InvalidDeployer());
        require(cfg.blacklister != address(0), InvalidBlacklister());
        require(cfg.underlyingToken != address(0), InvalidUnderlyingToken());
        require(bytes(cfg.name).length > 0, InvalidName());
        require(cfg.owner != address(0), InvalidOwner());
        require(cfg.zkVerifier != address(0), InvalidZkVerifier());
        require(cfg.roles != address(0), InvalidRoles());
        require(bytes(cfg.implementationSalt).length > 0, InvalidImplementationSalt());
        require(bytes(cfg.proxySalt).length > 0, InvalidProxySalt());

        // Effects: return encoded config for base runner
        deployConfig = abi.encode(cfg);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "ExtensionMarket";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployExtensionMarket.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployExtensionMarket.output.json";
    }
}
