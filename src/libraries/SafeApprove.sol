// Copyright (c) 2025 Merge Layers Inc.
//
// This source code is licensed under the Business Source License 1.1
// (the "License"); you may not use this file except in compliance with the
// License. You may obtain a copy of the License at
//
//     https://github.com/malda-protocol/malda-lending/blob/main/LICENSE-BSL
//
// See the License for the specific language governing permissions and
// limitations under the License.
//
// This file contains code derived from or inspired by Compound V2,
// originally licensed under the BSD 3-Clause License. See LICENSE-COMPOUND-V2
// for original license terms and attributions.

// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|                            
*/

interface IToken {
    function approve(address spender, uint256 amount) external returns (bool);
}

library SafeApprove {
    error SafeApprove_NoContract();
    error SafeApprove_Failed();

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
