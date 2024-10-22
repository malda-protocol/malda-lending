// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.27;

contract OracleMock {
    uint256 public price;
    uint256 public underlyingPrice;

    function setPrice(uint256 _price) external {
        price = _price;
    }

    function setUnderlyingPrice(uint256 _price) external {
        underlyingPrice = _price;
    }

    function getPrice(address) external view returns (uint256) {
        return price;
    }

    function getUnderlyingPrice(address) external view returns (uint256) {
        return underlyingPrice;
    }
}
