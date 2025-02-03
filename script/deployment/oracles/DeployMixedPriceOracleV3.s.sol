// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {DeployBase} from "script/deployers/DeployBase.sol";
import {MixedPriceOracleV3} from "src/oracles/MixedPriceOracleV3.sol";
import {IDefaultAdapter} from "src/interfaces/IDefaultAdapter.sol";

/**
 * forge script DeployMixedPriceOracleV3  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --broadcast
 */
contract DeployMixedPriceOracleV3 is Script, DeployBase {
    function run(address usdcFeed, address wethFeed, address roles, uint256 stalenessPeriod) public returns (address) {
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);

        string[] memory symbols = new string[](2);
        symbols[0] = "mUSDC";
        symbols[1] = "mWETH";

        IDefaultAdapter.PriceConfig[] memory configs = new IDefaultAdapter.PriceConfig[](2);
        configs[0] = IDefaultAdapter.PriceConfig({defaultFeed: usdcFeed, toSymbol: "USD", underlyingDecimals: 6});

        configs[1] = IDefaultAdapter.PriceConfig({defaultFeed: wethFeed, toSymbol: "USD", underlyingDecimals: 18});

        bytes32 salt = getSalt("MixedPriceOracleV3");
        address created = deployer.create(
            salt,
            abi.encodePacked(
                type(MixedPriceOracleV3).creationCode, abi.encode(symbols, configs, roles, stalenessPeriod)
            )
        );

        console.log("MixedPriceOracleV3 deployed at: %s", created);

        vm.stopBroadcast();

        return created;
    }
}
