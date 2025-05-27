# mErc20Immutable
[Git Source](https://github.com/malda-protocol/malda-lending/blob/413dc9221d099e8e0b7a9a3f94769f4666aaf31b/src\mToken\mErc20Immutable.sol)

**Inherits:**
[mErc20](/src\mToken\mErc20.sol\abstract.mErc20.md)


## Functions
### constructor

Constructs the new money market


```solidity
constructor(
    address underlying_,
    address operator_,
    address interestRateModel_,
    uint256 initialExchangeRateMantissa_,
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    address payable admin_
);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`underlying_`|`address`|The address of the underlying asset|
|`operator_`|`address`|The address of the Operator|
|`interestRateModel_`|`address`|The address of the interest rate model|
|`initialExchangeRateMantissa_`|`uint256`|The initial exchange rate, scaled by 1e18|
|`name_`|`string`|ERC-20 name of this token|
|`symbol_`|`string`|ERC-20 symbol of this token|
|`decimals_`|`uint8`|ERC-20 decimal precision of this token|
|`admin_`|`address payable`|Address of the administrator of this token|


