// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {DeploymentScriptBase} from "script/utils/DeploymentScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {Deployer} from "src/utils/Deployer.sol";

/// @title DeployHostMarket
/// @author Merge Layers Inc.
/// @notice Single deployment script that deploys mErc20Host implementation + proxy
contract DeployHostMarket is DeploymentScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice Config value for deployer
        address deployer;
        /// @notice Config value for underlyingToken
        address underlyingToken;
        /// @notice Config value for operator
        address operator;
        /// @notice Config value for interestModel
        address interestModel;
        /// @notice Config value for exchangeRateMantissa
        uint256 exchangeRateMantissa;
        /// @notice Config value for name
        string name;
        /// @notice Config value for symbol
        string symbol;
        /// @notice Config value for decimals
        uint256 decimals;
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
    /// @notice Error thrown when underlying token is invalid
    error InvalidUnderlyingToken();
    /// @notice Error thrown when operator is invalid
    error InvalidOperator();
    /// @notice Error thrown when interest model is invalid
    error InvalidInterestModel();
    /// @notice Error thrown when exchange rate is invalid
    error InvalidExchangeRate();
    /// @notice Error thrown when name is invalid
    error InvalidName();
    /// @notice Error thrown when symbol is invalid
    error InvalidSymbol();
    /// @notice Error thrown when decimals is invalid
    error InvalidDecimals();
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

        // Interactions: precompute deterministic deployment address for implementation
        bytes32 implementationSalt = keccak256(bytes(cfg.implementationSalt));
        address implementation = deployer.precompute(implementationSalt);
        if (implementation.code.length == 0) {
            bytes memory callData =
                abi.encodeWithSelector(deployer.create.selector, implementationSalt, type(mErc20Host).creationCode);
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

        // Interactions: precompute deterministic deployment address for proxy
        bytes32 proxySalt = keccak256(bytes(cfg.proxySalt));
        marketAddress = deployer.precompute(proxySalt);
        if (marketAddress.code.length == 0) {
            bytes memory callData = abi.encodeWithSelector(
                deployer.create.selector,
                proxySalt,
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implementation, cfg.owner, _encodeInitializeData(cfg))
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

        mErc20Host market = mErc20Host(payable(marketAddress));
        // Requirement: all conditions must be satisfied
        require(market.admin() == payable(cfg.owner), InvalidOwner());
        require(market.underlying() == cfg.underlyingToken, InvalidUnderlyingToken());
        require(market.operator() == cfg.operator, InvalidOperator());
        require(market.interestRateModel() == cfg.interestModel, InvalidInterestModel());
        require(address(market.verifier()) == cfg.zkVerifier, InvalidZkVerifier());
        require(address(market.rolesOperator()) == cfg.roles, InvalidRoles());
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
        vm.serializeAddress(json, "underlyingToken", cfg.underlyingToken);
        vm.serializeAddress(json, "operator", cfg.operator);
        vm.serializeAddress(json, "interestModel", cfg.interestModel);
        vm.serializeUint(json, "exchangeRateMantissa", cfg.exchangeRateMantissa);
        vm.serializeString(json, "name", cfg.name);
        vm.serializeString(json, "symbol", cfg.symbol);
        vm.serializeUint(json, "decimals", cfg.decimals);
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
        cfg.underlyingToken = _readAndLogAddress(json, "underlyingToken");
        cfg.operator = _readAndLogAddress(json, "operator");
        cfg.interestModel = _readAndLogAddress(json, "interestModel");
        cfg.exchangeRateMantissa = _readAndLogUint(json, "exchangeRateMantissa");
        cfg.name = _readAndLogString(json, "name");
        cfg.symbol = _readAndLogString(json, "symbol");
        cfg.decimals = _readAndLogUint(json, "decimals");
        cfg.owner = _readAndLogAddress(json, "owner");
        cfg.zkVerifier = _readAndLogAddress(json, "zkVerifier");
        cfg.roles = _readAndLogAddress(json, "roles");
        cfg.implementationSalt = _readAndLogString(json, "implementationSalt");
        cfg.proxySalt = _readAndLogString(json, "proxySalt");

        // Requirement: all conditions must be satisfied
        require(cfg.deployer != address(0), InvalidDeployer());
        require(cfg.underlyingToken != address(0), InvalidUnderlyingToken());
        require(cfg.operator != address(0), InvalidOperator());
        require(cfg.interestModel != address(0), InvalidInterestModel());
        require(cfg.exchangeRateMantissa > 0, InvalidExchangeRate());
        require(bytes(cfg.name).length > 0, InvalidName());
        require(bytes(cfg.symbol).length > 0, InvalidSymbol());
        require(cfg.decimals < 256, InvalidDecimals());
        require(cfg.owner != address(0), InvalidOwner());
        require(cfg.zkVerifier != address(0), InvalidZkVerifier());
        require(cfg.roles != address(0), InvalidRoles());
        require(bytes(cfg.implementationSalt).length > 0, InvalidImplementationSalt());
        require(bytes(cfg.proxySalt).length > 0, InvalidProxySalt());

        // Effects: return encoded config for base runner
        deployConfig = abi.encode(cfg);
    }

    /// @notice Encodes mErc20Host initializer payload for proxy deployment
    /// @param cfg Decoded deployment config
    /// @return initData Encoded initialize calldata
    function _encodeInitializeData(DeployConfig memory cfg) internal pure returns (bytes memory initData) {
        initData = abi.encodeWithSelector(
            mErc20Host.initialize.selector,
            cfg.underlyingToken,
            cfg.operator,
            cfg.interestModel,
            cfg.exchangeRateMantissa,
            cfg.name,
            cfg.symbol,
            uint8(cfg.decimals),
            payable(cfg.owner),
            cfg.zkVerifier,
            cfg.roles
        );
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "HostMarket";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployHostMarket.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployHostMarket.output.json";
    }
}
