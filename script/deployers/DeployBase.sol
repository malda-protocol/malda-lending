// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {DeployConfig, Market, Role, InterestConfig} from "./Types.sol";

contract DeployBase is Script {
    using stdJson for string;

    Deployer public deployer;
    mapping(string => DeployConfig) public configs;
    string public configPath;
    string[] public networks;
    uint256 public key;
    mapping(string => uint256) public forks;

    function setUp() public virtual {
        key = vm.envUint("OWNER_PRIVATE_KEY");
        configPath = "deployment-config.json";
        networks = vm.parseJsonKeys(vm.readFile(configPath), ".networks");

        for (uint256 i = 0; i < networks.length; i++) {
            string memory network = networks[i];
            _parseBaseConfig(network);
        }
    }

    function _parseBaseConfig(string memory network) internal {
        DeployConfig storage config = configs[network];
        string memory json = vm.readFile(configPath);
        string memory networkPath = string.concat(".networks.", network);

        // Parse basic config
        config.chainId = uint32(abi.decode(json.parseRaw(string.concat(networkPath, ".chainId")), (uint256)));
        config.isHost = abi.decode(json.parseRaw(string.concat(networkPath, ".isHost")), (bool));

        // Parse deployer config
        config.deployer.owner = abi.decode(json.parseRaw(string.concat(networkPath, ".deployer.owner")), (address));
        config.deployer.salt = abi.decode(json.parseRaw(string.concat(networkPath, ".deployer.salt")), (string));

        // Parse roles
        Role[] memory roles = abi.decode(json.parseRaw(string.concat(networkPath, ".roles")), (Role[]));

        for (uint256 i = 0; i < roles.length; i++) {
            config.roles.push(roles[i]);
        }

        // Parse markets
        Market[] memory markets = abi.decode(json.parseRaw(string.concat(networkPath, ".markets")), (Market[]));
        for (uint256 i = 0; i < markets.length; i++) {
            config.markets.push(markets[i]);
        }

        // Parse zkVerifier config
        config.zkVerifier.verifierAddress =
            abi.decode(json.parseRaw(string.concat(networkPath, ".zkVerifier.verifierAddress")), (address));
        config.zkVerifier.imageId =
            abi.decode(json.parseRaw(string.concat(networkPath, ".zkVerifier.imageId")), (bytes32));

        // Parse host-specific config
        if (config.isHost) {
            _parseHostConfig(json, network, networkPath);
        }
    }

    function _parseHostConfig(string memory json, string memory network, string memory networkPath) internal {
        DeployConfig storage config = configs[network];

        // Parse oracle config
        string memory oraclePath = string.concat(networkPath, ".oracle");
        config.oracle.oracleType = abi.decode(json.parseRaw(string.concat(oraclePath, ".oracleType")), (string));
        config.oracle.stalenessPeriod =
            abi.decode(json.parseRaw(string.concat(oraclePath, ".stalenessPeriod")), (uint256));
        config.oracle.usdcFeed = abi.decode(json.parseRaw(string.concat(oraclePath, ".usdcFeed")), (address));
        config.oracle.wethFeed = abi.decode(json.parseRaw(string.concat(oraclePath, ".wethFeed")), (address));

        // Parse allowed chains
        bytes memory allowedChainsRaw = json.parseRaw(string.concat(networkPath, ".allowedChains"));
        config.allowedChains = abi.decode(allowedChainsRaw, (uint32[]));
    }

    function _verifyChain(string memory network) internal view {
        require(block.chainid == configs[network].chainId, "Wrong chain");
    }

    function _deployCreate3Deployer(string memory network) internal {
        address owner = configs[network].deployer.owner;
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOYER_SALT"))));

        // Compute the deterministic address first
        bytes memory bytecode = type(Deployer).creationCode;
        bytes memory constructorArgs = abi.encode(owner);
        bytes memory bytecodeWithConstructor = abi.encodePacked(bytecode, constructorArgs);

        address deployerAddress = _computeCreate2Address(salt, bytecodeWithConstructor);

        // Check if deployer already exists at this address
        uint256 size;
        assembly {
            size := extcodesize(deployerAddress)
        }

        // Deploy only if not already deployed
        if (size == 0) {
        vm.startBroadcast(key);
            deployerAddress = _deployCreate2(salt, bytecode, constructorArgs);
        vm.stopBroadcast();
            console.log("Deployer contract deployed at: %s", deployerAddress);
        } else {
            console.log("Using existing deployer at: %s", deployerAddress);
        }
        deployer = Deployer(payable(deployerAddress));
    }

    function _computeCreate2Address(bytes32 salt, bytes memory bytecode) internal view returns (address) {
        bytes32 bytecodeHash = keccak256(bytecode);
        bytes32 _data = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, bytecodeHash));
        return address(uint160(uint256(_data)));
    }

    function _deployCreate2(bytes32 salt, bytes memory bytecode, bytes memory constructorArgs)
        internal
        returns (address)
    {
        bytes memory bytecodeWithConstructor = abi.encodePacked(bytecode, constructorArgs);

        address deployedAddress;
        assembly {
            deployedAddress := create2(0, add(bytecodeWithConstructor, 0x20), mload(bytecodeWithConstructor), salt)
            if iszero(deployedAddress) { revert(0, 0) }
        }

        return deployedAddress;
    }

    function getSalt(string memory name) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes(string.concat(name, "-v1")))
        );
    }
}
