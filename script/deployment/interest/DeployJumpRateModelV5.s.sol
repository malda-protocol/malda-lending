// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Script} from "forge-std/Script.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {JumpRateModelV5} from "src/interest/JumpRateModelV5.sol";

import "forge-std/console2.sol";

/**
 * forge script script/deployment/interest/DeployJumpRateModelV5.s.sol:DeployJumpRateModelV5  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --sig "run((uint256,string,uint256,uint256,uint256,uint256))" "(750000000000000000,'ExampleName',2102400,20000000000000000,100000000000000000,500000000000000000)" \
 *     --broadcast
 */
contract DeployJumpRateModelV5 is Script {
    struct InterestData {
        uint256 kink;
        string name;
        uint256 blocksPerYear;
        uint256 baseRatePerYear;
        uint256 multiplierPerYear;
        uint256 jumpMultiplierPerYear;
    }

    function run() public {
        uint256 key = vm.envUint("PRIVATE_KEY");

        Deployer deployer = Deployer(payable(0x8F91616F05b3D74A8Ae56e43C585F0972Ccb91Df));
        InterestData memory data = InterestData({
            kink: 400000000000000000,
            name: "mwrsETH Interest Model",
            blocksPerYear: 31536000,
            baseRatePerYear: 0,
            multiplierPerYear: 2219685438,
            jumpMultiplierPerYear: 95129375951
        });
        address owner = 0x91B945CbB063648C44271868a7A0c7BdFf64827D;

        bytes32 salt = getSalt(string.concat(data.name, "JumpRateModelV1.0.5-0xa31963C753f277f7d82d98F56b2C374256925eB7"));

        // ---------------------------------------------------------------------
        // Build deployment calldata for Safe
        // ---------------------------------------------------------------------
        bytes memory constructorArgs = abi.encode(
            data.blocksPerYear,
            data.baseRatePerYear,
            data.multiplierPerYear,
            data.jumpMultiplierPerYear,
            data.kink,
            owner,
            data.name
        );
        bytes memory creationCode = abi.encodePacked(
            type(JumpRateModelV5).creationCode,
            constructorArgs
        );
        bytes memory callData = abi.encodeWithSelector(
            deployer.create.selector,
            salt,
            creationCode
        );

        address created = deployer.precompute(salt);
        console2.log("created: ", created);


        // ---------------------------------------------------------------------
        // Output Safe-ready data
        // ---------------------------------------------------------------------
        console2.log("========================================");
        console2.log("Submit the following in your Safe:");
        console2.log("To (Deployer):", address(deployer));
        console2.log("Value: 0");
        console2.logBytes(callData);
    }

    function getSalt(string memory name) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes(string.concat(name, "-v1")))
        );
    }
}
