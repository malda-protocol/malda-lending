// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.27;

/*
_____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|
                               
*/

abstract contract Constants {
    // ----------- GENERIC ------------
    uint256 public constant SMALL = 10 ether;
    uint256 public constant MEDIUM = 100 ether;
    uint256 public constant LARGE = 1000 ether;

    uint256 public constant ALICE_KEY = 0x1;
    uint256 public constant BOB_KEY = 0x2;
    uint256 public constant FOO_KEY = 0x3;

    address public constant ZERO_ADDRESS = address(0);
    uint256 public constant ZERO_VALUE = 0;
}