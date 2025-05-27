# Migrator
[Git Source](https://github.com/malda-protocol/malda-lending/blob/413dc9221d099e8e0b7a9a3f94769f4666aaf31b/src\migration\Migrator.sol)


## Functions
### getAllCollateralMarkets

Get all markets where `params.userV1` has collateral in on Mendi


```solidity
function getAllCollateralMarkets(MigrationParams calldata params) external view returns (address[] memory markets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params`|`MigrationParams`|Migration parameters containing protocol addresses|


### getAllPositions

Get all `migratable` positions from Mendi to Malda


```solidity
function getAllPositions(MigrationParams calldata params) external returns (Position[] memory positions);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params`|`MigrationParams`|Migration parameters containing protocol addresses|


### migrateAllPositions

Migrates all positions from Mendi to Malda


```solidity
function migrateAllPositions(MigrationParams calldata params) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params`|`MigrationParams`|Migration parameters containing protocol addresses|


### _collectMendiPositions

Collects all user positions from Mendi


```solidity
function _collectMendiPositions(MigrationParams memory params) private returns (Position[] memory);
```

### _getMaldaMarket

Gets corresponding Malda market for a given underlying


```solidity
function _getMaldaMarket(address maldaOperator, address underlying) private view returns (address);
```

## Structs
### MigrationParams

```solidity
struct MigrationParams {
    address mendiComptroller;
    address maldaOperator;
    address userV1;
    address userV2;
}
```

### Position

```solidity
struct Position {
    address mendiMarket;
    address maldaMarket;
    uint256 collateralUnderlyingAmount;
    uint256 borrowAmount;
}
```

