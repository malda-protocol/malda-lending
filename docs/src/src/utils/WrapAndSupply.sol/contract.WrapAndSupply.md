# WrapAndSupply
[Git Source](https://github.com/malda-protocol/malda-lending/blob/034fc0e2fca466a96bdb4527b71e15ddea321646/src/utils/WrapAndSupply.sol)

**Author:**
Malda Protocol

Wraps native coins and supplies to host or extension markets in a single call.


## State Variables
### WRAPPED_NATIVE
The wrapped native coin contract


```solidity
IWrappedNative public immutable WRAPPED_NATIVE
```


## Functions
### constructor

Initializes the helper with the wrapped native token address


```solidity
constructor(address _wrappedNative) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_wrappedNative`|`address`|Wrapped native token (e.g., WETH) contract address|


### wrapAndSupplyOnHostMarket

Wraps a native coin into its wrapped version and supplies on a host market


```solidity
function wrapAndSupplyOnHostMarket(address mToken, address receiver, uint256 minAmount) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market address|
|`receiver`|`address`|The mToken receiver|
|`minAmount`|`uint256`|The minimum amount of mTokens expected|


### wrapAndSupplyOnExtensionMarket

Wraps a native coin into its wrapped version and supplies on an extension market


```solidity
function wrapAndSupplyOnExtensionMarket(address mTokenGateway, address receiver, bytes4 selector) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mTokenGateway`|`address`|The extension market address|
|`receiver`|`address`|The receiver|
|`selector`|`bytes4`|The host chain function selector|


### _wrap

Wraps a native coin into its wrapped version


```solidity
function _wrap(uint256 amountToWrap) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountToWrap`|`uint256`|The amount of native coin to wrap|


## Events
### WrappedAndSupplied
Emitted when native assets are wrapped and supplied to a market


```solidity
event WrappedAndSupplied(address indexed sender, address indexed receiver, address indexed market, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|The caller providing native funds|
|`receiver`|`address`|The account receiving the minted mTokens|
|`market`|`address`|The market that received the wrapped assets|
|`amount`|`uint256`|The amount of native coin wrapped and supplied|

## Errors
### WrapAndSupply_AddressNotValid
Error thrown when the address is not valid


```solidity
error WrapAndSupply_AddressNotValid();
```

### WrapAndSupply_AmountNotValid
Error thrown when the amount is not valid


```solidity
error WrapAndSupply_AmountNotValid();
```

