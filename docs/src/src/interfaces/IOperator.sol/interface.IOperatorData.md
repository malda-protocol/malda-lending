# IOperatorData
[Git Source](https://github.com/malda-protocol/malda-lending/blob/413dc9221d099e8e0b7a9a3f94769f4666aaf31b/src\interfaces\IOperator.sol)


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

