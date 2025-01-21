// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Deployer} from "src/utils/Deployer.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ChainConfig, OracleConfig} from "./Types.sol";

contract DeployBase is Script {
    using stdJson for string;

    Deployer public deployer;
    uint256 public chainsLength;
    mapping(uint256 => ChainConfig) public chains;
    ChainConfig public hostChain;

    function setUp() public virtual {        
        string memory json = vm.readFile("deployment-config.json");
        
        console.log("Parsing chains");
        
        // We know there are 2 chains from the config
        chainsLength = 2;
        
        for (uint i = 0; i < chainsLength; i++) {
            string memory path = string.concat(".chains[", vm.toString(i), "]");
            ChainConfig memory chain;
            
            chain.id = abi.decode(json.parseRaw(string.concat(path, ".id")), (uint32));
            chain.name = abi.decode(json.parseRaw(string.concat(path, ".name")), (string));
            chain.rpcAlias = abi.decode(json.parseRaw(string.concat(path, ".rpcAlias")), (string));
            chain.isHost = abi.decode(json.parseRaw(string.concat(path, ".isHost")), (bool));
            
            // Parse oracle config for host chain
            if (chain.isHost) {
                string memory oraclePath = string.concat(path, ".contracts.oracle");
                OracleConfig memory oracle;
                oracle.oracleType = abi.decode(json.parseRaw(string.concat(oraclePath, ".type")), (string));
                oracle.stalenessPeriod = abi.decode(json.parseRaw(string.concat(oraclePath, ".stalenessPeriod")), (uint256));
                chain.oracle = oracle;
                hostChain = chain;
                console.log("Host chain found: %s", chain.name);
            }
            
            chains[i] = chain;
            console.log("Chain %s parsed: %s", i, chain.name);
        }
        
        console.log("Chains parsed");
        
        // Deploy CREATE3 deployer to all configured chains
        _deployCreate3DeployerToAllChains();

        vm.makePersistent(address(deployer));
    }

    function _deployCreate3DeployerToAllChains() internal {
        uint256 ownerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        address owner = vm.addr(ownerPrivateKey);

        for (uint i = 0; i < chainsLength; i++) {
            ChainConfig memory chain = chains[i];
            
            // Switch to chain's RPC
            vm.createSelectFork(vm.rpcUrl(chain.rpcAlias));
            
            console.log("\nDeploying CREATE3 Deployer to %s", chain.name);
            
            // Start broadcasting with owner's key
            vm.startBroadcast(ownerPrivateKey);
            
            // Deploy CREATE3 deployer
            _deployCreate3Deployer(owner);
            
            // Stop broadcast before switching chains
            vm.stopBroadcast();
        }
    }

    function _deployCreate3Deployer(address owner) internal {
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
            deployerAddress = _deployCreate2(salt, bytecode, constructorArgs);
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
