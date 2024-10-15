// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.8.27;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

// contracts
import {CREATE3} from "../libraries/CREATE3.sol";

contract Deployer {
    address public admin;

    constructor() {
        admin = msg.sender;
    }

    receive() external payable {}

    // ----------- OWNER ------------
    function saveEth() external {
        if (admin == msg.sender) {
            (bool success,) = msg.sender.call{value: address(this).balance}("");
            require(success, "ETH");
        }
    }

    // ----------- VIEW ------------

    function precompute(bytes32 salt) external view returns (address) {
        return CREATE3.getDeployed(salt);
    }

    // ----------- PUBLIC ------------
    function create(bytes32 salt, bytes memory code) external payable returns (address) {
        return CREATE3.deploy(salt, code, msg.value);
    }
}
