# IInterestRateModel
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\interfaces\IInterestRateModel.sol)

Interface for the interest rate contracts


## Functions
### isInterestRateModel

Should return true


```solidity
function isInterestRateModel() external view returns (bool);
```

### blocksPerYear

The approximate number of blocks per year that is assumed by the interest rate model


```solidity
function blocksPerYear() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The number of blocks per year|


### multiplierPerBlock

The multiplier of utilization rate that gives the slope of the interest rate


```solidity
function multiplierPerBlock() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The multiplier per block|


### baseRatePerBlock

The base interest rate which is the y-intercept when utilization rate is 0


```solidity
function baseRatePerBlock() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The base rate per block|


### jumpMultiplierPerBlock

The multiplierPerBlock after hitting a specified utilization point


```solidity
function jumpMultiplierPerBlock() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The jump multiplier per block|


### kink

The utilization point at which the jump multiplier is applied


```solidity
function kink() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The utilization point (kink)|


### name

A name for user-friendliness, e.g. WBTC


```solidity
function name() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The name of the interest rate model|


### utilizationRate

Calculates the utilization rate of the market


```solidity
function utilizationRate(uint256 cash, uint256 borrows, uint256 reserves) external pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cash`|`uint256`|The total cash in the market|
|`borrows`|`uint256`|The total borrows in the market|
|`reserves`|`uint256`|The total reserves in the market|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The utilization rate as a mantissa between [0, 1e18]|


### getBorrowRate

Returns the current borrow rate per block for the market


```solidity
function getBorrowRate(uint256 cash, uint256 borrows, uint256 reserves) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cash`|`uint256`|The total cash in the market|
|`borrows`|`uint256`|The total borrows in the market|
|`reserves`|`uint256`|The total reserves in the market|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current borrow rate per block, scaled by 1e18|


### getSupplyRate

Returns the current supply rate per block for the market


```solidity
function getSupplyRate(uint256 cash, uint256 borrows, uint256 reserves, uint256 reserveFactorMantissa)
    external
    view
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cash`|`uint256`|The total cash in the market|
|`borrows`|`uint256`|The total borrows in the market|
|`reserves`|`uint256`|The total reserves in the market|
|`reserveFactorMantissa`|`uint256`|The current reserve factor for the market|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current supply rate per block, scaled by 1e18|


## Events
### NewInterestParams
Emitted when interest rate parameters are updated


```solidity
event NewInterestParams(
    uint256 baseRatePerBlock, uint256 multiplierPerBlock, uint256 jumpMultiplierPerBlock, uint256 kink
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`baseRatePerBlock`|`uint256`|The base rate per block|
|`multiplierPerBlock`|`uint256`|The multiplier per block for the interest rate slope|
|`jumpMultiplierPerBlock`|`uint256`|The multiplier after hitting the kink|
|`kink`|`uint256`|The utilization point where the jump multiplier is applied|

