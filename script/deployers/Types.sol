// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

struct ChainConfig {
    uint32 id;
    string name;
    string rpcAlias;
    bool isHost;
    OracleConfig oracle;
}

struct OracleConfig {
    string oracleType;
    uint256 stalenessPeriod;
    address usdcFeed;
    address wethFeed;
} 