// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Operator} from "src/Operator/Operator.sol";

contract OperatorHarness is Operator {
    function callOnlyAllowedUser(address user) external onlyAllowedUser(user) {}

    function callIfNotBlacklisted(address user) external ifNotBlacklisted(user) {}

    function pushAllMarkets(address mToken) external {
        allMarkets.push(mToken);
    }

    function setMarketListed(address mToken, bool listed) external {
        markets[mToken].isListed = listed;
    }

    function setAccountMembership(address mToken, address account, bool status) external {
        markets[mToken].accountMembership[account] = status;
    }

    function setAccountAssets(address account, address[] calldata assets) external {
        delete accountAssets[account];
        for (uint256 i; i < assets.length; ++i) {
            accountAssets[account].push(assets[i]);
        }
    }
}
