# IOperatorData
[Git Source](https://github.com/malda-protocol/malda-lending/blob/b62e113034d94e880ebb241b8fad49eb27118646/src\interfaces\IOperator.sol)


## Structs
### Market

```solidity
struct Market {
    bool isListed;
    uint256 collateralFactorMantissa;
    mapping(address => bool) accountMembership;
    bool isComped;
}
```

