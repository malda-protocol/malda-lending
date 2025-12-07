// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {IOwnable} from "src/interfaces/IOwnable.sol";
import {SetRole} from "../../configuration/SetRole.s.sol";
import {DeployBaseRelease} from "../../deployers/DeployBaseRelease.sol";

interface IAdmin {
    function setPendingAdmin(address newAdmin) external;
}

interface ISafeModule {
    function setMaster(address newAdmin) external;
    function setGuardian(address addr) external;
    function setGasGuardian(address addr) external;
}

contract TransferReleaseOwnership is DeployBaseRelease {
    using stdJson for string;

    SetRole setRole;

    address[] marketList;
    address pauser;
    address batchSubmitter;
    address timelockController;
    address rewardDistributor;
    address zkVerifier;
    address rebalancer;
    address acrossBridge;
    address everclearBridge;
    address rolesContract;
    address oracle;
    address operator;
    address deployer;
    address gasHelper;
    address safeModule = 0x923B1e0e129fAc8949d6d0C8C2f932Be4B055637;

    address[] interesteModels;

    function setUp() public override {
        configPath = "deployment-config-release.json";
        super.setUp();

        string memory marketsOutputPath = "script/deployment/mainnet/output/release-deployed-market-addresses.json";
        string memory rawMarketJson = vm.readFile(marketsOutputPath);
        uint256 length = 8;
        marketList = new address[](length);
        console.log("Markets: ");
        for (uint256 i; i < length; ++i) {
            string memory base = string.concat("[", vm.toString(i), "]");

            address marketAddr = vm.parseJsonAddress(rawMarketJson, string.concat(base, ".address"));
            marketList[i] = marketAddr;
        }
        console.log("Registered no of markets:", marketList.length);
        for (uint256 i; i < marketList.length; ++i) {
            console.log(" - market: ", marketList[i]);
        }

        string memory corePath = "script/deployment/mainnet/output/release-deployed-core-addresses.json";
        string memory jsonContent = vm.readFile(corePath);
        console.logString(jsonContent);
        pauser = vm.parseJsonAddress(jsonContent, ".Pauser");
        batchSubmitter = vm.parseJsonAddress(jsonContent, ".BatchSubmitter");
        rewardDistributor = vm.parseJsonAddress(jsonContent, ".RewardDistributor");
        zkVerifier = vm.parseJsonAddress(jsonContent, ".ZkVerifier");
        rolesContract = vm.parseJsonAddress(jsonContent, ".Roles");
        operator = vm.parseJsonAddress(jsonContent, ".Operator");
        deployer = vm.parseJsonAddress(jsonContent, ".Deployer");
        gasHelper = vm.parseJsonAddress(jsonContent, ".DefaultGasHelper");

        interesteModels.push(0x9323cB1416a5d14b47f09c64641D078F67b902a3);
        interesteModels.push(0x78e537025Dfb75ECa61f268483F0973b6934c644);
        interesteModels.push(0xB864Ac7673BE69E69A449506ECE4cF0e4408e880);
        interesteModels.push(0xA2C097933717CC6fc771408e2C243C5F2dbAF8Af);
        interesteModels.push(0x38461F3131149Da56b799c04B340D992b57A19a3);
        interesteModels.push(0xb301c62f3f9622523c39a6ba47699fa2182483B4);
        interesteModels.push(0x3592F632C5CA77A67FbF2a4388821cd95cC029Be);
        interesteModels.push(0x5372910e816879803577fA98D78c3C0D7764D415);
    }

    function run() public {
        // ------------------
        // ------------------
        // ------------------
        // ------------------
        // ------------- OWNER TO SET -----------

        address securityMultisig = 0x3E8545884FE2450A2E3973c341F8A22A645289C5;
        address operatingMultisig = 0x91B945CbB063648C44271868a7A0c7BdFf64827D;
        // ------------------
        // ------------------
        // ------------------
        // ------------------
        // ------------------

        // Deploy to all networks
        for (uint256 i = 0; i < networks.length; i++) {
            string memory network = networks[i];
            console.log("\n=== Configuring %s ===", network);

            // Create fork for this network
            forks[network] = vm.createSelectFork(network);

            uint256 key = vm.envUint("PRIVATE_KEY");
            vm.startBroadcast(key);

            // Transfer ownerhip
            console.log("Transfer ownership");

            console.log(" -- for Deployer ", operatingMultisig);
            IAdmin(deployer).setPendingAdmin(operatingMultisig);

            console.log(" -- for Pauser ", securityMultisig);
            IOwnable(pauser).transferOwnership(securityMultisig);

            console.log(" -- for ZkVerifier ", securityMultisig);
            IOwnable(zkVerifier).transferOwnership(securityMultisig);

            console.log(" -- for BatchSubmitter ", operatingMultisig);
            IOwnable(batchSubmitter).transferOwnership(operatingMultisig);

            setRole = new SetRole();

            if (configs[network].isHost) {
                console.log(" HOST");
                console.log(" -- for RewardDistributor ", operatingMultisig);
                IOwnable(rewardDistributor).transferOwnership(operatingMultisig);

                console.log(" -- for Operator ", securityMultisig);
                IOwnable(operator).transferOwnership(securityMultisig);

                console.log(" -- for DefaultGasHelper ", operatingMultisig);
                IOwnable(gasHelper).transferOwnership(operatingMultisig);

                console.log(" -- for all host markets ", securityMultisig);
                for (uint256 j; j < marketList.length; ++j) {
                    console.log(" -- for market: ", marketList[j]);
                    IAdmin(marketList[j]).setPendingAdmin(securityMultisig);
                }
                ISafeModule(safeModule).setGuardian(securityMultisig);
                ISafeModule(safeModule).setGasGuardian(operatingMultisig);
                ISafeModule(safeModule).setMaster(securityMultisig);

                console.log(" -- for all interest models ", securityMultisig);
                for (uint256 j; j < interesteModels.length; ++j) {
                    console.log(" -- for interest model: ", interesteModels[j]);
                    IOwnable(interesteModels[j]).transferOwnership(operatingMultisig);
                }
                vm.stopBroadcast();

                console.log(" -- for Roles securityMultisig", rolesContract);
                console.log(" -- for A");
                setRole.run(rolesContract, securityMultisig, keccak256(abi.encodePacked("GUARDIAN_PAUSE")), true);
                console.log(" -- for A1");
                console.log(" -- for A");
                setRole.run(rolesContract, securityMultisig, keccak256(abi.encodePacked("GUARDIAN_BLACKLIST")), true);

                console.log(" -- for B");
                setRole.run(rolesContract, securityMultisig, keccak256(abi.encodePacked("GUARDIAN_ORACLE")), true);

                console.log(" -- for C");
                setRole.run(rolesContract, securityMultisig, keccak256(abi.encodePacked("CHAINS_MANAGER")), true);

                setRole.run(
                    rolesContract,
                    0xB819A871d20913839c37f316Dc914b0570bfc0eE,
                    keccak256(abi.encodePacked("GUARDIAN_PAUSE")),
                    false
                );
                setRole.run(
                    rolesContract,
                    0xB819A871d20913839c37f316Dc914b0570bfc0eE,
                    keccak256(abi.encodePacked("GUARDIAN_BLACKLIST")),
                    false
                );
                setRole.run(
                    rolesContract,
                    0xB819A871d20913839c37f316Dc914b0570bfc0eE,
                    keccak256(abi.encodePacked("GUARDIAN_ORACLE")),
                    false
                );
                setRole.run(
                    rolesContract,
                    0xB819A871d20913839c37f316Dc914b0570bfc0eE,
                    keccak256(abi.encodePacked("CHAINS_MANAGER")),
                    false
                );

                console.log(" -- for Roles operatingMultisig", rolesContract);
                setRole.run(rolesContract, operatingMultisig, keccak256(abi.encodePacked("GUARDIAN_BORROW_CAP")), true);
                setRole.run(
                    rolesContract,
                    0xB819A871d20913839c37f316Dc914b0570bfc0eE,
                    keccak256(abi.encodePacked("GUARDIAN_BORROW_CAP")),
                    false
                );

                setRole.run(rolesContract, operatingMultisig, keccak256(abi.encodePacked("GUARDIAN_SUPPLY_CAP")), true);
                setRole.run(
                    rolesContract,
                    0xB819A871d20913839c37f316Dc914b0570bfc0eE,
                    keccak256(abi.encodePacked("GUARDIAN_SUPPLY_CAP")),
                    false
                );

                setRole.run(rolesContract, operatingMultisig, keccak256(abi.encodePacked("GUARDIAN_RESERVE")), true);
                setRole.run(
                    rolesContract,
                    0xB819A871d20913839c37f316Dc914b0570bfc0eE,
                    keccak256(abi.encodePacked("GUARDIAN_RESERVE")),
                    false
                );

                setRole.run(rolesContract, operatingMultisig, keccak256(abi.encodePacked("GUARDIAN_BRIDGE")), true);
                setRole.run(
                    rolesContract,
                    0xB819A871d20913839c37f316Dc914b0570bfc0eE,
                    keccak256(abi.encodePacked("GUARDIAN_BRIDGE")),
                    false
                );
            } else {
                console.log(" EXTENSION");
                console.log(" -- for all extension markets ", securityMultisig);
                for (uint256 j; j < 4; ++j) {
                    if (
                        marketList[i] == 0xe79a5f1E2E5619dF1cbb089Db3B11ff9E4dA5aff
                            || marketList[i] == 0x867B44af79da71684508c25a1323db3cce5bC23D
                            || marketList[i] == 0x301E5481271fD4F4f4C0291F88d7d829c64E2B2b
                            || marketList[i] == 0xa31963C753f277f7d82d98F56b2C374256925eB7
                    ) continue;

                    console.log(" -- for market: ", marketList[j]);
                    IOwnable(marketList[j]).transferOwnership(securityMultisig);
                }

                vm.stopBroadcast();
                console.log(" -- for Roles ");
                setRole.run(rolesContract, securityMultisig, keccak256(abi.encodePacked("GUARDIAN_PAUSE")), true);
                setRole.run(
                    rolesContract,
                    0xB819A871d20913839c37f316Dc914b0570bfc0eE,
                    keccak256(abi.encodePacked("GUARDIAN_PAUSE")),
                    false
                );

                setRole.run(rolesContract, securityMultisig, keccak256(abi.encodePacked("GUARDIAN_BLACKLIST")), true);
                setRole.run(
                    rolesContract,
                    0xB819A871d20913839c37f316Dc914b0570bfc0eE,
                    keccak256(abi.encodePacked("GUARDIAN_BLACKLIST")),
                    false
                );

                setRole.run(rolesContract, securityMultisig, keccak256(abi.encodePacked("GUARDIAN_ORACLE")), true);
                setRole.run(
                    rolesContract,
                    0xB819A871d20913839c37f316Dc914b0570bfc0eE,
                    keccak256(abi.encodePacked("GUARDIAN_ORACLE")),
                    false
                );

                setRole.run(rolesContract, securityMultisig, keccak256(abi.encodePacked("CHAINS_MANAGER")), true);
                setRole.run(
                    rolesContract,
                    0xB819A871d20913839c37f316Dc914b0570bfc0eE,
                    keccak256(abi.encodePacked("CHAINS_MANAGER")),
                    false
                );
            }

            vm.startBroadcast(key);
            console.log(" -- for Roles ", securityMultisig);
            IOwnable(rolesContract).transferOwnership(securityMultisig);

            vm.stopBroadcast();
            console.log("-------------------- DONE");
        }
    }
}
