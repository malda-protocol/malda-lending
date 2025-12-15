# ExponentialNoError
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\utils\ExponentialNoError.sol)

**Author:**
Compound

Exp is a struct which stores decimals with a fixed precision of 18 decimal places.
Thus, if we wanted to store the 5.1, mantissa would store 5.1e18. That is:
`Exp({mantissa: 5100000000000000000})`.


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

*Truncates the given exp to a whole number value.
For example, truncate(Exp{mantissa: 15 * expScale}) = 15*


```solidity
function truncate(Exp memory exp) internal pure returns (uint256);
```

### mul_ScalarTruncate

*Multiply an Exp by a scalar, then truncate to return an unsigned integer.*


```solidity
function mul_ScalarTruncate(Exp memory a, uint256 scalar) internal pure returns (uint256);
```

### mul_ScalarTruncateAddUInt

*Multiply an Exp by a scalar, truncate, then add an to an unsigned integer, returning an unsigned integer.*


```solidity
function mul_ScalarTruncateAddUInt(Exp memory a, uint256 scalar, uint256 addend) internal pure returns (uint256);
```

### lessThanExp

*Checks if first Exp is less than second Exp.*


```solidity
function lessThanExp(Exp memory left, Exp memory right) internal pure returns (bool);
```

### lessThanOrEqualExp

*Checks if left Exp <= right Exp.*


```solidity
function lessThanOrEqualExp(Exp memory left, Exp memory right) internal pure returns (bool);
```

### greaterThanExp

*Checks if left Exp > right Exp.*


```solidity
function greaterThanExp(Exp memory left, Exp memory right) internal pure returns (bool);
```

### isZeroExp

*returns true if Exp is exactly zero*


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

