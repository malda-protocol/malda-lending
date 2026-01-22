// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {MixedPriceOracleV4} from "src/oracles/MixedPriceOracleV4.sol";
import {OracleFeedV4} from "script/deployers/Types.sol";

/**
 * forge script SetPriceFeedOnOracleV4.  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --sig "run(string,address,string,uint8)" "WETHUSD" "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419" "USD" 18 \
 *     --broadcast
 */
contract SetPriceFeedOnOracleV4 is Script {
    function runTestnet(address oracle, string memory symbol, address priceFeed, uint8 underlyingDecimals) public {
        uint256 key = vm.envUint("PRIVATE_KEY");
        MixedPriceOracleV4.PriceConfig memory config = MixedPriceOracleV4.PriceConfig({
            api3Feed: priceFeed, chainlinkFeed: priceFeed, toSymbol: "USD", underlyingDecimals: underlyingDecimals
        });

        console.log("Setting oracle feed for %s", symbol);
        vm.startBroadcast(key);
        MixedPriceOracleV4(oracle).setConfig(symbol, config);
        vm.stopBroadcast();
        console.log("Oracle feed set");
    }

    function run(address oracle) public {
        uint256 key = vm.envUint("PRIVATE_KEY");

        OracleFeedV4[] memory feeds = new OracleFeedV4[](16);
        // usdc
        feeds[0] = OracleFeedV4({
            symbol: "mUSDC",
            apiV3Feed: 0x874b4573B30629F696653EE101528C7426FFFb6b,
            chainlinkFeed: 0xAADAa473C1bDF7317ec07c915680Af29DeBfdCb5,
            toSymbol: "USD",
            underlyingDecimals: 6
        });
        feeds[1] = OracleFeedV4({
            symbol: "USDC",
            apiV3Feed: 0x874b4573B30629F696653EE101528C7426FFFb6b,
            chainlinkFeed: 0xAADAa473C1bDF7317ec07c915680Af29DeBfdCb5,
            toSymbol: "USD",
            underlyingDecimals: 6
        });
        //usdt
        feeds[2] = OracleFeedV4({
            symbol: "mUSDT",
            apiV3Feed: 0x0c547EC8B69F50d023D52391b8cB82020c46b848,
            chainlinkFeed: 0xefCA2bbe0EdD0E22b2e0d2F8248E99F4bEf4A7dB,
            toSymbol: "USD",
            underlyingDecimals: 6
        });
        feeds[3] = OracleFeedV4({
            symbol: "USDT",
            apiV3Feed: 0x0c547EC8B69F50d023D52391b8cB82020c46b848,
            chainlinkFeed: 0xefCA2bbe0EdD0E22b2e0d2F8248E99F4bEf4A7dB,
            toSymbol: "USD",
            underlyingDecimals: 6
        });
        //WBTC
        feeds[4] = OracleFeedV4({
            symbol: "mWBTC",
            apiV3Feed: 0xa34Aa6654A7E45fB000F130453Ba967Fd57851C1,
            chainlinkFeed: 0x7A99092816C8BD5ec8ba229e3a6E6Da1E628E1F9,
            toSymbol: "USD",
            underlyingDecimals: 8
        });
        feeds[5] = OracleFeedV4({
            symbol: "WBTC",
            apiV3Feed: 0xa34Aa6654A7E45fB000F130453Ba967Fd57851C1,
            chainlinkFeed: 0x7A99092816C8BD5ec8ba229e3a6E6Da1E628E1F9,
            toSymbol: "USD",
            underlyingDecimals: 8
        });
        //WETH
        feeds[6] = OracleFeedV4({
            symbol: "mWETH",
            apiV3Feed: 0x2284eC83978Fe21A0E667298d9110bbeaED5E9B4,
            chainlinkFeed: 0x3c6Cd9Cc7c7a4c2Cf5a82734CD249D7D593354dA,
            toSymbol: "USD",
            underlyingDecimals: 18
        });
        feeds[7] = OracleFeedV4({
            symbol: "WETH",
            apiV3Feed: 0x2284eC83978Fe21A0E667298d9110bbeaED5E9B4,
            chainlinkFeed: 0x3c6Cd9Cc7c7a4c2Cf5a82734CD249D7D593354dA,
            toSymbol: "USD",
            underlyingDecimals: 18
        });
        //ezETH
        feeds[8] = OracleFeedV4({
            symbol: "mezETH",
            apiV3Feed: 0x01600fE800B9a1c3638F24c1408F2d177133074C,
            chainlinkFeed: 0xb71F79770BA599940F454c70e63d4DE0E8606731,
            toSymbol: "WETH",
            underlyingDecimals: 18
        });
        feeds[9] = OracleFeedV4({
            symbol: "ezETH",
            apiV3Feed: 0x01600fE800B9a1c3638F24c1408F2d177133074C,
            chainlinkFeed: 0xb71F79770BA599940F454c70e63d4DE0E8606731,
            toSymbol: "WETH",
            underlyingDecimals: 18
        });
        //weETH
        feeds[10] = OracleFeedV4({
            symbol: "mweETH",
            apiV3Feed: 0x6Bd45e0f0adaAE6481f2B4F3b867911BF5f8321b,
            chainlinkFeed: 0x1FBc7d24654b10c71fd74d3730d9Df17836181EF,
            toSymbol: "WETH",
            underlyingDecimals: 18
        });
        feeds[11] = OracleFeedV4({
            symbol: "weETH",
            apiV3Feed: 0x6Bd45e0f0adaAE6481f2B4F3b867911BF5f8321b,
            chainlinkFeed: 0x1FBc7d24654b10c71fd74d3730d9Df17836181EF,
            toSymbol: "WETH",
            underlyingDecimals: 18
        });
        //rsETH
        feeds[12] = OracleFeedV4({
            symbol: "mwrsETH",
            apiV3Feed: 0xB7b25D8e8490a138c854426e7000C7E114C2DebF,
            chainlinkFeed: address(0),
            toSymbol: "WETH",
            underlyingDecimals: 18
        });
        feeds[13] = OracleFeedV4({
            symbol: "wrsETH",
            apiV3Feed: 0xB7b25D8e8490a138c854426e7000C7E114C2DebF,
            chainlinkFeed: address(0),
            toSymbol: "WETH",
            underlyingDecimals: 18
        });
        //wstETH
        feeds[14] = OracleFeedV4({
            symbol: "mwstETH",
            apiV3Feed: 0x043F8c576154E19E05cD53b21Baab86deC75c728,
            chainlinkFeed: 0x8eCE1AbA32716FdDe8D6482bfd88E9a0ee01f565,
            toSymbol: "USD",
            underlyingDecimals: 18
        });
        feeds[15] = OracleFeedV4({
            symbol: "wstETH",
            apiV3Feed: 0x043F8c576154E19E05cD53b21Baab86deC75c728,
            chainlinkFeed: 0x8eCE1AbA32716FdDe8D6482bfd88E9a0ee01f565,
            toSymbol: "USD",
            underlyingDecimals: 18
        });

        uint256 len = feeds.length;
        string[] memory symbols = new string[](len);
        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](len);
        for (uint256 i; i < len;) {
            symbols[i] = feeds[i].symbol;
            configs[i] = MixedPriceOracleV4.PriceConfig({
                api3Feed: feeds[i].apiV3Feed,
                chainlinkFeed: feeds[i].chainlinkFeed,
                toSymbol: feeds[i].toSymbol,
                underlyingDecimals: feeds[i].underlyingDecimals
            });
            unchecked {
                ++i;
            }
        }

        vm.startBroadcast(key);
        for (uint256 i; i < configs.length; ++i) {
            MixedPriceOracleV4(oracle).setConfig(symbols[i], configs[i]);
        }
        vm.stopBroadcast();
    }
}
