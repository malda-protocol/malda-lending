# IOperatorData
[Git Source](https://github.com/malda-protocol/malda-lending/blob/6ea8fcbab45a04b689cc49c81c736245cab92c98/src\interfaces\IOperator.sol)


## Structs
### Market

```solidity
struct Market {
    bool isListed;
    uint256 collateralFactorMantissa;
    mapping(address => bool) accountMembership;
    bool isMalded;
}
```

