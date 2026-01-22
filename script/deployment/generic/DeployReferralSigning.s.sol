// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {ReferralSigning} from "src/referral/ReferralSigning.sol";
import {Script, console} from "forge-std/Script.sol";
import {Deployer} from "src/utils/Deployer.sol";

contract DeployReferralSigning is Script {
    function run() public returns (address) {
        Deployer _deployer = Deployer(payable(0x8F91616F05b3D74A8Ae56e43C585F0972Ccb91Df));
        bytes32 salt = getSalt("ReferralSigningV1.0.0");

        console.log("Deploying ReferralSigning");

        address created = _deployer.precompute(salt);
        // Deploy only if not already deployed
        if (created.code.length == 0) {
            vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
            created = _deployer.create(salt, type(ReferralSigning).creationCode);
            vm.stopBroadcast();
            console.log("ReferralSigning deployed at: %s", created);
        } else {
            console.log("Using existing ReferralSigning at: %s", created);
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
