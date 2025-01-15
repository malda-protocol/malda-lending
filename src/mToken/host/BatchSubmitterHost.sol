// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {ImErc20Host} from "../../interfaces/ImErc20Host.sol";
import {ImTokenOperationTypes} from "../../interfaces/ImToken.sol";

/**
 * @title BatchSubmitterHost
 * @notice Allows batching of repay, liquidate, and mint operations on the host chain
 */
contract BatchSubmitterHost {
    struct BatchOperation {
        address mToken;      // The mToken address to interact with
        uint256 amount;      // Amount for the operation
        bytes data;          // Additional data (like journal data for repay)
        uint8 opType;        // 0: repay, 1: liquidate, 2: mint
        address borrower;    // For liquidate operations
        address collateral;  // For liquidate operations
    }

    /**
     * @notice Execute multiple operations in a single transaction
     * @param operations Array of operations to execute
     */
    function batchExecute(BatchOperation[] calldata operations) external {
        uint256 length = operations.length;
        for (uint256 i = 0; i < length;) {
            BatchOperation calldata op = operations[i];
            
            if (op.opType == 0) {
                // Repay
                ImErc20Host(op.mToken).repay(op.amount);
            } else if (op.opType == 1) {
                // Liquidate
                ImErc20Host(op.mToken).liquidateBorrow(
                    op.borrower,
                    op.amount,
                    op.collateral
                );
            } else if (op.opType == 2) {
                // Mint
                ImErc20Host(op.mToken).mint(op.amount);
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Execute multiple repayExternal operations in a single transaction
     * @param mToken The mToken address
     * @param journalData The journal data for verification
     * @param seal The seal data
     * @param amounts Array of amounts to repay
     * @param positions Array of positions
     */
    function batchRepayExternal(
        address mToken,
        bytes calldata journalData,
        bytes calldata seal,
        uint256[] calldata amounts,
        address[] calldata positions
    ) external {
        ImErc20Host(mToken).repayExternal(
            journalData,
            seal,
            amounts,
            positions
        );
    }
} 