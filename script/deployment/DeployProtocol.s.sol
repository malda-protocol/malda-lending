// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {DeployBase} from "../deployers/DeployBase.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {DeployConfig, Market, Role, InterestConfig} from "../deployers/Types.sol";
import {DeployDeployer} from "../deployers/DeployDeployer.s.sol";
import {DeployRbac} from "./generic/DeployRbac.s.sol";
import {DeployPauser} from "./generic/DeployPauser.s.sol";
import {DeployOperator} from "./markets/DeployOperator.s.sol";
import {DeployHostMarket} from "./markets/host/DeployHostMarket.s.sol";
import {DeployExtensionMarket} from "./markets/extension/DeployExtensionMarket.s.sol";
import {DeployJumpRateModelV4} from "./interest/DeployJumpRateModelV4.s.sol";
import {DeployRewardDistributor} from "./rewards/DeployRewardDistributor.s.sol";
import {OracleConfig} from "../deployers/Types.sol";
import {Operator} from "src/Operator/Operator.sol";
import {BatchSubmitter} from "src/mToken/BatchSubmitter.sol";
import {DeployBatchSubmitter} from "./generic/DeployBatchSubmitter.s.sol";
import {RewardDistributor} from "src/rewards/RewardDistributor.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {Roles} from "src/Roles.sol";
import {JumpRateModelV4} from "src/interest/JumpRateModelV4.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DeployMixedPriceOracleV3} from "./oracles/DeployMixedPriceOracleV3.s.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {mTokenConfiguration} from "src/mToken/mTokenConfiguration.sol";
// import {VerifyDeployment} from "./VerifyDeployment.s.sol";

