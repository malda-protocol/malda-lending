# IOperatorData
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/interfaces/IOperator.sol)

**Author:**
Merge Layers Inc.

Data definitions used by Operator contracts


## Structs
### Market

```solidity
struct Market {
    // Whether or not this market is listed
    bool isListed;
    //  Multiplier representing the most one can borrow against their collateral in this market.
    //  For instance, 0.9 to allow borrowing 90% of collateral value.
    //  Must be between 0 and 1, and stored as a mantissa.
    uint256 collateralFactorMantissa;
    // Per-market mapping of "accounts in this asset"
    mapping(address => bool) accountMembership;
}
```

