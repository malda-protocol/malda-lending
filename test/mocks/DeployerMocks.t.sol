// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

contract DeployableMock {
    uint256 public value;

    constructor(uint256 _value) payable {
        value = _value;
    }
}
