// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {DeployBaseRelease} from "../../deployers/DeployBaseRelease.sol";
import {DeployJumpRateModelV4} from "../interest/DeployJumpRateModelV4.s.sol";

import {MarketRelease, InterestConfig} from "../../deployers/Types.sol";

import {DeployHostMarket} from "../markets/host/DeployHostMarket.s.sol";
import {DeployExtensionMarket} from "../markets/extension/DeployExtensionMarket.s.sol";

// forge script DeployMarketsTestnet --slow
// forge script DeployMarketsTestnet --slow  --multi --verify --broadcast
contract DeployMarketsTestnet is DeployBaseRelease {
    using stdJson for string;

    address internal marketAddress;
    address internal owner;

    Deployer internal deployer;
    address internal rolesContract;
    address internal zkVerifier;
    address internal operator;
    address internal interestModel;
    address internal oracle;
    address internal pauser;
    address internal blacklister;

    DeployHostMarket internal deployHost;
    DeployExtensionMarket internal deployExt;
    DeployJumpRateModelV4 internal deployInterest;

    error ADDRESSES_NOT_SET();

    function setUp() public override {
        configPath = "deployment-config-testnet.json";
        super.setUp();

        // SET before running it! Available after `DeployerCoreTestnet`
        deployer = Deployer(payable(0x360a5443FeA41EA1C62bF0420863842B3f341735));
        rolesContract = 0xccC52e812224Cb1411668515B835913C8598Dbd8;
        zkVerifier = 0x0E3a778B1c2A15e93BEB44842bf4171FD5deA6cF;
        operator = 0x8A61Da8c8bD768598F8300E8E81341331F26d4d0;
        oracle = 0xd4E07fC4E6efe4B5cb44D0386ca731297918a8B4;
        pauser = 0x825AA423B88757CeEc452CB6d2d6Cd47897e7e2e;
        blacklister = 0x50dCbB8529F6a1c81dCfBCc0C36c3e2Be2CCf57C;
        // SET before running it ^!

        // check to make sure addresses were set
        if (
            oracle == address(0) || address(deployer) == address(0) || rolesContract == address(0)
                || zkVerifier == address(0) || operator == address(0) || pauser == address(0)
                || blacklister == address(0)
        ) {
            revert ADDRESSES_NOT_SET();
        }
    }

    function run() public {
        // Deploy to all networks
        for (uint256 i = 0; i < networks.length; i++) {
            string memory network = networks[i];
            console.log("\n=== Deploying to %s ===", network);

            // Create fork for this network
            forks[network] = vm.createSelectFork(network);

            owner = configs[network].deployer.owner;
            if (configs[network].isHost) {
                deployHost = new DeployHostMarket();
                deployInterest = new DeployJumpRateModelV4();
                console.log("Deploying host chain");
                _deployHostChain(network);
            } else {
                deployExt = new DeployExtensionMarket();
                console.log("Deploying extension chain");
                _deployExtensionChain(network);
            }

            console.log("-------------------- DONE");
        }
    }

    function _deployHostChain(string memory network) internal {
        uint256 marketsLength = configs[network].markets.length;
        for (uint256 i; i < marketsLength;) {
            _deployMarketOnNetwork(true, configs[network].markets[i], network);
            unchecked {
                ++i;
            }
        }
    }

    function _deployExtensionChain(string memory network) internal {
        uint256 marketsLength = configs[network].markets.length;
        for (uint256 i; i < marketsLength;) {
            _deployMarketOnNetwork(false, configs[network].markets[i], network);
            unchecked {
                ++i;
            }
        }

        //
    }

    function _deployMarketOnNetwork(bool isHost, MarketRelease memory market, string memory network) internal {
        // Deploy proxy for market
        if (isHost) {
            interestModel = _deployInterestModel(market.interestModel);

            marketAddress = _deployHostMarket(market);
            // Setup allowed chains on host market
            _updateAllowedChains(marketAddress, network);
        } else {
            marketAddress = _deployExtensionMarket(market);
        }
    }

    function _deployHostMarket(MarketRelease memory market) internal returns (address) {
        return deployHost.run(
            deployer,
            DeployHostMarket.MarketData({
                underlyingToken: market.underlying,
                operator: operator,
                interestModel: interestModel,
                exchangeRateMantissa: uint256(2e16),
                name: market.name,
                symbol: market.symbol,
                decimals: market.decimals,
                owner: owner,
                zkVerifier: zkVerifier,
                roles: rolesContract
            })
        );
    }

    function _deployExtensionMarket(MarketRelease memory market) internal returns (address) {
        return deployExt.run(deployer, blacklister, market.underlying, market.name, owner, zkVerifier, rolesContract);
    }

    function _updateAllowedChains(address market, string memory network) internal {
        // Allow chains in host market
        for (uint256 i = 0; i < configs[network].allowedChains.length; i++) {
            vm.startBroadcast(key);
            mErc20Host(market).updateAllowedChain(configs[network].allowedChains[i], true);
            vm.stopBroadcast();
        }
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
            }),
            owner
        );
    }
}
