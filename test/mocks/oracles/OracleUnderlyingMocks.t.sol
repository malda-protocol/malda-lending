// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

contract MockChainlinkOracle {
    uint256 public decimals;
    uint256 public price;

    constructor(uint256 _price, uint256 _decimals) {
        price = _price;
        decimals = _decimals;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        roundId = 1;
        answer = int256(price);
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = 1;
    }
}

contract DummyToken {
    string public symbol;
    uint256 public decimals;

    constructor(string memory _symbol, uint256 _decimals) {
        symbol = _symbol;
        decimals = _decimals;
    }
}

contract DummyMToken {
    address public underlying;

    constructor(address _underlying) {
        underlying = _underlying;
    }
}
