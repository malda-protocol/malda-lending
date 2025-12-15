# IMendiMarket
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\migration\IMigrator.sol)


## Functions
### repayBorrow


```solidity
function repayBorrow(uint256 repayAmount) external returns (uint256);
```

### repayBorrowBehalf


```solidity
function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256);
```

### redeemUnderlying


```solidity
function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
```

### redeem


```solidity
function redeem(uint256 amount) external returns (uint256);
```

### underlying


```solidity
function underlying() external view returns (address);
```

### balanceOf


```solidity
function balanceOf(address sender) external view returns (uint256);
```

### balanceOfUnderlying


```solidity
function balanceOfUnderlying(address sender) external returns (uint256);
```

### borrowBalanceStored


```solidity
function borrowBalanceStored(address sender) external view returns (uint256);
```

