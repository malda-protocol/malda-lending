// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {IDefaultAdapter} from "src/interfaces/IDefaultAdapter.sol";

contract MockV3Feed is IDefaultAdapter {
    uint8 public override decimals;
    int256 public price;
    uint256 public updatedAt;

    constructor(uint8 _decimals, int256 _price) {
        decimals = _decimals;
        price = _price;
        updatedAt = block.timestamp;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt_, uint80 answeredInRound)
    {
        roundId = 1;
        answer = price;
        startedAt = 0;
        updatedAt_ = updatedAt;
        answeredInRound = 1;
    }

    function latestAnswer() external view returns (int256) {
        return price;
    }

    function latestTimestamp() external view returns (uint256) {
        return updatedAt;
    }

    function setPrice(int256 _price) external {
        price = _price;
    }

    function setUpdatedAt(uint256 _updatedAt) external {
        updatedAt = _updatedAt;
    }
}

    contract MockV3Token {
        string public symbol;

        constructor(string memory _symbol) {
            symbol = _symbol;
        }
    }

    contract MockV3MToken {
        string public symbol;
        address public underlying;

        constructor(string memory _symbol, address _underlying) {
            symbol = _symbol;
            underlying = _underlying;
        }
    }
