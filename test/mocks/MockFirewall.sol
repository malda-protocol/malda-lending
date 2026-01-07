// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IHypernativeFirewall} from "src/libraries/HypernativeFirewallProtected.sol";

contract MockFirewall is IHypernativeFirewall {
    address public lastRegistered;
    bool public lastStrictMode;
    uint256 public registerCount;
    uint256 public validateBlacklistedCount;
    address public lastBlacklistedSender;
    bool public checkForbiddenAccount;
    address public expectedForbiddenSender;
    bool public checkForbiddenContext;
    address public expectedContextOrigin;
    address public expectedContextSender;

    function register(address account, bool isStrictMode) external {
        lastRegistered = account;
        lastStrictMode = isStrictMode;
        registerCount++;
    }

    function validateBlacklistedAccountInteraction(address sender) external {
        lastBlacklistedSender = sender;
        validateBlacklistedCount++;
    }

    function validateForbiddenAccountInteraction(address sender) external view {
        if (checkForbiddenAccount) {
            require(sender == expectedForbiddenSender, "MockFirewall: forbidden account");
        }
    }

    function validateForbiddenContextInteraction(address origin, address sender) external view {
        if (checkForbiddenContext) {
            require(
                origin == expectedContextOrigin && sender == expectedContextSender, "MockFirewall: forbidden context"
            );
        }
    }

    function setExpectedForbiddenAccount(address sender) external {
        checkForbiddenAccount = true;
        expectedForbiddenSender = sender;
    }

    function clearExpectedForbiddenAccount() external {
        checkForbiddenAccount = false;
        expectedForbiddenSender = address(0);
    }

    function setExpectedForbiddenContext(address origin, address sender) external {
        checkForbiddenContext = true;
        expectedContextOrigin = origin;
        expectedContextSender = sender;
    }

    function clearExpectedForbiddenContext() external {
        checkForbiddenContext = false;
        expectedContextOrigin = address(0);
        expectedContextSender = address(0);
    }
}
