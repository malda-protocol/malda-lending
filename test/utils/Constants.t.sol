// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

abstract contract Constants {
    uint256 internal constant DEFAULT_START_TIME = 1_700_000_000;

    uint256 internal constant SMALL = 1 ether;
    uint256 internal constant MEDIUM = 100 ether;
    uint256 internal constant LARGE = 1000 ether;

    uint256 internal constant ALICE_KEY = 0x1;
    uint256 internal constant BOB_KEY = 0x2;
    uint256 internal constant FOO_KEY = 0x3;

    address internal constant ZERO_ADDRESS = address(0);
    uint256 internal constant ZERO_VALUE = 0;

    uint256 internal constant DEFAULT_ORACLE_PRICE = 1e18;
    uint256 internal constant DEFAULT_ORACLE_PRICE36 = 1e36;
    uint256 internal constant DEFAULT_LIQUIDATOR_ORACLE_PRICE = 8e17;
    uint256 internal constant DEFAULT_COLLATERAL_FACTOR = 9e17; // 90%
    uint256 internal constant DEFAULT_INFLATION_INCREASE = 1000; // 90%

    uint256 internal constant DEFAULT_CHAIN_ID = 1;
    uint32 internal constant MAINNET_CHAIN_ID = 1;
    uint32 internal constant ALT_CHAIN_ID = 2;
    uint32 internal constant THIRD_CHAIN_ID = 3;
    uint32 internal constant OPTIMISM_CHAIN_ID = 10;
    uint32 internal constant TEST_CHAIN_ID = 99;
    uint32 internal constant LZ_DST_CHAIN_ID = 101;
    uint32 internal constant LINEA_CHAIN_ID = 59144;
}
