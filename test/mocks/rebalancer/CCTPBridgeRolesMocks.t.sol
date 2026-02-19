// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

contract MockRoles {
    bytes32 public constant REBALANCER_ROLE = keccak256("REBALANCER_ROLE");
    bytes32 public constant BRIDGE_CONFIGURATOR_ROLE = keccak256("BRIDGE_CONFIGURATOR_ROLE");
    bytes32 public constant GUARDIAN_BRIDGE_ROLE = keccak256("GUARDIAN_BRIDGE_ROLE");

    mapping(address account => mapping(bytes32 role => bool allowed)) public perms;

    function grantRebalancer(address who) external {
        perms[who][REBALANCER_ROLE] = true;
    }

    function grantBridgeConfigurator(address who) external {
        perms[who][BRIDGE_CONFIGURATOR_ROLE] = true;
    }

    function grantGuardianBridge(address who) external {
        perms[who][GUARDIAN_BRIDGE_ROLE] = true;
    }

    function REBALANCER() external pure returns (bytes32) {
        return REBALANCER_ROLE;
    }

    function GUARDIAN_BRIDGE() external pure returns (bytes32) {
        return GUARDIAN_BRIDGE_ROLE;
    }

    function BRIDGE_CONFIGURATOR() external pure returns (bytes32) {
        return BRIDGE_CONFIGURATOR_ROLE;
    }

    function isAllowedFor(address account, bytes32 role) external view returns (bool) {
        return perms[account][role];
    }
}
