// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

contract OracleMockPerToken {
    mapping(address => uint256) public price;
    mapping(address => uint256) public underlyingPrice;
    address public admin;
    mapping(address => uint8) public registeredDecimals;

    error OracleMock_NotAuthorized();

    constructor(address _admin) {
        admin = _admin;
    }

    function setDecimals(address token, uint8 dec) external {
        require(msg.sender == admin, OracleMock_NotAuthorized());
        registeredDecimals[token] = dec;
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }

    // not used
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        roundId = 1;
        answer = 0;
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = 1;
    }

    // not used
    function latestAnswer() external pure returns (int256) {
        return 0;
    }

    function latestTimestamp() external view returns (uint256) {
        return block.timestamp;
    }

    function setPrice(address _token, uint256 _price) external {
        require(msg.sender == admin, OracleMock_NotAuthorized());
        price[_token] = _price;
    }

    function setUnderlyingPrice(address _token, uint256 _price) external {
        require(msg.sender == admin, OracleMock_NotAuthorized());
        underlyingPrice[_token] = _price;
    }

    function getPrice(address _t) external view returns (uint256) {
        return price[_t];
    }

    function getUnderlyingPrice(address _t) external view returns (uint256) {
        return underlyingPrice[_t];
    }
}
