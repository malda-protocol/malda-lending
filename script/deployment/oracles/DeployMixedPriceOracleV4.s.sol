// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {MixedPriceOracleV4} from "src/oracles/MixedPriceOracleV4.sol";
import {OracleFeedV4} from "script/deployers/Types.sol";

/**
 * forge script DeployMixedPriceOracleV4  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --broadcast
 */
contract DeployMixedPriceOracleV4 is Script {
    function runTestnet(Deployer deployer, address roles, uint256 stalenessPeriod) public returns (address) {
        uint256 key = vm.envUint("PRIVATE_KEY");

        string[] memory symbols = new string[](0);
        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](0);

        bytes32 salt = getSalt("MixedPriceOracleV4V1.0.1");
        address created = deployer.precompute(salt);
        if (created.code.length > 0) {
            console.log("MixedPriceOracleV4 already deployed at: %s", created);
        } else {
            vm.startBroadcast(key);
            created = deployer.create(
                salt,
                abi.encodePacked(
                    type(MixedPriceOracleV4).creationCode, abi.encode(symbols, configs, roles, stalenessPeriod)
                )
            );
            vm.stopBroadcast();
            console.log("MixedPriceOracleV4 deployed at: %s", created);
        }

        return created;
    }

    function runWithoutFeeds(Deployer deployer, address roles, uint256 stalenessPeriod) public returns (address) {
        uint256 key = vm.envUint("PRIVATE_KEY");

        string[] memory symbols = new string[](0);
        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](0);

        bytes32 salt = getSalt("MixedPriceOracleV4V1.0.1");
        address created = deployer.precompute(salt);
        if (created.code.length > 0) {
            console.log("MixedPriceOracleV4 already deployed at: %s", created);
        } else {
            vm.startBroadcast(key);
            created = deployer.create(
                salt,
                abi.encodePacked(
                    type(MixedPriceOracleV4).creationCode, abi.encode(symbols, configs, roles, stalenessPeriod)
                )
            );
            vm.stopBroadcast();
            console.log("MixedPriceOracleV4 deployed at: %s", created);
        }

        return created;
    }
    //function runWithFeeds(Deployer deployer, OracleFeedV4[] memory feeds, address roles, uint256 stalenessPeriod)

    function run() public returns (address) {
        Deployer deployer = Deployer(payable(0x8F91616F05b3D74A8Ae56e43C585F0972Ccb91Df));
        address roles = 0x1211d07F0EBeA8994F23EC26e1e512929FC8Ab08;
        uint256 stalenessPeriod = 86400;

        OracleFeedV4[] memory feeds = new OracleFeedV4[](16);
        // usdc - both feeds return USD
        feeds[0] = OracleFeedV4({
            symbol: "mUSDC",
            apiV3Feed: 0x874b4573B30629F696653EE101528C7426FFFb6b,
            chainlinkFeed: 0xAADAa473C1bDF7317ec07c915680Af29DeBfdCb5,
            api3ToSymbol: "USD",
            chainlinkToSymbol: "USD",
            underlyingDecimals: 6
        });
        feeds[1] = OracleFeedV4({
            symbol: "USDC",
            apiV3Feed: 0x874b4573B30629F696653EE101528C7426FFFb6b,
            chainlinkFeed: 0xAADAa473C1bDF7317ec07c915680Af29DeBfdCb5,
            api3ToSymbol: "USD",
            chainlinkToSymbol: "USD",
            underlyingDecimals: 6
        });
        // usdt - both feeds return USD
        feeds[2] = OracleFeedV4({
            symbol: "mUSDT",
            apiV3Feed: 0x0c547EC8B69F50d023D52391b8cB82020c46b848,
            chainlinkFeed: 0xefCA2bbe0EdD0E22b2e0d2F8248E99F4bEf4A7dB,
            api3ToSymbol: "USD",
            chainlinkToSymbol: "USD",
            underlyingDecimals: 6
        });
        feeds[3] = OracleFeedV4({
            symbol: "USDT",
            apiV3Feed: 0x0c547EC8B69F50d023D52391b8cB82020c46b848,
            chainlinkFeed: 0xefCA2bbe0EdD0E22b2e0d2F8248E99F4bEf4A7dB,
            api3ToSymbol: "USD",
            chainlinkToSymbol: "USD",
            underlyingDecimals: 6
        });
        // WBTC - both feeds return USD
        feeds[4] = OracleFeedV4({
            symbol: "mWBTC",
            apiV3Feed: 0xa34Aa6654A7E45fB000F130453Ba967Fd57851C1,
            chainlinkFeed: 0x7A99092816C8BD5ec8ba229e3a6E6Da1E628E1F9,
            api3ToSymbol: "USD",
            chainlinkToSymbol: "USD",
            underlyingDecimals: 8
        });
        feeds[5] = OracleFeedV4({
            symbol: "WBTC",
            apiV3Feed: 0xa34Aa6654A7E45fB000F130453Ba967Fd57851C1,
            chainlinkFeed: 0x7A99092816C8BD5ec8ba229e3a6E6Da1E628E1F9,
            api3ToSymbol: "USD",
            chainlinkToSymbol: "USD",
            underlyingDecimals: 8
        });
        // WETH - both feeds return USD
        feeds[6] = OracleFeedV4({
            symbol: "mWETH",
            apiV3Feed: 0x2284eC83978Fe21A0E667298d9110bbeaED5E9B4,
            chainlinkFeed: 0x3c6Cd9Cc7c7a4c2Cf5a82734CD249D7D593354dA,
            api3ToSymbol: "USD",
            chainlinkToSymbol: "USD",
            underlyingDecimals: 18
        });
        feeds[7] = OracleFeedV4({
            symbol: "WETH",
            apiV3Feed: 0x2284eC83978Fe21A0E667298d9110bbeaED5E9B4,
            chainlinkFeed: 0x3c6Cd9Cc7c7a4c2Cf5a82734CD249D7D593354dA,
            api3ToSymbol: "USD",
            chainlinkToSymbol: "USD",
            underlyingDecimals: 18
        });
        // ezETH - API3 returns USD, Chainlink returns ETH exchange rate
        feeds[8] = OracleFeedV4({
            symbol: "mezETH",
            apiV3Feed: 0x01600fE800B9a1c3638F24c1408F2d177133074C,
            chainlinkFeed: 0xb71F79770BA599940F454c70e63d4DE0E8606731,
            api3ToSymbol: "USD",
            chainlinkToSymbol: "WETH",
            underlyingDecimals: 18
        });
        feeds[9] = OracleFeedV4({
            symbol: "ezETH",
            apiV3Feed: 0x01600fE800B9a1c3638F24c1408F2d177133074C,
            chainlinkFeed: 0xb71F79770BA599940F454c70e63d4DE0E8606731,
            api3ToSymbol: "USD",
            chainlinkToSymbol: "WETH",
            underlyingDecimals: 18
        });
        // weETH - API3 returns USD, Chainlink returns ETH exchange rate
        feeds[10] = OracleFeedV4({
            symbol: "mweETH",
            apiV3Feed: 0x6Bd45e0f0adaAE6481f2B4F3b867911BF5f8321b,
            chainlinkFeed: 0x1FBc7d24654b10c71fd74d3730d9Df17836181EF,
            api3ToSymbol: "USD",
            chainlinkToSymbol: "WETH",
            underlyingDecimals: 18
        });
        feeds[11] = OracleFeedV4({
            symbol: "weETH",
            apiV3Feed: 0x6Bd45e0f0adaAE6481f2B4F3b867911BF5f8321b,
            chainlinkFeed: 0x1FBc7d24654b10c71fd74d3730d9Df17836181EF,
            api3ToSymbol: "USD",
            chainlinkToSymbol: "WETH",
            underlyingDecimals: 18
        });
        // wrsETH - API3 returns USD, no Chainlink feed
        feeds[12] = OracleFeedV4({
            symbol: "mwrsETH",
            apiV3Feed: 0xB7b25D8e8490a138c854426e7000C7E114C2DebF,
            chainlinkFeed: address(0),
            api3ToSymbol: "USD",
            chainlinkToSymbol: "USD",
            underlyingDecimals: 18
        });
        feeds[13] = OracleFeedV4({
            symbol: "wrsETH",
            apiV3Feed: 0xB7b25D8e8490a138c854426e7000C7E114C2DebF,
            chainlinkFeed: address(0),
            api3ToSymbol: "USD",
            chainlinkToSymbol: "USD",
            underlyingDecimals: 18
        });
        // wstETH - both feeds return USD
        feeds[14] = OracleFeedV4({
            symbol: "mwstETH",
            apiV3Feed: 0x043F8c576154E19E05cD53b21Baab86deC75c728,
            chainlinkFeed: 0x8eCE1AbA32716FdDe8D6482bfd88E9a0ee01f565,
            api3ToSymbol: "USD",
            chainlinkToSymbol: "USD",
            underlyingDecimals: 18
        });
        feeds[15] = OracleFeedV4({
            symbol: "wstETH",
            apiV3Feed: 0x043F8c576154E19E05cD53b21Baab86deC75c728,
            chainlinkFeed: 0x8eCE1AbA32716FdDe8D6482bfd88E9a0ee01f565,
            api3ToSymbol: "USD",
            chainlinkToSymbol: "USD",
            underlyingDecimals: 18
        });

        uint256 key = vm.envUint("PRIVATE_KEY");

        uint256 len = feeds.length;
        string[] memory symbols = new string[](len);
        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](len);
        for (uint256 i; i < len;) {
            symbols[i] = feeds[i].symbol;
            configs[i] = MixedPriceOracleV4.PriceConfig({
                api3Feed: feeds[i].apiV3Feed,
                chainlinkFeed: feeds[i].chainlinkFeed,
                api3ToSymbol: feeds[i].api3ToSymbol,
                chainlinkToSymbol: feeds[i].chainlinkToSymbol,
                underlyingDecimals: feeds[i].underlyingDecimals
            });
            unchecked {
                ++i;
            }
        }
        bytes32 salt = getSalt("MixedPriceOracleV4V1.0.1");
        address created = deployer.precompute(salt);
        if (created.code.length > 0) {
            console.log("MixedPriceOracleV4 already deployed at: %s", created);
        } else {
            console.log("MixedPriceOracleV4 deployment calldata:");
            console.logBytes(
                abi.encodeWithSelector(
                    deployer.create.selector,
                    salt,
                    abi.encodePacked(
                        type(MixedPriceOracleV4).creationCode, abi.encode(symbols, configs, roles, stalenessPeriod)
                    )
                )
            );

            vm.startBroadcast(key);
            created = deployer.create(
                salt,
                abi.encodePacked(
                    type(MixedPriceOracleV4).creationCode, abi.encode(symbols, configs, roles, stalenessPeriod)
                )
            );
            vm.stopBroadcast();
            console.log("MixedPriceOracleV4 deployed at: %s", created);
        }

        return created;
    }

    function getSalt(string memory name) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes(string.concat(name, "-v1")))
            );
    }
}