contract DeployProtocol is DeployBase {
    using stdJson for string;

    error UnsupportedOracleType();

    address marketAddress;
    address interestModel;

    // Track deployed implementations
    address public mTokenHostImplementation;
    address public mTokenGatewayImplementation;

    Deployer deployer;

    DeployDeployer deployDeployer;
    DeployRbac deployRbac;
    DeployBatchSubmitter deployBatchSubmitter;
    DeployJumpRateModelV4 deployInterest;
    DeployOperator deployOperator;
    DeployPauser deployPauser;
    DeployMixedPriceOracleV3 deployOracle;
    DeployRewardDistributor deployReward;
    DeployHostMarket deployHost;
    DeployExtensionMarket deployExt;

    function setUp() public override {
        super.setUp();
    }

    function run() public {
        string memory json = vm.readFile(configPath);
        string[] memory networks = vm.parseJsonKeys(json, ".networks");

        // Deploy to all networks
        for (uint256 i = 0; i < networks.length; i++) {
            string memory network = networks[i];
            console.log("\n=== Deploying to %s ===", network);

            // Create fork for this network
            forks[network] = vm.createSelectFork(network);

            deployDeployer = new DeployDeployer();
            deployRbac = new DeployRbac();
            deployBatchSubmitter = new DeployBatchSubmitter();

            deployer = Deployer(payable(_deployDeployer(network)));
            address rolesContract = _deployRoles();
            address batchSubmitter =
                _deployBatchSubmitter(rolesContract, configs[network].zkVerifier.verifierAddress);

            if (configs[network].isHost) {
                deployInterest = new DeployJumpRateModelV4();
                deployOperator = new DeployOperator();
                deployPauser = new DeployPauser();
                deployOracle = new DeployMixedPriceOracleV3();
                deployReward = new DeployRewardDistributor();
                deployHost = new DeployHostMarket();

                console.log("Deploying host chain configuration");
                _deployHostChain(network, rolesContract, batchSubmitter);
            } else {
                deployExt = new DeployExtensionMarket();
                console.log("Deploying extension chain configuration");
                _deployExtensionChain(network, rolesContract, batchSubmitter);
            }
        }

        // VerifyDeployment verifier = new VerifyDeployment();
        // verifier.run();
        
        // console.log("\n=== Deployment verification completed successfully ===");
    }

    function _deployHostChain(string memory network, address rolesContract, address batchSubmitter) internal {
        address rewardDistributor = _deployRewardDistributor();
        address oracle = _deployOracle(configs[network].oracle, rolesContract);
        address operator = _deployOperator(oracle, rewardDistributor, rolesContract);
        _deployPauser(rolesContract, operator);

        _setOperatorInRewardDistributor(operator, rewardDistributor);

        // Setup roles and chain connections
        _setupRoles(rolesContract, network);

        // Deploy and configure markets
        mTokenHostImplementation = _deployMTokenHostImplementation();
        uint256 marketsLength = configs[network].markets.length;
        for (uint256 i = 0; i < marketsLength; i++) {
            _deployAndConfigureMarket(
                true,
                configs[network].markets[i],
                operator,
                rolesContract,
                mTokenHostImplementation,
                network,
                batchSubmitter
            );
        }
    }

    function _deployExtensionChain(string memory network, address rolesContract, address batchSubmitter) internal {
        mTokenGatewayImplementation = _deployMTokenGatewayImplementation();

        uint256 marketsLength = configs[network].markets.length;
        for (uint256 i = 0; i < marketsLength; i++) {
            _deployAndConfigureMarket(
                false,
                configs[network].markets[i],
                address(0),
                rolesContract,
                mTokenGatewayImplementation,
                network,
                batchSubmitter
            );
        }

        _setupRoles(rolesContract, network);
    }

    function _deployMTokenHostImplementation() internal returns (address) {
        bytes32 salt = getSalt("mTokenHost-implementation");
        vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));
        address impl = deployer.create(salt, abi.encodePacked(type(mErc20Host).creationCode));
        vm.stopBroadcast();
        console.log("Host implementation deployed at:", impl);
        return impl;
    }

    function _deployMTokenGatewayImplementation() internal returns (address) {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");

        bytes32 salt = getSalt("mTokenGateway-implementation");
        vm.startBroadcast(key);
        address impl = deployer.create(salt, type(mTokenGateway).creationCode);
        vm.stopBroadcast();

        return impl;
    }

    function _deployAndConfigureMarket(
        bool isHost,
        Market memory market,
        address operator,
        address rolesContract,
        address marketImplementation,
        string memory network,
        address batchSubmitter
    ) internal {
        // Deploy interest model only for host chain
        if (isHost) {
            console.log("Deploying interest model");
            interestModel = _deployInterestModel(market.interestModel);
        }

        // Deploy proxy for market
        if (isHost) {
            // Prepare initialization data
            bytes memory initData = abi.encodeWithSelector(
                mErc20Host.initialize.selector,
                market.underlying,
                operator,
                interestModel,
                uint256(1e18), // exchangeRateMantissa
                market.name,
                market.symbol,
                market.decimals,
                payable(configs[network].deployer.owner),
                configs[network].zkVerifier.verifierAddress,
                rolesContract
            );
            console.log("Host implementation address:", marketImplementation);

            // Deploy proxy
            {
                bytes32 proxySalt = getSalt(market.name);
                console.log("Deploying market");
                vm.startBroadcast(key);
                marketAddress = deployer.create(
                    proxySalt,
                    abi.encodePacked(
                        type(TransparentUpgradeableProxy).creationCode,
                        abi.encode(marketImplementation, configs[network].deployer.owner, initData)
                    )
                );
                vm.stopBroadcast();
                console.log("Market deployed at:", marketAddress);
                console.logBytes32(
                    vm.load(marketAddress, bytes32(0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103))
                );
            }
        } else {
            console.log("Deploying gateway");
            // Prepare initialization data
            bytes memory initData = abi.encodeWithSelector(
                mTokenGateway.initialize.selector,
                payable(configs[network].deployer.owner),
                market.underlying,
                rolesContract,
                configs[network].zkVerifier.verifierAddress
            );
            console.log("Deploying proxy");

            console.log("Extension implementation address:", marketImplementation);
            // Deploy proxy
            {
                bytes32 proxySalt = getSalt(market.name);
                vm.startBroadcast(key);

                marketAddress = deployer.create(
                    proxySalt,
                    abi.encodePacked(
                        type(TransparentUpgradeableProxy).creationCode,
                        abi.encode(marketImplementation, configs[network].deployer.owner, initData)
                    )
                );
                vm.stopBroadcast();
            }

            console.log("Market deployed at:", marketAddress);
            console.logBytes32(
                vm.load(marketAddress, bytes32(0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103))
            );
        }

        // Configure market if host chain
        if (isHost) {
            console.log("Configuring market");
            _configureMarket(
                operator,
                marketAddress,
                market.collateralFactor,
                market.borrowCap,
                market.supplyCap,
                market.borrowRateMaxMantissa
            );
            console.log("Market configured");

            console.log("Setting up chain connections");
            // Setup allowed chains on host market
            _setupChainConnections(marketAddress, network);
            console.log("Chain connections set up");
        }

        // Setup ZK verification image ID
        console.log("Setting up ZK image ID");
        _setupZkImageId(marketAddress, batchSubmitter, configs[network].zkVerifier.imageId, isHost);
        console.log("ZK image ID set up");
    }

    function _deployDeployer(string memory network) internal returns (address) {
        return deployDeployer.run(configs[network].chainId, configs[network].deployer.owner, configs[network].deployer.salt);
    }

    function _deployRoles() internal returns (address) {
        console.log("Deploying roles");
        address returnedRoles = deployRbac.run(deployer);

        console.log("Roles deployed at:", returnedRoles);
        return returnedRoles;
    }

    function _deployBatchSubmitter(address rolesContract, address zkVerifier)
        internal
        returns (address)
    {
        console.log("Deploying batch submitter");
        address returnedBatchSubmitter = deployBatchSubmitter.run(deployer, rolesContract, zkVerifier);
        console.log("Batch submitter deployed at:", returnedBatchSubmitter);
        return returnedBatchSubmitter;
    }

    function _deployRewardDistributor() internal returns (address) {
        return deployReward.run(deployer);
    }

    function _deployOracle(OracleConfig memory oracleConfig, address rolesContract) internal returns (address) {
        return deployOracle.run(
            deployer, oracleConfig.usdcFeed, oracleConfig.wethFeed, rolesContract, oracleConfig.stalenessPeriod
        );
    }

    function _deployOperator(address oracle, address rewardDistributor, address rolesContract)
        internal
        returns (address)
    {
        return deployOperator.run(deployer, oracle, rewardDistributor, rolesContract);
    }

    function _deployPauser(address rolesContract, address operator) internal {
        deployPauser.run(deployer, rolesContract, operator);
    }

    function _deployInterestModel(InterestConfig memory modelConfig) internal returns (address) {
        return deployInterest.run(
            deployer,
            DeployJumpRateModelV4.InterestData({
                kink: modelConfig.kink,
                name: modelConfig.name,
                blocksPerYear: modelConfig.blocksPerYear,
                baseRatePerYear: modelConfig.baseRate,
                multiplierPerYear: modelConfig.multiplier,
                jumpMultiplierPerYear: modelConfig.jumpMultiplier
            })
        );
    }

    function _configureMarket(
        address operator,
        address market,
        uint256 collateralFactor,
        uint256 borrowCap,
        uint256 supplyCap,
        uint256 borrowRateMaxMantissa
    ) internal {

        // Support market
        console.log("Supporting market");
        vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));
        Operator(operator).supportMarket(market);
        vm.stopBroadcast();
        console.log("Market supported");

        // Set collateral factor
        console.log("Setting collateral factor");
        vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));
        Operator(operator).setCollateralFactor(market, collateralFactor);
        vm.stopBroadcast();
        console.log("Collateral factor set");

        // Set borrow rate max mantissa
        console.log("Setting borrow rate max mantissa");
        vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));
        (bool success, ) = market.call{gas: 120000}(abi.encodeWithSelector(mTokenConfiguration.setBorrowRateMaxMantissa.selector, borrowRateMaxMantissa));
        require(success, "Failed to set borrow rate max mantissa");
        vm.stopBroadcast();
        console.log("Borrow rate max mantissa set");

        // Set caps
        address[] memory marketAddrs = new address[](1);
        uint256[] memory caps = new uint256[](1);
        marketAddrs[0] = market;

        // Set borrow cap
        caps[0] = borrowCap;
        vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));
        Operator(operator).setMarketBorrowCaps(marketAddrs, caps);
        vm.stopBroadcast();

        // Set supply cap
        caps[0] = supplyCap;
        vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));
        Operator(operator).setMarketSupplyCaps(marketAddrs, caps);
        vm.stopBroadcast();
    }

    function _setupRoles(address rolesContract, string memory network) internal {
        uint256 rolesLength = configs[network].roles.length;
        for (uint256 i = 0; i < rolesLength; i++) {
            Role memory role = configs[network].roles[i];
            for (uint256 j = 0; j < role.accounts.length; j++) {
                vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));
                Roles(rolesContract).allowFor(role.accounts[j], keccak256(abi.encodePacked(role.roleName)), true);
                vm.stopBroadcast();
                console.log("Allowed %s for %s", role.accounts[j], role.roleName);
            }
        }
    }

    function _setupChainConnections(address market, string memory network) internal {
        // Allow chains in host market
        for (uint256 i = 0; i < configs[network].allowedChains.length; i++) {
            vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));
            mErc20Host(market).updateAllowedChain(configs[network].allowedChains[i], true);
            vm.stopBroadcast();
        }
    }

    function _setOperatorInRewardDistributor(address operator, address rewardDistributor) internal {
        vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));
        RewardDistributor(rewardDistributor).setOperator(operator);
        vm.stopBroadcast();
    }

    function _setupZkImageId(address market, address batchSubmitter, bytes32 imageId, bool isHost) internal {
        // Set image ID for batch submitter
        if(BatchSubmitter(batchSubmitter).imageId() != imageId) {
            vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));
            BatchSubmitter(batchSubmitter).setImageId(imageId);
            vm.stopBroadcast();
        }

        // Set image ID for market
        if (isHost) {
            vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));
            mErc20Host(market).setImageId(imageId);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));
            mTokenGateway(market).setImageId(imageId);
            vm.stopBroadcast();
        }
    }
}
