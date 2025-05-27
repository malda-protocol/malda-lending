# IOperatorData
[Git Source](https://github.com/malda-protocol/malda-lending/blob/7babde64a69e0bddbfb8ee96e52976dd39acebdd/src\interfaces\IOperator.sol)


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

