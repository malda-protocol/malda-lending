// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IAggregatorV3} from "src/interfaces/external/chainlink/IAggregatorV3.sol";
import {ChainlinkOracle} from "src/oracles/ChainlinkOracle.sol";

contract ChainlinkOracleHarness is ChainlinkOracle {
    constructor(string[] memory symbols_, IAggregatorV3[] memory feeds_, uint256[] memory baseUnits_)
        ChainlinkOracle(symbols_, feeds_, baseUnits_)
    {}

    function exposed_getLatestPrice(string calldata symbol) external view returns (uint256, uint256) {
        return _getLatestPrice(symbol);
    }
}
