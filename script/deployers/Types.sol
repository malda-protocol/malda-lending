// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

struct DeployConfig {
    DeployerConfig deployer;
    uint32 chainId;
    bool isHost;
    OracleConfig oracle; // Only used if isHost is true
    ZkVerifierConfig zkVerifier;
    uint32[] allowedChains; // Only used if isHost is true
    Role[] roles;
    Market[] markets;
}

struct DeployerConfig {
    address owner;
    string salt;
}

struct OracleConfig {
    string oracleType;
    uint256 stalenessPeriod;
    address usdcFeed;
    address wethFeed;
}

struct Market {
    uint256 borrowCap;
    uint256 borrowRateMaxMantissa;
    uint256 collateralFactor;
    uint8 decimals;
    InterestConfig interestModel;
    string name;
    address priceFeed;
    uint256 supplyCap;
    string symbol;
    address underlying;
}

struct InterestConfig {
    uint256 baseRate;
    uint256 blocksPerYear;
    uint256 jumpMultiplier;
    uint256 kink;
    uint256 multiplier;
    string name;
}

struct Role {
    address[] accounts;
    string roleName;
}

struct ZkVerifierConfig {
    bytes32 imageId;
    address verifierAddress;
}
