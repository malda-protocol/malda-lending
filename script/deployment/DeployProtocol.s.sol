// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {DeployBase} from "script/deployers/DeployBase.sol";
import {Deployer} from "src/utils/Deployer.sol";

import {DeployRbac} from "./generic/DeployRbac.s.sol";
import {DeployUnit} from "./generic/DeployUnit.s.sol";
import {DeployPauser} from "./generic/DeployPauser.s.sol";
import {DeployOperator} from "./markets/DeployOperator.s.sol";
import {DeployHostMarket} from "./markets/host/DeployHostMarket.s.sol";
import {DeployExtensionMarket} from "./markets/extension/DeployExtensionMarket.s.sol";
import {DeployJumpRateModelV4} from "./interest/DeployJumpRateModelV4.s.sol";
import {DeployChainlinkOracle} from "./oracles/DeployChainlinkOracle.s.sol";
import {DeployRewardDistributor} from "./rewards/DeployRewardDistributor.s.sol";
import {ChainConfig, OracleConfig} from "../deployers/Types.sol";
import {Operator} from "src/operator/Operator.sol";
import {BatchSubmitter} from "src/mToken/BatchSubmitter.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {Roles} from "src/Roles.sol";
import {JumpRateModelV4} from "src/interest/JumpRateModelV4.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Unit} from "src/operator/Unit.sol";
import {DeployMixedPriceOracleV3} from "./oracles/DeployMixedPriceOracleV3.s.sol";

