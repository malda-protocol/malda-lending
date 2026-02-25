// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {DeploymentScriptBase} from "script/utils/DeploymentScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {Deployer} from "src/utils/Deployer.sol";

/// @title DeployMockToken
/// @author Merge Layers Inc.
/// @notice Single deployment script that deploys ERC20Mock
contract DeployMockToken is DeploymentScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice Config value for deployer
        address deployer;
        /// @notice Config value for name
        string name;
        /// @notice Config value for symbol
        string symbol;
        /// @notice Config value for decimals
        uint256 decimals;
        /// @notice Config value for owner
        address owner;
        /// @notice Config value for pohVerify
        address pohVerify;
        /// @notice Config value for limit
        uint256 limit;
        /// @notice Config value for salt
        string salt;
    }

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when deployer is invalid
    error InvalidDeployer();
    /// @notice Error thrown when name is invalid
    error InvalidName();
    /// @notice Error thrown when symbol is invalid
    error InvalidSymbol();
    /// @notice Error thrown when decimals is invalid
    error InvalidDecimals();
    /// @notice Error thrown when owner is invalid
    error InvalidOwner();
    /// @notice Error thrown when poh verify is invalid
    error InvalidPohVerify();
    /// @notice Error thrown when salt is invalid
    error InvalidSalt();
    /// @notice Error thrown when mock token address is invalid
    error InvalidMockTokenAddress();

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @inheritdoc DeploymentScriptBase
    function _deployAndAssertResult(bytes memory deployConfig) internal override returns (address mockTokenAddress) {
        // Effects: decode validated runtime config
        DeployConfig memory cfg = abi.decode(deployConfig, (DeployConfig));

        Deployer deployer = Deployer(payable(cfg.deployer));

        // Interactions: precompute deterministic deployment address
        bytes32 salt = keccak256(bytes(cfg.salt));
        mockTokenAddress = deployer.precompute(salt);
        if (mockTokenAddress.code.length == 0) {
            bytes memory callData = abi.encodeWithSelector(
                deployer.create.selector,
                salt,
                abi.encodePacked(
                    type(ERC20Mock).creationCode,
                    abi.encode(cfg.name, cfg.symbol, uint8(cfg.decimals), cfg.owner, cfg.pohVerify, cfg.limit)
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

            mockTokenAddress = abi.decode(returnData, (address));
        }

        // Requirements: mockTokenAddress should not be the zero address; mockTokenAddress code length should be greater than
        // zero.
        require(mockTokenAddress != address(0), InvalidMockTokenAddress());
        require(mockTokenAddress.code.length > 0, InvalidMockTokenAddress());

        ERC20Mock token = ERC20Mock(mockTokenAddress);
        // Requirements: admin should equal cfg.owner; pohVerify should equal cfg.pohVerify; decimals should equal cfg.decimals.
        require(token.admin() == cfg.owner, InvalidOwner());
        require(token.pohVerify() == cfg.pohVerify, InvalidPohVerify());
        require(token.decimals() == uint8(cfg.decimals), InvalidDecimals());
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
        vm.serializeString(json, "name", cfg.name);
        vm.serializeString(json, "symbol", cfg.symbol);
        vm.serializeUint(json, "decimals", cfg.decimals);
        vm.serializeAddress(json, "owner", cfg.owner);
        vm.serializeAddress(json, "pohVerify", cfg.pohVerify);
        vm.serializeUint(json, "limit", cfg.limit);
        serialized = vm.serializeString(json, "salt", cfg.salt);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load input config JSON from selected path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        // Effects: read runtime config fields
        cfg.deployer = _readAndLogAddress(json, "deployer");
        cfg.name = _readAndLogString(json, "name");
        cfg.symbol = _readAndLogString(json, "symbol");
        cfg.decimals = _readAndLogUint(json, "decimals");
        cfg.owner = _readAndLogAddress(json, "owner");
        cfg.pohVerify = _readAndLogAddress(json, "pohVerify");
        cfg.limit = _readAndLogUint(json, "limit");
        cfg.salt = _readAndLogString(json, "salt");

        // Requirement: all conditions must be satisfied
        require(cfg.deployer != address(0), InvalidDeployer());
        require(bytes(cfg.name).length > 0, InvalidName());
        require(bytes(cfg.symbol).length > 0, InvalidSymbol());
        require(cfg.decimals < 256, InvalidDecimals());
        require(cfg.owner != address(0), InvalidOwner());
        require(cfg.pohVerify != address(0), InvalidPohVerify());
        require(bytes(cfg.salt).length > 0, InvalidSalt());

        // Effects: return encoded config for base runner
        deployConfig = abi.encode(cfg);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "MockToken";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployMockToken.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployMockToken.output.json";
    }
}
