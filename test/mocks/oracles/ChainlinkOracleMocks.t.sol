// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {IAggregatorV3} from "src/interfaces/external/chainlink/IAggregatorV3.sol";

contract MockAggregatorV3 is IAggregatorV3 {
    uint8 public decimalsOverride;
    int256 public answer;
    uint256 public updatedAt;

    constructor(uint8 _decimals, int256 _answer) {
        decimalsOverride = _decimals;
        answer = _answer;
        updatedAt = block.timestamp;
    }

    function decimals() external view returns (uint8) {
        return decimalsOverride;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer_, uint256 startedAt, uint256 updatedAt_, uint80 answeredInRound)
    {
        roundId = 1;
        answer_ = answer;
        startedAt = 0;
        updatedAt_ = updatedAt;
        answeredInRound = 1;
    }

    function setAnswer(int256 _answer) external {
        answer = _answer;
    }

    function setUpdatedAt(uint256 _updatedAt) external {
        updatedAt = _updatedAt;
    }
}

contract MockSymbolToken {
    string public symbol;

    constructor(string memory _symbol) {
        symbol = _symbol;
    }
}

contract MockMToken {
    string public symbol;
    address public underlying;

    constructor(string memory _symbol, address _underlying) {
        symbol = _symbol;
        underlying = _underlying;
    }
}
