# IOperatorData
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ecf312765013f0471a4707ec1225b346cdb0a535/src\interfaces\IOperator.sol)


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

