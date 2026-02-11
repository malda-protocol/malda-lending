// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {HypernativeFirewallProtected} from "src/libraries/HypernativeFirewallProtected.sol";

contract FirewallHarness is HypernativeFirewallProtected {
    bytes32 internal constant FIREWALL_SLOT = bytes32(uint256(keccak256("eip1967.hypernative.firewall")) - 1);
    bytes32 internal constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.hypernative.admin")) - 1);
    bytes32 internal constant MODE_SLOT = bytes32(uint256(keccak256("eip1967.hypernative.is_strict_mode")) - 1);

    uint256 public callCount;

    function initFirewall(address firewall, address admin) external {
        _initHypernativeFirewall(firewall, admin);
    }

    function callOnlyFirewallApprovedAllowEOA() external onlyFirewallApprovedAllowEOA {
        callCount++;
    }

    function callOnlyFirewallAdmin() external onlyFirewallAdmin {
        callCount++;
    }

    function getFirewallAddress() external view returns (address) {
        return _getAddressBySlot(FIREWALL_SLOT);
    }

    function getAdminAddress() external view returns (address) {
        return _getAddressBySlot(ADMIN_SLOT);
    }

    function isStrictMode() external view returns (bool) {
        return _getValueBySlot(MODE_SLOT) == 1;
    }
}
