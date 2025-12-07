// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|
*/

/// @title Minimal ERC20 approve interface
/// @author Merge Layers Inc.
/// @notice Exposes approve to perform safe allowance updates
interface IToken {
    /// @notice Approves spender for an allowance amount
    /// @param spender Address allowed to spend
    /// @param amount Allowance amount
    /// @return success True if approve succeeded
    function approve(address spender, uint256 amount) external returns (bool);
}

/// @title SafeApprove
/// @author Merge Layers Inc.
/// @notice Library for safely setting ERC20 approvals
library SafeApprove {
    /// @notice Thrown when target is not a contract
    error SafeApprove_NoContract();

    /// @notice Thrown when an approve call fails
    error SafeApprove_Failed();

    /// @notice Safely sets allowance to zero then desired value
    /// @param token Token to approve
    /// @param to Spender address
    /// @param value New allowance to set
    function safeApprove(address token, address to, uint256 value) internal {
        require(token.code.length > 0, SafeApprove_NoContract());

        bool success;
        bytes memory data;
        (success, data) = token.call(abi.encodeCall(IToken.approve, (to, 0)));
        require(success && (data.length == 0 || abi.decode(data, (bool))), SafeApprove_Failed());

        if (value > 0) {
            (success, data) = token.call(abi.encodeCall(IToken.approve, (to, value)));
            require(success && (data.length == 0 || abi.decode(data, (bool))), SafeApprove_Failed());
        }
    }
}