contract DeployProtocol is Script, DeployBase {
    using stdJson for string;

    error UnsupportedOracleType();
    error ChainNotFound();
    error HostChainNotConfigured();

    struct DeploymentConfig {
        address owner;
        string salt;
        address hostChainId;
        ZkVerifier zkVerifier;
    }

    struct Market {
        address underlying;
        string name;
        string symbol;
        uint8 decimals;
        address priceFeed;
        InterestConfig interestModel;
        uint256 collateralFactor;
        uint256 borrowCap;
        uint256 supplyCap;
    }

    struct InterestConfig {
        string name;
        uint256 baseRate;
        uint256 multiplier;
        uint256 jumpMultiplier;
        uint256 kink;
        uint256 blocksPerYear;
    }

    struct Role {
        bytes32 role;
        address[] accounts;
    }

    struct ZkVerifier {
        address verifierAddress;
        bytes32 imageId;
    }

    DeploymentConfig internal config;
    mapping(address => address) public marketAddresses; // underlying => market address
    
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

    function setUp() public override {
        uint256 ownerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        OWNER = vm.addr(ownerPrivateKey);
        
        string memory json = vm.readFile("deployment-config.json");
        
        console.log("Parsing markets");
        
        // Parse each market individually
        Market memory market;
        market.underlying = abi.decode(json.parseRaw(".markets[0].underlying"), (address));
        market.name = abi.decode(json.parseRaw(".markets[0].name"), (string));
        market.symbol = abi.decode(json.parseRaw(".markets[0].symbol"), (string));
        market.decimals = uint8(abi.decode(json.parseRaw(".markets[0].decimals"), (uint256)));
        market.priceFeed = abi.decode(json.parseRaw(".markets[0].priceFeed"), (address));
        
        // Parse interest model
        market.interestModel.name = abi.decode(json.parseRaw(".markets[0].interestModel.name"), (string));
        market.interestModel.baseRate = abi.decode(json.parseRaw(".markets[0].interestModel.baseRate"), (uint256));
        market.interestModel.multiplier = abi.decode(json.parseRaw(".markets[0].interestModel.multiplier"), (uint256));
        market.interestModel.jumpMultiplier = abi.decode(json.parseRaw(".markets[0].interestModel.jumpMultiplier"), (uint256));
        market.interestModel.kink = abi.decode(json.parseRaw(".markets[0].interestModel.kink"), (uint256));
        market.interestModel.blocksPerYear = abi.decode(json.parseRaw(".markets[0].interestModel.blocksPerYear"), (uint256));
        
        market.collateralFactor = abi.decode(json.parseRaw(".markets[0].collateralFactor"), (uint256));
        market.borrowCap = abi.decode(json.parseRaw(".markets[0].borrowCap"), (uint256));
        market.supplyCap = abi.decode(json.parseRaw(".markets[0].supplyCap"), (uint256));
        
        // Store market
        marketsLength = 1;
        markets[0] = market;
        
        console.log("Market parsed: %s", market.name);
        
        console.log("Parsing roles");
        
        // Parse roles individually
        rolesLength = 4; // We know there are 4 roles
        for (uint i = 0; i < rolesLength; i++) {
            string memory path = string.concat(".roles[", vm.toString(i), "]");
            Role memory role;
            role.role = abi.decode(json.parseRaw(string.concat(path, ".role")), (bytes32));
            
            // Parse accounts array
            bytes memory accountsRaw = json.parseRaw(string.concat(path, ".accounts"));
            address[] memory accounts = abi.decode(accountsRaw, (address[]));
            role.accounts = accounts;
            
            roles[i] = role;
            console.log("Role %s parsed", i);
        }

        console.log("Roles parsed");
        
        console.log("Parsing config");
        
        // Parse config fields individually
        config.owner = abi.decode(json.parseRaw(".deployer.owner"), (address));
        config.salt = abi.decode(json.parseRaw(".deployer.salt"), (string));
        config.hostChainId = abi.decode(json.parseRaw(".hostChainId"), (address));
        
        // Parse zkVerifier fields individually
        config.zkVerifier.verifierAddress = abi.decode(json.parseRaw(".zkVerifier.verifierAddress"), (address));
        config.zkVerifier.imageId = abi.decode(json.parseRaw(".zkVerifier.imageId"), (bytes32));
        
        console.log("Config parsed");
        console.log("ZkVerifier address:", config.zkVerifier.verifierAddress);
        console.logBytes32(config.zkVerifier.imageId);
        
        super.setUp();
    }

    function run() public {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(key);

        // Deploy core protocol contracts on host chain
        vm.stopBroadcast();
        address rolesContract = _deployRoles();
        console.log("Debug");
        address rewardDistributor = _deployRewardDistributor();
        address oracle = _deployOracle(hostChain.oracle, rolesContract);
        address operator = _deployOperator(oracle, rewardDistributor, rolesContract);
        _deployPauser(rolesContract, operator);

        vm.startBroadcast(key);
        // Deploy market implementations once
        mTokenHostImplementation = _deployMTokenHostImplementation();
        mTokenGatewayImplementation = _deployMTokenGatewayImplementation();

        require(mTokenHostImplementation != address(0), "Host implementation deployment failed");
        console.log("Host implementation ready at:", mTokenHostImplementation);

        console.log("Configuring");
        // Deploy markets on host chain
        for (uint i = 0; i < marketsLength; i++) {
            Market memory market = markets[i];
            _deployAndConfigureMarket(true, market, operator, rolesContract, mTokenHostImplementation);
        }

        // Set up roles on host chain
        _setupRoles(rolesContract);
        
        // Stop broadcast before switching chains
        vm.stopBroadcast();

        // Now deploy to extension chains
        for (uint i = 0; i < chainsLength; i++) {
            ChainConfig memory chain = chains[i];
            if (!chain.isHost) {
                // Switch to extension chain
                vm.createSelectFork(vm.rpcUrl(chain.rpcAlias));
                
                vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));

                // Deploy minimal required contracts
                address extensionRoles = _deployRoles();
                
                // Deploy markets on extension chain
                for (uint j = 0; j < marketsLength; j++) {
                    Market memory market = markets[j];
                    _deployAndConfigureMarket(false, market, address(0), extensionRoles, mTokenGatewayImplementation);
                }

                // Set up roles on extension chain
                _setupRoles(extensionRoles);
                
                // Stop broadcast before next iteration
                vm.stopBroadcast();
            }
        }
    }

    function _deployMTokenHostImplementation() internal returns (address) {
        bytes32 salt = getSalt("mTokenHost-implementation");
        address impl = deployer.create(
            salt,
            type(mErc20Host).creationCode
        );
        console.log("Host implementation deployed at:", impl);
        return impl;
    }

    function _deployMTokenGatewayImplementation() internal returns (address) {
        bytes32 salt = getSalt("mTokenGateway-implementation");
        return deployer.create(
            salt,
            type(mTokenGateway).creationCode
        );
    }

    function _deployAndConfigureMarket(
        bool isHost,
        Market memory market,
        address operator,
        address rolesContract,
        address marketImplementation
    ) internal {
        address marketAddress;
        address interestModel;

        // Deploy interest model only for host chain
        if (isHost) {
            interestModel = _deployInterestModel(market.interestModel);
            uint256 key = vm.envUint("OWNER_PRIVATE_KEY");
            vm.startBroadcast(key);
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
                config.zkVerifier.verifierAddress,
                rolesContract
            );

            console.log("Underlying:", market.underlying);
            console.log("Operator:", operator);
            console.log("Interest model:", interestModel);
            console.log("Exchange rate mantissa:", uint256(1e18));
            console.log("Name:", market.name);
            console.log("Symbol:", market.symbol);
            console.log("Decimals:", market.decimals);
            console.log("Owner:", OWNER);
            console.log("Verifier:", config.zkVerifier.verifierAddress);
            console.log("Roles:", rolesContract);

            // Deploy proxy
            bytes32 proxySalt = getSalt(market.name);
            console.log("Deploying market");
            marketAddress = deployer.create(
                proxySalt,
                abi.encodePacked(
                    type(ERC1967Proxy).creationCode,
                    abi.encode(marketImplementation, initData)
                )
            );
            console.log("Market deployed at:", marketAddress);
        } else {
            // Prepare initialization data
            bytes memory initData = abi.encodeWithSelector(
                mTokenGateway.initialize.selector,
                payable(OWNER),
                market.underlying,
                rolesContract,
                config.zkVerifier.verifierAddress
            );

            // Deploy proxy
            bytes32 proxySalt = getSalt(string.concat(
                "mTokenGatewayProxy", 
                string(abi.encodePacked(market.underlying))
            ));
            marketAddress = deployer.create(
                proxySalt,
                abi.encodePacked(
                    type(ERC1967Proxy).creationCode,
                    abi.encode(marketImplementation, initData)
                )
            );
        }

        // Configure market if host chain
        if (isHost) {
            _configureMarket(
                operator,
                marketAddress,
                market.collateralFactor,
                market.borrowCap,
                market.supplyCap
            );
        }

        marketAddresses[market.underlying] = marketAddress;

        // Additional initialization
        if (isHost) {
            // Setup allowed chains on host market
            _setupChainConnections(marketAddress);
        }

        // Setup ZK verification image ID
        _setupZkImageId(
            marketAddress,
            config.zkVerifier.verifierAddress,
            config.zkVerifier.imageId,
            isHost
        );
    }

    function _isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    function _deployRoles() internal returns (address) {
        DeployRbac deployRbac = new DeployRbac();
        address returnedRoles = deployRbac.run(deployer);
        console.log("Roles deployed at:", returnedRoles);
        return returnedRoles;
    }

    function _deployRewardDistributor() internal returns (address) {
        DeployRewardDistributor deployReward = new DeployRewardDistributor();
        return deployReward.run(deployer);
    }

    function _deployOracle(OracleConfig memory oracleConfig, address rolesContract) internal returns (address) {
        if (keccak256(bytes(oracleConfig.oracleType)) == keccak256(bytes("Chainlink"))) {
            DeployMixedPriceOracleV3 deployOracle = new DeployMixedPriceOracleV3();
            return deployOracle.run(
                deployer,
                oracleConfig.usdcFeed,
                oracleConfig.wethFeed,
                rolesContract,
                oracleConfig.stalenessPeriod
            );
        }
        revert UnsupportedOracleType();
    }

    function _deployOperator(
        address oracle,
        address rewardDistributor,
        address rolesContract
    ) internal returns (address) {
        DeployOperator deployOperator = new DeployOperator();
        return deployOperator.run(deployer, oracle, rewardDistributor, rolesContract);
    }

    function _deployPauser(address rolesContract, address operator) internal {
        DeployPauser deployPauser = new DeployPauser();
        deployPauser.run(deployer, rolesContract, operator);
    }

    function _deployInterestModel(InterestConfig memory modelConfig) internal returns (address) {
        vm.stopBroadcast();
        DeployJumpRateModelV4 deployInterest = new DeployJumpRateModelV4();
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
        address rolesContract
    ) internal returns (address) {
        if (isHost) {
            DeployHostMarket deployHost = new DeployHostMarket();
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
                    zkVerifier: address(0), // Set actual verifier
                    roles: rolesContract
                })
            );
        } else {
            DeployExtensionMarket deployExt = new DeployExtensionMarket();
            return deployExt.run(
                deployer,
                DeployExtensionMarket.GatewayData({
                    underlyingToken: market.underlying,
                    roles: rolesContract,
                    zkVerifier: config.zkVerifier.verifierAddress
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
        Operator(operator).supportMarket(market);

        // Set collateral factor
        Operator(operator).setCollateralFactor(market, collateralFactor);

        // Set caps
        address[] memory marketAddrs = new address[](1);  // Renamed to avoid shadowing
        uint256[] memory caps = new uint256[](1);
        marketAddrs[0] = market;

        // Set borrow cap
        caps[0] = borrowCap;
        Operator(operator).setMarketBorrowCaps(marketAddrs, caps);

        // Set supply cap
        caps[0] = supplyCap;
        Operator(operator).setMarketSupplyCaps(marketAddrs, caps);
    }

    function _setupRoles(address rolesContract) internal {
        for (uint256 i = 0; i < rolesLength; i++) {
            Role memory role = roles[i];
            for (uint256 j = 0; j < role.accounts.length; j++) {
                Roles(rolesContract).allowFor(role.accounts[j], role.role, true);
            }
        }
    }

    function _setupChainConnections(address market) internal {
        // Allow chains in host market
        for (uint i = 0; i < chainsLength; i++) {
            ChainConfig memory chain = chains[i];
            if (!chain.isHost) {
                mErc20Host(market).updateAllowedChain(chain.id, true);
            }
        }
    }

    function _setupZkImageId(
        address market, 
        address batchSubmitter,
        bytes32 imageId,
        bool isHost
    ) internal {
        // Set image ID for batch submitter
        BatchSubmitter(batchSubmitter).setImageId(imageId);
        
        // Set image ID for market
        if (isHost) {
            mErc20Host(market).setImageId(imageId);
        } else {
            mTokenGateway(market).setImageId(imageId);
        }
    }
} 