# Migrator
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\migration\Migrator.sol)


## State Variables
### allowedMarkets

```solidity
mapping(address => bool) public allowedMarkets;
```


### MENDI_COMPTROLLER

```solidity
address public constant MENDI_COMPTROLLER = 0x1b4d3b0421dDc1eB216D230Bc01527422Fb93103;
```


### MALDA_OPERATOR

```solidity
address public immutable MALDA_OPERATOR;
```


## Functions
### constructor


```solidity
constructor(address _operator);
```

### getAllCollateralMarkets

Get all markets where `user` has collateral in on Mendi


```solidity
function getAllCollateralMarkets(address user) external view returns (address[] memory markets);
```

### getAllPositions

Get all `migratable` positions from Mendi to Malda for `user`


```solidity
function getAllPositions(address user) external returns (Position[] memory positions);
```

### migrateAllPositions

Migrates all positions from Mendi to Malda


```solidity
function migrateAllPositions() external;
```

### _collectMendiPositions

Collects all user positions from Mendi


```solidity
function _collectMendiPositions(address user) private returns (Position[] memory);
```

### _getMaldaMarket

Gets corresponding Malda market for a given underlying


```solidity
function _getMaldaMarket(address underlying) private view returns (address);
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

