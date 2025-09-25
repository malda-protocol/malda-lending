// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Operator} from "src/Operator/Operator.sol";
import {BatchSubmitter} from "src/mToken/BatchSubmitter.sol";
import {Roles} from "src/Roles.sol";
import {Pauser} from "src/pauser/Pauser.sol";
import {IOwnable} from "src/interfaces/IOwnable.sol";

import {
    DeployConfig,
    MarketRelease,
    Role,
    InterestConfig,
    OracleConfigRelease,
    OracleFeed
} from "../../deployers/Types.sol";

import {DeployBaseRelease} from "../../deployers/DeployBaseRelease.sol";

interface IAdmin {
    function setPendingAdmin(address newAdmin) external;
}

interface ISafeModule {
    function setMaster(address newAdmin) external;
}

contract TransferReleaseOwnership is DeployBaseRelease {
    using stdJson for string;

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
    address safeModule = 0x923b1e0e129fac8949d6d0c8c2f932be4b055637;

    function setUp() public override {
        configPath = "deployment-config-release.json";
        super.setUp();

        string memory marketsOutputPath = "script/output/release-deployed-market-addresses.json";
        string memory rawMarketJson = vm.readFile(marketsOutputPath);
        uint256 length = vm.parseJson(rawMarketJson, "").length;
        marketList = new address[](length);
        for (uint256 i; i < length; ++i) {
            string memory base = string.concat("[", vm.toString(i), "]");

            address marketAddr = vm.parseJsonAddress(rawMarketJson, string.concat(base, ".address"));
            marketList.push(marketAddr);
        }

        string memory corePath = "script/output/release-deployed-core-addresses.json";
        pauser = vm.parseJsonAddress(corePath, ".Pauser");
        batchSubmitter = vm.parseJsonAddress(corePath, ".BatchSubmitter");
        rewardDistributor = vm.parseJsonAddress(corePath, ".RewardDistributor");
        zkVerifier = vm.parseJsonAddress(corePath, ".ZkVerifier");
        rolesContract = vm.parseJsonAddress(corePath, ".Roles");
        operator = vm.parseJsonAddress(corePath, ".Operator");
        deployer = vm.parseJsonAddress(corePath, ".Deployer");
        gasHelper = vm.parseJsonAddress(corePath, ".DefaultGasHelper");
    }

    function run() public {
        // ------------------
        // ------------------
        // ------------------
        // ------------------
        // ------------- OWNER TO SET -----------
        address owner = 0x91B945CbB063648C44271868a7A0c7BdFf64827D; ///// SET!!!!
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
            console.log("Transfer ownership to", owner);

            console.log(" -- for Deployer ", owner);
            IAdmin(deployer).setPendingAdmin(owner);
            console.log(" -- for Pauser ", owner);
            IOwnable(pauser).transferOwnership(owner);
            console.log(" -- for BatchSubmitter ", owner);
            IOwnable(batchSubmitter).transferOwnership(owner);
            console.log(" -- for RewardDistributor ", owner);
            IOwnable(rewardDistributor).transferOwnership(owner);
            console.log(" -- for ZkVerifier ", owner);
            IOwnable(zkVerifier).transferOwnership(owner);
            console.log(" -- for Roles ", owner);
            IOwnable(rolesContract).transferOwnership(owner);
            if (configs[network].isHost) {
                console.log(" HOST");
                console.log(" -- for Operator ", owner);
                IOwnable(operator).transferOwnership(owner);
                console.log(" -- for DefaultGasHelper ", owner);
                IOwnable(gasHelper).transferOwnership(owner);
                console.log(" -- for all host markets ", owner);
                for (uint256 j; j < marketList.length; ++j) {
                    console.log(" -- for market: ", marketList[i]);
                    IAdmin(marketList[j]).setPendingAdmin(owner);
                }
                ISafeModule(safeModule).setMaster(newAdmin);

            } else {
                console.log(" EXTENSION");
                console.log(" -- for all extension markets ", owner);
                for (uint256 j; j < marketList.length; ++j) {
                    console.log(" -- for market: ", marketList[j]);
                    IOwnable(marketList[j]).transferOwnership(owner);
                }
            }

            vm.stopBroadcast();
            console.log("-------------------- DONE");
        }
    }
}
