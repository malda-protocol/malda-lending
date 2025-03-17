// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Comptroller} from "@mendi/Comptroller.sol";
import {CErc20} from "@mendi/CErc20.sol";
import {CToken} from "@mendi/CToken.sol";
import {Operator} from "src/Operator/Operator.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";

contract Migrator {
    using SafeERC20 for IERC20;

    struct MigrationParams {
        address mendiComptroller;
        address maldaOperator;
    }

    struct Position {
        address mendiMarket;
        address maldaMarket;
        uint256 collateralAmount;
        uint256 borrowAmount;
    }

    /**
     * @notice Migrates all positions from Mendi to Malda
     * @param params Migration parameters containing protocol addresses
     */
    function migrateAllPositions(MigrationParams calldata params) external {
        // 1. Collect all positions from Mendi
        Position[] memory positions = _collectMendiPositions(params);
        require(positions.length > 0, "No Mendi positions");

        // 2. Mint mTokens in all v2 markets
        for (uint256 i = 0; i < positions.length; i++) {
            Position memory position = positions[i];
            if (position.collateralAmount > 0) {
                mErc20Host(position.maldaMarket).mintMigration(
                    position.collateralAmount,
                    msg.sender
                );

                // Enter market
                address[] memory marketsToEnter = new address[](1);
                marketsToEnter[0] = position.maldaMarket;
                Operator(params.maldaOperator).enterMarkets(marketsToEnter);
            }
        }

        // 3. Borrow from all necessary v2 markets
        for (uint256 i = 0; i < positions.length; i++) {
            Position memory position = positions[i];
            if (position.borrowAmount > 0) {
                mErc20Host(position.maldaMarket).borrow(position.borrowAmount);
            }
        }

        // 4. Repay all debts in v1 markets
        for (uint256 i = 0; i < positions.length; i++) {
            Position memory position = positions[i];
            if (position.borrowAmount > 0) {
                IERC20 underlying = IERC20(CErc20(position.mendiMarket).underlying());
                underlying.approve(position.mendiMarket, position.borrowAmount);
                require(
                    CErc20(position.mendiMarket).repayBorrow(position.borrowAmount) == 0,
                    "Mendi repay failed"
                );
            }
        }

        // 5. Withdraw and transfer all collateral from v1 to v2
        for (uint256 i = 0; i < positions.length; i++) {
            Position memory position = positions[i];
            if (position.collateralAmount > 0) {
                // Withdraw from v1
                require(
                    CErc20(position.mendiMarket).redeemUnderlying(position.collateralAmount) == 0,
                    "Mendi withdraw failed"
                );

                // Transfer to v2
                IERC20 underlying = IERC20(CErc20(position.mendiMarket).underlying());
                underlying.safeTransfer(position.maldaMarket, position.collateralAmount);
            }
        }
    }

    /**
     * @notice Collects all user positions from Mendi
     */
    function _collectMendiPositions(MigrationParams memory params) 
        private  
        returns (Position[] memory) 
    {
        Comptroller mendi = Comptroller(params.mendiComptroller);
        CToken[] memory mendiMarkets = mendi.getAssetsIn(msg.sender);
        Position[] memory positions = new Position[](mendiMarkets.length);
        uint256 positionCount;

        for (uint256 i = 0; i < mendiMarkets.length; i++) {
            CToken mendiMarket = mendiMarkets[i];
            uint256 collateralAmount = mendiMarket.balanceOfUnderlying(msg.sender);
            uint256 borrowAmount = mendiMarket.borrowBalanceStored(msg.sender);

            if (collateralAmount > 0 || borrowAmount > 0) {
                address maldaMarket = _getMaldaMarket(
                    params.maldaOperator,
                    CErc20(address(mendiMarket)).underlying()
                );
                require(maldaMarket != address(0), "Malda market not found");

                positions[positionCount++] = Position({
                    mendiMarket: address(mendiMarket),
                    maldaMarket: maldaMarket,
                    collateralAmount: collateralAmount,
                    borrowAmount: borrowAmount
                });
            }
        }

        // Resize array to actual position count
        assembly {
            mstore(positions, positionCount)
        }
        return positions;
    }

    /**
     * @notice Gets corresponding Malda market for a given underlying
     */
    function _getMaldaMarket(address maldaOperator, address underlying) 
        private 
        view 
        returns (address) 
    {
        address[] memory maldaMarkets = Operator(maldaOperator).getAllMarkets();
        
        for (uint256 i = 0; i < maldaMarkets.length; i++) {
            if (mErc20Host(maldaMarkets[i]).underlying() == underlying) {
                return maldaMarkets[i];
            }
        }
        
        return address(0);
    }
}