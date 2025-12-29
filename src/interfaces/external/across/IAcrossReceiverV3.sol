// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|
*/

interface IAcrossReceiverV3 {
    /// @notice handles AcrossV3 SpokePool message
    /// @param tokenSent the token address received
    /// @param amount the token amount
    /// @param relayer the relayer submitting the message (unused)
    /// @param message the custom message sent from source
    function handleV3AcrossMessage(address tokenSent, uint256 amount, address relayer, bytes memory message) external;
}
