// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {DeployBase} from "script/deployers/DeployBase.sol";
import {JumpRateModelV2} from "src/interest/JumpRateModelV2.sol";

/**
 * forge script script/deployment/interest/DeployJumpRateModelV2.s.sol:DeployJumpRateModelV2  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --sig "run((uint256,string,uint256,uint256,uint256,uint256))" "(750000000000000000,'ExampleName',2102400,20000000000000000,100000000000000000,500000000000000000)" \
 *     --broadcast
 */
contract DeployJumpRateModelV2 is Script, DeployBase {
    struct InterestData {
        uint256 kink;
        string name;
        uint256 blocksPerYear;
        uint256 baseRatePerYear;
        uint256 multiplierPerYear;
        uint256 jumpMultiplierPerYear;
    }

    function run(InterestData memory data) public returns (address) {
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);

        bytes32 salt = getSalt(string.concat(data.name, "JumpRateModelV2"));
        address created = deployer.create(
            salt,
            abi.encodePacked(
                type(JumpRateModelV2).creationCode,
                abi.encode(
                    data.blocksPerYear,
                    data.baseRatePerYear,
                    data.multiplierPerYear,
                    data.jumpMultiplierPerYear,
                    data.kink,
                    vm.envAddress("OWNER"),
                    data.name
                )
            )
        );

        console.log(" JumpRateModelV2 deployed at: %s", created);

        vm.stopBroadcast();

        return created;
    }
}
