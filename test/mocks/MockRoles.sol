// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

contract MockRoles {
    mapping(address => bool) public permissions;
    mapping(address => bool) public isRebalancer;
    mapping(address => bool) public isBridgeConfigurator;


    bytes32 public constant GUARDIAN_BLACKLIST = keccak256("GUARDIAN_BLACKLIST");
    bytes32 public constant GUARDIAN_BRIDGE = keccak256("GUARDIAN_BRIDGE");
    bytes32 public constant REBALANCER = keccak256("REBALANCER");

    function isAllowedFor(address account, bytes32) external view returns (bool) {
        return permissions[account];
    }

    function setAllowed(address account, bool allowed) external {
        permissions[account] = allowed;
    }

    function setRebalancer(address who, bool v) external {
        isRebalancer[who] = v;
    }

    function setBridgeConfigurator(address who, bool v) external {
        isBridgeConfigurator[who] = v;
    }
}