// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRebalanceMarket} from "src/interfaces/IRebalancer.sol";
import {IHypernativeFirewall} from "src/libraries/HypernativeFirewallProtected.sol";

contract MockRebalanceMarket is IRebalanceMarket {
    address public underlying;
    IERC20 public token;

    constructor(address _underlying) {
        underlying = _underlying;
        token = IERC20(_underlying);
    }

    function extractForRebalancing(uint256 amount) external {
        token.transfer(msg.sender, amount);
    }
}

contract MockFirewallRegister is IHypernativeFirewall {
    address public lastAccount;
    bool public lastStrict;

    function register(address account, bool isStrictMode) external {
        lastAccount = account;
        lastStrict = isStrictMode;
    }

    function validateBlacklistedAccountInteraction(address) external {}

    function validateForbiddenAccountInteraction(address) external view {}

    function validateForbiddenContextInteraction(address, address) external view {}
}

contract RejectEthReceiver {
    receive() external payable {
        revert("reject");
    }
}
