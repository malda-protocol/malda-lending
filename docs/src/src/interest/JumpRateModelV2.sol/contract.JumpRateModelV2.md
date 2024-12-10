# JumpRateModelV2
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/3408a5de0b7e9a81798e0551731f955e891c66df/src\interest\JumpRateModelV2.sol)

**Inherits:**
[IInterestRateModel](/src\interfaces\IInterestRateModel.sol\interface.IInterestRateModel.md), Ownable

Implementation of the IInterestRateModel interface for calculating interest rates


## State Variables
### blocksPerYear
The approximate number of blocks per year that is assumed by the interest rate model


```solidity
uint256 public override blocksPerYear;
```


### multiplierPerBlock
The multiplier of utilization rate that gives the slope of the interest rate


```solidity
uint256 public override multiplierPerBlock;
```


### baseRatePerBlock
The base interest rate which is the y-intercept when utilization rate is 0


```solidity
uint256 public override baseRatePerBlock;
```


### jumpMultiplierPerBlock
The multiplierPerBlock after hitting a specified utilization point


```solidity
uint256 public override jumpMultiplierPerBlock;
```


### kink
The utilization point at which the jump multiplier is applied


```solidity
uint256 public override kink;
```


### name
A name for user-friendliness, e.g. WBTC


```solidity
string public override name;
```


## Functions
### constructor

Construct an interest rate model


```solidity
constructor(
    uint256 blocksPerYear_,
    uint256 baseRatePerYear,
    uint256 multiplierPerYear,
    uint256 jumpMultiplierPerYear,
    uint256 kink_,
    address owner_,
    string memory name_
) Ownable(owner_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`blocksPerYear_`|`uint256`|The estimated number of blocks per year|
|`baseRatePerYear`|`uint256`|The base APR, scaled by 1e18|
|`multiplierPerYear`|`uint256`|The rate increase in interest wrt utilization, scaled by 1e18|
|`jumpMultiplierPerYear`|`uint256`|The multiplier per block after utilization point|
|`kink_`|`uint256`|The utilization point where the jump multiplier applies|
|`owner_`|`address`|The owner of the contract|
|`name_`|`string`|A user-friendly name for the contract|


### updateJumpRateModel

Update the parameters of the interest rate model (only callable by owner, i.e. Timelock)


```solidity
function updateJumpRateModel(
    uint256 baseRatePerYear,
    uint256 multiplierPerYear,
    uint256 jumpMultiplierPerYear,
    uint256 kink_
) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`baseRatePerYear`|`uint256`|The approximate target base APR, as a mantissa (scaled by 1e18)|
|`multiplierPerYear`|`uint256`|The rate of increase in interest rate wrt utilization (scaled by 1e18)|
|`jumpMultiplierPerYear`|`uint256`|The multiplierPerBlock after hitting a specified utilization point|
|`kink_`|`uint256`|The utilization point at which the jump multiplier is applied|


### updateBlocksPerYear

Updates the blocksPerYear in order to make interest calculations simpler


```solidity
function updateBlocksPerYear(uint256 blocksPerYear_) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`blocksPerYear_`|`uint256`|The new estimated eth blocks per year.|


### isInterestRateModel

Should return true


```solidity
function isInterestRateModel() external pure override returns (bool);
```

### utilizationRate

Calculates the utilization rate of the market


```solidity
function utilizationRate(uint256 cash, uint256 borrows, uint256 reserves) public pure override returns (uint256);
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
function getBorrowRate(uint256 cash, uint256 borrows, uint256 reserves) public view override returns (uint256);
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
    override
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


### _updateJumpRateModel

Internal function to update the parameters of the interest rate model


```solidity
function _updateJumpRateModel(
    uint256 baseRatePerYear,
    uint256 multiplierPerYear,
    uint256 jumpMultiplierPerYear,
    uint256 kink_
) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`baseRatePerYear`|`uint256`|The base APR, scaled by 1e18|
|`multiplierPerYear`|`uint256`|The rate increase wrt utilization, scaled by 1e18|
|`jumpMultiplierPerYear`|`uint256`|The multiplier per block after utilization point|
|`kink_`|`uint256`|The utilization point where the jump multiplier applies|


