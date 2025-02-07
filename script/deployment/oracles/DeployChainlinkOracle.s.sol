// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {DeployBase} from "script/deployers/DeployBase.sol";
import {ChainlinkOracle} from "src/oracles/ChainlinkOracle.sol";
import {IAggregatorV3} from "src/interfaces/external/chainlink/IAggregatorV3.sol";

/**
 * forge script DeployChainlinkOracle  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --broadcast
 */
contract DeployChainlinkOracle is Script, DeployBase {
    function run() public returns (address) {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(key);

        string[] memory symbols = new string[](1);
        symbols[0] = "USDCETH";

        IAggregatorV3[] memory feeds = new IAggregatorV3[](1);
        feeds[0] = IAggregatorV3(address(0));

        uint256[] memory baseUnits = new uint256[](1);
        baseUnits[0] = 18;

        bytes32 salt = getSalt("ChainlinkOracle");
        address created = deployer.create(
            salt, abi.encodePacked(type(ChainlinkOracle).creationCode, abi.encode(symbols, feeds, baseUnits))
        );                                          

        console.log(" ChainlinkOracle deployed at: %s", created);

        vm.stopBroadcast();

        return created;
    }
}
