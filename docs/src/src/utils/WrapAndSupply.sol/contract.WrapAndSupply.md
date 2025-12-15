# WrapAndSupply
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\utils\WrapAndSupply.sol)


## State Variables
### wrappedNative

```solidity
IWrappedNative public immutable wrappedNative;
```


## Functions
### constructor


```solidity
constructor(address _wrappedNative);
```

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
|`minAmount`|`uint256`||


### wrapAndSupplyOnExtensionMarket

Wraps a native coin into its wrapped version and supplies on an extension market


```solidity
function wrapAndSupplyOnExtensionMarket(address mTokenGateway, address receiver, bytes4 selector) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mTokenGateway`|`address`|The market address|
|`receiver`|`address`|The receiver|
|`selector`|`bytes4`|The host chain function selector|


### _wrap


```solidity
function _wrap() private returns (uint256);
```

## Events
### WrappedAndSupplied

```solidity
event WrappedAndSupplied(address indexed sender, address indexed receiver, address indexed market, uint256 amount);
```

## Errors
### WrapAndSupply_AddressNotValid

```solidity
error WrapAndSupply_AddressNotValid();
```

### WrapAndSupply_AmountNotValid

```solidity
error WrapAndSupply_AmountNotValid();
```

