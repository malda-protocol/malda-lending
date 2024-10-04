# IOperatorData
[Git Source](https://github.com/malda-protocol/malda-lending/blob/00d040411754d9ec62fde1c26b93be292ca3e328/src\interfaces\IOperator.sol)


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

