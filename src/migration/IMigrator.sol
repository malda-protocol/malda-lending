// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IMendiMarket {
    function repayBorrow(uint256 repayAmount) external returns (uint256);
    function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256);
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
    function redeem(uint256 amount) external returns (uint256);
    function underlying() external view returns (address);

    function balanceOf(address sender) external view returns (uint256);
    function balanceOfUnderlying(address sender) external returns (uint256);
    function borrowBalanceStored(address sender) external view returns (uint256);
}

interface IMendiComptroller {
    function getAssetsIn(address account) external view returns (IMendiMarket[] memory);
}
