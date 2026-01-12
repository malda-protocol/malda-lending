// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

contract MockMToken {
    struct Snapshot {
        uint256 tokenBalance;
        uint256 borrowBalance;
        uint256 exchangeRate;
    }

    mapping(address => Snapshot) private _snapshots;
    mapping(address => uint256) private _borrowBalanceStored;

    uint256 public totalBorrows;
    uint256 public totalSupply;
    uint256 public totalUnderlying;
    uint256 public exchangeRateStored;
    uint256 public reserveFactorMantissa;
    address public operator;
    bool public accrueInterestCalled;

    function setSnapshot(address account, uint256 tokenBalance, uint256 borrowBalance, uint256 exchangeRate) external {
        _snapshots[account] = Snapshot(tokenBalance, borrowBalance, exchangeRate);
        _borrowBalanceStored[account] = borrowBalance;
    }

    function setBorrowBalanceStored(address account, uint256 borrowBalance) external {
        _borrowBalanceStored[account] = borrowBalance;
    }

    function setTotals(uint256 totalBorrows_, uint256 totalSupply_, uint256 totalUnderlying_) external {
        totalBorrows = totalBorrows_;
        totalSupply = totalSupply_;
        totalUnderlying = totalUnderlying_;
    }

    function setExchangeRateStored(uint256 exchangeRate) external {
        exchangeRateStored = exchangeRate;
    }

    function setReserveFactorMantissa(uint256 reserveFactor) external {
        reserveFactorMantissa = reserveFactor;
    }

    function setOperator(address operator_) external {
        operator = operator_;
    }

    function accrueInterest() external {
        accrueInterestCalled = true;
    }

    function getAccountSnapshot(address account) external view returns (uint256, uint256, uint256) {
        Snapshot memory snapshot = _snapshots[account];
        return (snapshot.tokenBalance, snapshot.borrowBalance, snapshot.exchangeRate);
    }

    function borrowBalanceStored(address account) external view returns (uint256) {
        return _borrowBalanceStored[account];
    }
}
