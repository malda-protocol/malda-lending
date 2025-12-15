# mErc20Upgradable
[Git Source](https://github.com/malda-protocol/malda-lending/blob/6ea8fcbab45a04b689cc49c81c736245cab92c98/src\mToken\mErc20Upgradable.sol)

**Inherits:**
[mErc20](/src\mToken\mErc20.sol\contract.mErc20.md), Initializable


## Functions
### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### proxyInitialize

Initialize the new money market


```solidity
function proxyInitialize(
    address underlying_,
    address operator_,
    address interestRateModel_,
    uint256 initialExchangeRateMantissa_,
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    address payable admin_
) public;
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
|`admin_`|`address payable`||


