# IOperatorData
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/interfaces/IOperator.sol)

**Title:**
Operator storage structures

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

