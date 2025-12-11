# Migrator
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/migration/Migrator.sol)

**Inherits:**
[ExponentialNoError](/src/utils/ExponentialNoError.sol/abstract.ExponentialNoError.md)

**Title:**
Migrator

**Author:**
Merge Layers Inc.

Contract for migrating positions from Mendi to Malda


## State Variables
### MENDI_COMPTROLLER
Mendi Comptroller address


```solidity
address public constant MENDI_COMPTROLLER = 0x1b4d3b0421dDc1eB216D230Bc01527422Fb93103
```


### MALDA_OPERATOR
Malda Operator address


```solidity
address public immutable MALDA_OPERATOR
```


### allowedMarkets
Mapping of allowed markets


```solidity
mapping(address market => bool allowed) public allowedMarkets
```


## Functions
### constructor

Initializes the migrator with the operator address


```solidity
constructor(address _operator) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operator`|`address`|Address of the Malda operator|


### getAllPositions

Get all `migratable` positions from Mendi to Malda for `user`


```solidity
function getAllPositions(address user) external returns (Position[] memory positions);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`positions`|`Position[]`|Array of positions|


### migrateAllPositions

Migrates all positions from Mendi to Malda


```solidity
function migrateAllPositions() external;
```

### getAllCollateralMarkets

Get all markets where `user` has collateral in on Mendi


```solidity
function getAllCollateralMarkets(address user) external view returns (address[] memory markets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`markets`|`address[]`|Array of market addresses|


### _mintAll

Mints in v2 markets for all positions with collateral


```solidity
function _mintAll(Position[] memory positions) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positions`|`Position[]`|Positions to process|


### _borrowAll

Borrows in v2 markets for all positions requiring debt


```solidity
function _borrowAll(Position[] memory positions) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positions`|`Position[]`|Positions to process|


### _repayAll

Repays debts in v1 markets for all positions


```solidity
function _repayAll(Position[] memory positions) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positions`|`Position[]`|Positions to process|


### _withdrawAll

Withdraws collateral from v1 and transfers to v2 for all positions


```solidity
function _withdrawAll(Position[] memory positions) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positions`|`Position[]`|Positions to process|


### _collectMendiPositions

Collects all user positions from Mendi


```solidity
function _collectMendiPositions(address user) private returns (Position[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Position[]`|Array of positions|


### _getMaldaMarket

Gets corresponding Malda market for a given underlying


```solidity
function _getMaldaMarket(address underlying) private view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`underlying`|`address`|The underlying token address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The Malda market address|


## Errors
### Migrator_AddressNotValid
Error thrown when address is not valid


```solidity
error Migrator_AddressNotValid();
```

### Migrator_RedeemAmountNotValid
Error thrown when redeem amount is not valid


```solidity
error Migrator_RedeemAmountNotValid();
```

## Structs
### Position

```solidity
struct Position {
    address mendiMarket;
    address maldaMarket;
    uint256 collateralUnderlyingAmount;
    uint256 borrowAmount;
}
```

