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

// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

interface IPohVerifier {
    /**
     * @notice Check if the provided signature has been signed by signer
     * @dev human is supposed to be a POH address, this is what is being signed by the POH API
     * @param signature The signature to check
     * @param human the address for which the signature has been crafted
     * @return True if the signature was made by signer, false otherwise
     */
    function verify(bytes memory signature, address human) external view returns (bool);

    /**
     * @notice Returns the signer's address
     */
    function getSigner() external view returns (address);
}
