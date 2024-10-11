# Exponential
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ecf312765013f0471a4707ec1225b346cdb0a535/src\libraries\Exponential.sol)


## State Variables
### expScale

```solidity
uint256 constant expScale = 1e18;
```


### doubleScale

```solidity
uint256 constant doubleScale = 1e36;
```


### halfExpScale

```solidity
uint256 constant halfExpScale = expScale / 2;
```


### mantissaOne

```solidity
uint256 constant mantissaOne = expScale;
```


## Functions
### truncate


```solidity
function truncate(Exp memory exp) internal pure returns (uint256);
```

### mul_ScalarTruncate


```solidity
function mul_ScalarTruncate(Exp memory a, uint256 scalar) internal pure returns (uint256);
```

### mul_ScalarTruncateAddUInt


```solidity
function mul_ScalarTruncateAddUInt(Exp memory a, uint256 scalar, uint256 addend) internal pure returns (uint256);
```

### lessThanExp


```solidity
function lessThanExp(Exp memory left, Exp memory right) internal pure returns (bool);
```

### lessThanOrEqualExp


```solidity
function lessThanOrEqualExp(Exp memory left, Exp memory right) internal pure returns (bool);
```

### greaterThanExp


```solidity
function greaterThanExp(Exp memory left, Exp memory right) internal pure returns (bool);
```

### isZeroExp


```solidity
function isZeroExp(Exp memory value) internal pure returns (bool);
```

### safe224


```solidity
function safe224(uint256 n, string memory errorMessage) internal pure returns (uint224);
```

### safe32


```solidity
function safe32(uint256 n, string memory errorMessage) internal pure returns (uint32);
```

### add_


```solidity
function add_(Exp memory a, Exp memory b) internal pure returns (Exp memory);
```

### add_


```solidity
function add_(Double memory a, Double memory b) internal pure returns (Double memory);
```

### add_


```solidity
function add_(uint256 a, uint256 b) internal pure returns (uint256);
```

### sub_


```solidity
function sub_(Exp memory a, Exp memory b) internal pure returns (Exp memory);
```

### sub_


```solidity
function sub_(Double memory a, Double memory b) internal pure returns (Double memory);
```

### sub_


```solidity
function sub_(uint256 a, uint256 b) internal pure returns (uint256);
```

### mul_


```solidity
function mul_(Exp memory a, Exp memory b) internal pure returns (Exp memory);
```

### mul_


```solidity
function mul_(Exp memory a, uint256 b) internal pure returns (Exp memory);
```

### mul_


```solidity
function mul_(uint256 a, Exp memory b) internal pure returns (uint256);
```

### mul_


```solidity
function mul_(Double memory a, Double memory b) internal pure returns (Double memory);
```

### mul_


```solidity
function mul_(Double memory a, uint256 b) internal pure returns (Double memory);
```

### mul_


```solidity
function mul_(uint256 a, Double memory b) internal pure returns (uint256);
```

### mul_


```solidity
function mul_(uint256 a, uint256 b) internal pure returns (uint256);
```

### div_


```solidity
function div_(Exp memory a, Exp memory b) internal pure returns (Exp memory);
```

### div_


```solidity
function div_(Exp memory a, uint256 b) internal pure returns (Exp memory);
```

### div_


```solidity
function div_(uint256 a, Exp memory b) internal pure returns (uint256);
```

### div_


```solidity
function div_(Double memory a, Double memory b) internal pure returns (Double memory);
```

### div_


```solidity
function div_(Double memory a, uint256 b) internal pure returns (Double memory);
```

### div_


```solidity
function div_(uint256 a, Double memory b) internal pure returns (uint256);
```

### div_


```solidity
function div_(uint256 a, uint256 b) internal pure returns (uint256);
```

### fraction


```solidity
function fraction(uint256 a, uint256 b) internal pure returns (Double memory);
```

## Structs
### Exp

```solidity
struct Exp {
    uint256 mantissa;
}
```

### Double

```solidity
struct Double {
    uint256 mantissa;
}
```

