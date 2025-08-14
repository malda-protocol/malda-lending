// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {MockTokensBridge} from "src/rebalancer/bridges/MockTokensBridge.sol";

contract DeployMockTokensBridge is Script {
    // function run(Deployer deployer) public returns (address) {
    function run() public returns (address) {
        Deployer _deployer = Deployer(payable(0x7775C52aeA3780944aE69b389c23c9de325ce29B));
        address roles = 0xDb44c5e70439c6Ca5FcDe58944Fbe801E00557F0;
        address[] memory tokens = new address[](2);
        tokens[0] = 0xc6e1FB449b08B26B2063c289DF9BBcb79B91c992;
        tokens[1] = 0x0d7Ee0ee6E449e38269F2E089262b40cA4096594;

        bytes32 salt = getSalt("RolesV1.0.0");

        console.log("Deploying MockTokensBridge");

        address created = _deployer.precompute(salt);
        // Deploy only if not already deployed
        if (created.code.length == 0) {
            vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
            created =
                _deployer.create(salt, abi.encodePacked(type(MockTokensBridge).creationCode, abi.encode(roles, tokens)));
            vm.stopBroadcast();
            console.log("MockTokensBridge deployed at: %s", created);
        } else {
            console.log("Using existing MockTokensBridge at: %s", created);
        }

        return created;
    }

    function getSalt(string memory name) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes(string.concat(name, "-v1")))
        );
    }
}
