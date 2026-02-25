// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {DeploymentScriptBase} from "script/utils/DeploymentScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {OracleMock} from "test/mocks/OracleMock.sol";
import {Deployer} from "src/utils/Deployer.sol";

/// @title DeployMockOracle
/// @author Merge Layers Inc.
/// @notice Single deployment script that deploys and configures OracleMock
contract DeployMockOracle is DeploymentScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice Config value for deployer
        address deployer;
        /// @notice Config value for owner
        address owner;
        /// @notice Config value for price
        uint256 price;
        /// @notice Config value for underlyingPrice
        uint256 underlyingPrice;
        /// @notice Config value for salt
        string salt;
    }

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when deployer is invalid
    error InvalidDeployer();
    /// @notice Error thrown when owner is invalid
    error InvalidOwner();
    /// @notice Error thrown when salt is invalid
    error InvalidSalt();
    /// @notice Error thrown when oracle address is invalid
    error InvalidOracleAddress();
    /// @notice Error thrown when price is invalid
    error InvalidPrice();
    /// @notice Error thrown when underlying price is invalid
    error InvalidUnderlyingPrice();

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @inheritdoc DeploymentScriptBase
    function _deployAndAssertResult(bytes memory deployConfig) internal override returns (address oracleAddress) {
        DeployConfig memory cfg = abi.decode(deployConfig, (DeployConfig));

        Deployer deployer = Deployer(payable(cfg.deployer));

        // Interactions: precompute deterministic deployment address
        bytes32 salt = keccak256(bytes(cfg.salt));
        oracleAddress = deployer.precompute(salt);
        if (oracleAddress.code.length == 0) {
            bytes memory callData = abi.encodeWithSelector(
                deployer.create.selector, salt, abi.encodePacked(type(OracleMock).creationCode, abi.encode(cfg.owner))
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

            oracleAddress = abi.decode(returnData, (address));
        }

        // Requirements: oracleAddress should not be the zero address; oracleAddress code length should be greater than zero;
        // admin should equal cfg.owner.
        require(oracleAddress != address(0), InvalidOracleAddress());
        require(oracleAddress.code.length > 0, InvalidOracleAddress());
        require(OracleMock(oracleAddress).admin() == cfg.owner, InvalidOwner());
    }

    /// @inheritdoc DeploymentScriptBase
    function _postDeploymentConfiguration(bytes memory deployConfig, address oracleAddress) internal override {
        // Effects: decode validated runtime config
        DeployConfig memory cfg = abi.decode(deployConfig, (DeployConfig));

        // Interactions: broadcast post-deployment oracle state configuration
        vm.startBroadcast();
        OracleMock(oracleAddress).setPrice(cfg.price);
        OracleMock(oracleAddress).setUnderlyingPrice(cfg.underlyingPrice);
        vm.stopBroadcast();

        // Requirements: price should equal cfg.price; underlyingPrice should equal cfg.underlyingPrice.
        require(OracleMock(oracleAddress).price() == cfg.price, InvalidPrice());
        require(OracleMock(oracleAddress).underlyingPrice() == cfg.underlyingPrice, InvalidUnderlyingPrice());
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
        vm.serializeAddress(json, "owner", cfg.owner);
        vm.serializeUint(json, "price", cfg.price);
        vm.serializeUint(json, "underlyingPrice", cfg.underlyingPrice);
        serialized = vm.serializeString(json, "salt", cfg.salt);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load input config JSON from selected path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        // Effects: read runtime config fields
        cfg.deployer = _readAndLogAddress(json, "deployer");
        cfg.owner = _readAndLogAddress(json, "owner");
        cfg.price = _readAndLogUint(json, "price");
        cfg.underlyingPrice = _readAndLogUint(json, "underlyingPrice");
        cfg.salt = _readAndLogString(json, "salt");

        // Requirements: cfg.deployer should not be the zero address; cfg.owner should not be the zero address; cfg.salt should
        // not be empty.
        require(cfg.deployer != address(0), InvalidDeployer());
        require(cfg.owner != address(0), InvalidOwner());
        require(bytes(cfg.salt).length > 0, InvalidSalt());

        // Effects: return encoded config for base runner
        deployConfig = abi.encode(cfg);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "MockOracle";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployMockOracle.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployMockOracle.output.json";
    }
}
