// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

// contracts
import {CREATE3} from "src/libraries/CREATE3.sol";

contract Deployer {
    address public admin;
    address public pendingAdmin;

    error NotAuthorized(address admin, address sender);

    modifier onlyAdmin() {
        require(msg.sender == admin, NotAuthorized(admin, msg.sender));
        _;
    }

    constructor(address _admin) {
        admin = _admin;
    }

    receive() external payable {}

    // ----------- OWNER ------------
    function setPendingAdmin(address newAdmin) external onlyAdmin {
        pendingAdmin = newAdmin;
    }

    function saveEth() external {
        if (admin == msg.sender) {
            (bool success,) = msg.sender.call{value: address(this).balance}("");
            require(success, "ETH");
        }
    }

    function setNewAdmin(address _addr) external {
        if (admin == msg.sender) {
            admin = _addr;
        }
    }

    // ----------- VIEW ------------

    function precompute(bytes32 salt) external view returns (address) {
        return CREATE3.getDeployed(salt);
    }

    // ----------- PUBLIC ------------
    function create(bytes32 salt, bytes memory code) external payable onlyAdmin returns (address) {
        return CREATE3.deploy(salt, code, msg.value);
    }

    function acceptAdmin() external {
        if (msg.sender != pendingAdmin) {
            revert NotAuthorized(pendingAdmin, msg.sender);
        }
        admin = pendingAdmin;
        pendingAdmin = address(0);
    }
}
