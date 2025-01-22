// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {DeployBase} from "../deployers/DeployBase.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {DeployConfig, Market, Role, InterestConfig} from "../deployers/Types.sol";

import {DeployRbac} from "./generic/DeployRbac.s.sol";
import {DeployPauser} from "./generic/DeployPauser.s.sol";
import {DeployOperator} from "./markets/DeployOperator.s.sol";
import {DeployHostMarket} from "./markets/host/DeployHostMarket.s.sol";
import {DeployExtensionMarket} from "./markets/extension/DeployExtensionMarket.s.sol";
import {DeployJumpRateModelV4} from "./interest/DeployJumpRateModelV4.s.sol";
import {DeployRewardDistributor} from "./rewards/DeployRewardDistributor.s.sol";
import {OracleConfig} from "../deployers/Types.sol";
import {Operator} from "src/operator/Operator.sol";
import {BatchSubmitter} from "src/mToken/BatchSubmitter.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {Roles} from "src/Roles.sol";
import {JumpRateModelV4} from "src/interest/JumpRateModelV4.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DeployMixedPriceOracleV3} from "./oracles/DeployMixedPriceOracleV3.s.sol";

contract DeployProtocol is DeployBase {
    using stdJson for string;

    error UnsupportedOracleType();

    // Store markets in mapping
    uint256 public marketsLength;
    mapping(uint256 => Market) public markets;

    // Store roles in mapping
    uint256 public rolesLength;
    mapping(uint256 => Role) public roles;

    // Track deployed implementations
    address public mTokenHostImplementation;
    address public mTokenGatewayImplementation;

    address public OWNER;

    DeployRbac deployRbac;
    DeployJumpRateModelV4 deployInterest;
    DeployOperator deployOperator;
    DeployPauser deployPauser;
    DeployMixedPriceOracleV3 deployOracle;
    DeployRewardDistributor deployReward;
    DeployHostMarket deployHost;
    DeployExtensionMarket deployExt;

    function setUp() public override {
        super.setUp();
        deployRbac = new DeployRbac();
        deployInterest = new DeployJumpRateModelV4();
        deployOperator = new DeployOperator();
        deployPauser = new DeployPauser();
        deployOracle = new DeployMixedPriceOracleV3();
        deployReward = new DeployRewardDistributor();
        deployHost = new DeployHostMarket();
        deployExt = new DeployExtensionMarket();
    }

    function run() public {
        string memory json = vm.readFile(configPath);
        string[] memory networks = vm.parseJsonKeys(json, ".networks");

        // Deploy to all networks
        for (uint256 i = 0; i < networks.length; i++) {
            string memory network = networks[i];
            console.log("\n=== Deploying to %s ===", network);

            // Create fork for this network
            vm.createSelectFork(vm.rpcUrl(network));

            address rolesContract = _deployRoles();

            if (configs[network].isHost) {
                console.log("Deploying host chain configuration");
                _deployHostChain(network, rolesContract);
            } else {
                console.log("Deploying extension chain configuration");
                _deployExtensionChain(network, rolesContract);
            }
        }
    }

    function _deployHostChain(string memory network, address rolesContract) internal {
        address rewardDistributor = _deployRewardDistributor();
        address oracle = _deployOracle(configs[network].oracle, rolesContract);
        address operator = _deployOperator(oracle, rewardDistributor, rolesContract);
        _deployPauser(rolesContract, operator);

        // Deploy and configure markets
        mTokenHostImplementation = _deployMTokenHostImplementation();
        for (uint256 i = 0; i < marketsLength; i++) {
            _deployAndConfigureMarket(true, configs[network].markets[i], operator, rolesContract, mTokenHostImplementation, network);
        }

        // Setup roles and chain connections
        _setupRoles(rolesContract);
    }

    function _deployExtensionChain(string memory network, address rolesContract) internal {
        mTokenGatewayImplementation = _deployMTokenGatewayImplementation();

        for (uint256 i = 0; i < marketsLength; i++) {
            _deployAndConfigureMarket(false, configs[network].markets[i], address(0), rolesContract, mTokenGatewayImplementation, network);
        }

        _setupRoles(rolesContract);
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
        uint256 currentNonce = vm.getNonce(vm.addr(key));
        console.log("Starting nonce for gateway implementation:", currentNonce);

        bytes32 salt = getSalt("mTokenGateway-implementation");
        vm.startBroadcast(key);
        address impl = deployer.create(salt, type(mTokenGateway).creationCode);
        vm.stopBroadcast();

        uint64 newNonce = vm.getNonce(vm.addr(key));
        console.log("Nonce after gateway implementation:", newNonce);
        vm.setNonce(vm.addr(key), newNonce);
        return impl;
    }

    function _deployAndConfigureMarket(
        bool isHost,
        Market memory market,
        address operator,
        address rolesContract,
        address marketImplementation,
        string memory network
    ) internal {
        address marketAddress;
        address interestModel;

        // Deploy interest model only for host chain
        if (isHost) {
            console.log("Deploying interest model");
            interestModel = _deployInterestModel(market.interestModel);
        }

        console.log("configuring");

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
                payable(OWNER),
                configs[network].zkVerifier.verifierAddress,
                rolesContract
            );
            console.log("Host implementation address:", marketImplementation);

            // Deploy proxy
            bytes32 proxySalt = getSalt(market.name);
            console.log("Deploying market");
            vm.startBroadcast(key);
            marketAddress = deployer.create(
                proxySalt, abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(marketImplementation, initData))
            );
            vm.stopBroadcast();
            console.log("Market deployed at:", marketAddress);
        } else {
            console.log("Deploying gateway");
            // Prepare initialization data
            bytes memory initData = abi.encodeWithSelector(
                mTokenGateway.initialize.selector,
                payable(OWNER),
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
                    abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(marketImplementation, initData))
                );
                vm.stopBroadcast();
            }

            console.log("Market deployed at:", marketAddress);
        }

        // Configure market if host chain
        if (isHost) {
            console.log("Configuring market");
            _configureMarket(operator, marketAddress, market.collateralFactor, market.borrowCap, market.supplyCap);
            console.log("Market configured");
        }

        // Additional initialization
        if (isHost) {
            console.log("Setting up chain connections");
            // Setup allowed chains on host market
            _setupChainConnections(marketAddress, network);
            console.log("Chain connections set up");
        }

        // Setup ZK verification image ID
        console.log("Setting up ZK image ID");
        // _setupZkImageId(
        //     marketAddress,
        //     config.zkVerifier.verifierAddress,
        //     config.zkVerifier.imageId,
        //     isHost
        // );
        console.log("ZK image ID set up");
        uint64 newNonce = vm.getNonce(vm.addr(key));
        console.log("Nonce after market deployment:", newNonce);
        vm.setNonce(vm.addr(key), newNonce);
    }

    function _deployRoles() internal returns (address) {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");
        uint256 currentNonce = vm.getNonce(vm.addr(key));
        console.log("Starting nonce for roles deployment:", currentNonce);

        address returnedRoles = deployRbac.run(deployer);

        uint64 newNonce = vm.getNonce(vm.addr(key));
        console.log("Nonce after roles deployment:", newNonce);
        vm.setNonce(vm.addr(key), newNonce);

        console.log("Roles deployed at:", returnedRoles);
        return returnedRoles;
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

    function _deployMarket(
        bool isHost,
        Market memory market,
        address operator,
        address interestModel,
        address rolesContract,
        string memory network
    ) internal returns (address) {
        if (isHost) {
            return deployHost.run(
                deployer,
                DeployHostMarket.MarketData({
                    underlyingToken: market.underlying,
                    operator: operator,
                    interestModel: interestModel,
                    exchangeRateMantissa: 1e18,
                    name: market.name,
                    symbol: market.symbol,
                    decimals: market.decimals,
                    zkVerifier: configs[network].zkVerifier.verifierAddress,
                    roles: rolesContract
                })
            );
        } else {
            return deployExt.run(
                deployer,
                DeployExtensionMarket.GatewayData({
                    underlyingToken: market.underlying,
                    roles: rolesContract,
                    zkVerifier: configs[network].zkVerifier.verifierAddress
                })
            );
        }
    }

    function _configureMarket(
        address operator,
        address market,
        uint256 collateralFactor,
        uint256 borrowCap,
        uint256 supplyCap
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

        // Set caps
        address[] memory marketAddrs = new address[](1); // Renamed to avoid shadowing
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

    function _setupRoles(address rolesContract) internal {
        vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));
        for (uint256 i = 0; i < rolesLength; i++) {
            Role memory role = roles[i];
            for (uint256 j = 0; j < role.accounts.length; j++) {
                Roles(rolesContract).allowFor(role.accounts[j], role.role, true);
            }
        }
        vm.stopBroadcast();
    }

    function _setupChainConnections(address market, string memory network) internal {
        vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));
        // Allow chains in host market
        for (uint256 i = 0; i < configs[network].allowedChains.length; i++) {
            mErc20Host(market).updateAllowedChain(configs[network].allowedChains[i], true);
        }
        vm.stopBroadcast();
    }

    function _setupZkImageId(address market, address batchSubmitter, bytes32 imageId, bool isHost) internal {
        // Set image ID for batch submitter
        vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));
        BatchSubmitter(batchSubmitter).setImageId(imageId);
        vm.stopBroadcast();

        // Set image ID for market
        vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));
        if (isHost) {
            mErc20Host(market).setImageId(imageId);
        } else {
            mTokenGateway(market).setImageId(imageId);
        }
        vm.stopBroadcast();
    }
}
