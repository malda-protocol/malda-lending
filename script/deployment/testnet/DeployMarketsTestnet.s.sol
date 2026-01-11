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
        deployer = Deployer(payable(0x6F6cA5F50B6b99a7298B4b7fE7E4Daa1f90552a2));
        rolesContract = 0xF7731a207D6F1423231Fe7fF80DaF4D9fa95a879;
        zkVerifier = 0xF2F6D7F7679eEB50284633B0851D7B1Af9E33ce9;
        operator = 0x3fbe703927ADDF1d950edC03D89D8886645532Af;
        oracle = 0xd9BD603C04371F2C8734e728E76AC88fAb2d45a0;
        pauser = 0x26D4830769b00774d033aAb92e4Ba07Ee8260a7e;
        blacklister = 0xf851b71aeAE9d1f44991224C3FCb83d210D63D17;
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
