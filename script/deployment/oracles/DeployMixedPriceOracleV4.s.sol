// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {MixedPriceOracleV4} from "src/oracles/MixedPriceOracleV4.sol";
import {OracleFeedV4} from "script/deployers/Types.sol";
import {IDefaultAdapter} from "src/interfaces/IDefaultAdapter.sol";

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
    function runWithFeeds(Deployer deployer, OracleFeedV4[] memory feeds, address roles, uint256 stalenessPeriod)
        public
        returns (address)
    {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");

        uint256 len = feeds.length;
        string[] memory symbols = new string[](len);
        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](len);
        for (uint256 i; i < len;) {
            symbols[i] = feeds[i].symbol;
            configs[i] = MixedPriceOracleV4.PriceConfig({
                api3Feed: feeds[i].apiV3Feed,
                eOracleFeed: feeds[i].eOracleFeed,
                toSymbol: feeds[i].toSymbol,
                underlyingDecimals: feeds[i].underlyingDecimals
            });
            unchecked {
                ++i;
            }
        }
        bytes32 salt = getSalt("MixedPriceOracleV4V1.0.0");
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

    function getSalt(string memory name) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes(string.concat(name, "-v1")))
        );
    }
}
