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

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IInterestRateModel} from "src/interfaces/IInterestRateModel.sol";

/*
 _____ _____ __    ____  _____
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|
*/

/// @title JumpRateModelV4
/// @author Merge Layers Inc.
/// @notice Implementation of the IInterestRateModel interface for calculating interest rates
contract JumpRateModelV4 is IInterestRateModel, Ownable {
    // ----------- STORAGE ------------

    /// @inheritdoc IInterestRateModel
    uint256 public override blocksPerYear;

    /// @inheritdoc IInterestRateModel
    uint256 public override multiplierPerBlock;

    /// @inheritdoc IInterestRateModel
    uint256 public override baseRatePerBlock;

    /// @inheritdoc IInterestRateModel
    uint256 public override jumpMultiplierPerBlock;

    /// @inheritdoc IInterestRateModel
    uint256 public override kink;

    /// @inheritdoc IInterestRateModel
    string public override name;

    // ----------- ERRORS ------------

    /// @notice Error thrown when multiplier is not valid
    error JumpRateModelV4_MultiplierNotValid();
    /// @notice Error thrown when input is not valid
    error JumpRateModelV4_InputNotValid();

    /**
     * @notice Construct an interest rate model
     * @param blocksPerYear_ The estimated number of blocks per year
     * @param baseRatePerBlock_ The base APR, scaled by 1e18
     * @param multiplierPerBlock_ The rate increase in interest wrt utilization, scaled by 1e18
     * @param jumpMultiplierPerBlock_ The multiplier per block after utilization point
     * @param kink_ The utilization point where the jump multiplier applies
     * @param owner_ The owner of the contract
     * @param name_ A user-friendly name for the contract
     */
    constructor(
        uint256 blocksPerYear_,
        uint256 baseRatePerBlock_,
        uint256 multiplierPerBlock_,
        uint256 jumpMultiplierPerBlock_,
        uint256 kink_,
        address owner_,
        string memory name_
    ) Ownable(owner_) {
        blocksPerYear = blocksPerYear_;
        name = name_;
        _updateJumpRateModelWithoutComputation(baseRatePerBlock_, multiplierPerBlock_, jumpMultiplierPerBlock_, kink_);
    }

    // ----------- OWNER ------------
    /**
     * @notice Update the parameters of the interest rate model (only callable by owner, i.e. Timelock)
     * @param baseRatePerBlock_ The approximate target base APR, as a mantissa (scaled by 1e18)
     * @param multiplierPerBlock_ The rate of increase in interest rate wrt utilization (scaled by 1e18)
     * @param jumpMultiplierPerBlock_ The multiplierPerBlock after hitting a specified utilization point
     * @param kink_ The utilization point at which the jump multiplier is applied
     */
    function updateJumpRateModelDirect(
        uint256 baseRatePerBlock_,
        uint256 multiplierPerBlock_,
        uint256 jumpMultiplierPerBlock_,
        uint256 kink_
    ) external onlyOwner {
        _updateJumpRateModelWithoutComputation(baseRatePerBlock_, multiplierPerBlock_, jumpMultiplierPerBlock_, kink_);
    }

    /**
     * @notice Update the parameters of the interest rate model (only callable by owner, i.e. Timelock)
     * @param baseRatePerYear The approximate target base APR, as a mantissa (scaled by 1e18)
     * @param multiplierPerYear The rate of increase in interest rate wrt utilization (scaled by 1e18)
     * @param jumpMultiplierPerYear The multiplierPerBlock after hitting a specified utilization point
     * @param kink_ The utilization point at which the jump multiplier is applied
     */
    function updateJumpRateModel(
        uint256 baseRatePerYear,
        uint256 multiplierPerYear,
        uint256 jumpMultiplierPerYear,
        uint256 kink_
    ) external onlyOwner {
        _updateJumpRateModel(baseRatePerYear, multiplierPerYear, jumpMultiplierPerYear, kink_);
    }

    /**
     * @notice Updates the blocksPerYear in order to make interest calculations simpler
     * @param blocksPerYear_ The new estimated eth blocks per year.
     */
    function updateBlocksPerYear(uint256 blocksPerYear_) external onlyOwner {
        blocksPerYear = blocksPerYear_;
        emit BlocksPerYearUpdated(blocksPerYear_);
    }

    // ----------- PUBLIC ------------
    /// @inheritdoc IInterestRateModel
    function getSupplyRate(uint256 cash, uint256 borrows, uint256 reserves, uint256 reserveFactorMantissa)
        external
        view
        override
        returns (uint256)
    {
        uint256 oneMinusReserveFactor = 1e18 - reserveFactorMantissa;
        uint256 borrowRate = getBorrowRate(cash, borrows, reserves);
        uint256 rateToPool = borrowRate * oneMinusReserveFactor / 1e18;
        return utilizationRate(cash, borrows, reserves) * rateToPool / 1e18;
    }

    /// @inheritdoc IInterestRateModel
    function isInterestRateModel() external pure override returns (bool) {
        return true;
    }

    /// @inheritdoc IInterestRateModel
    function getBorrowRate(uint256 cash, uint256 borrows, uint256 reserves) public view override returns (uint256) {
        uint256 util = utilizationRate(cash, borrows, reserves);

        if (util <= kink) {
            return util * multiplierPerBlock / 1e18 + baseRatePerBlock;
        } else {
            uint256 normalRate = kink * multiplierPerBlock / 1e18 + baseRatePerBlock;
            uint256 excessUtil = util - kink;
            return excessUtil * jumpMultiplierPerBlock / 1e18 + normalRate;
        }
    }

    /// @inheritdoc IInterestRateModel
    function utilizationRate(uint256 cash, uint256 borrows, uint256 reserves) public pure override returns (uint256) {
        if (borrows == 0) {
            return 0;
        }
        uint256 utilRate = borrows * 1e18 / (cash + borrows - reserves);
        // cap utilization rate to 100%
        if (utilRate > 1e18) return 1e18;
        return utilRate;
    }

    // ----------- PRIVATE ------------
    /// @notice Internal function to update jump rate model parameters without computation
    /// @param basePerBlock_ The base rate per block
    /// @param multiplierPerBlock_ The multiplier per block
    /// @param jumpMultiplierPerBlock_ The jump multiplier per block
    /// @param kink_ The kink utilization point
    function _updateJumpRateModelWithoutComputation(
        uint256 basePerBlock_,
        uint256 multiplierPerBlock_,
        uint256 jumpMultiplierPerBlock_,
        uint256 kink_
    ) private {
        baseRatePerBlock = basePerBlock_;
        multiplierPerBlock = multiplierPerBlock_;
        jumpMultiplierPerBlock = jumpMultiplierPerBlock_;
        kink = kink_;

        emit NewInterestParams(baseRatePerBlock, multiplierPerBlock, jumpMultiplierPerBlock, kink);
    }

    /**
     * @notice Internal function to update the parameters of the interest rate model
     * @param baseRatePerYear The base APR, scaled by 1e18
     * @param multiplierPerYear The rate increase wrt utilization, scaled by 1e18
     * @param jumpMultiplierPerYear The multiplier per block after utilization point
     * @param kink_ The utilization point where the jump multiplier applies
     */
    function _updateJumpRateModel(
        uint256 baseRatePerYear,
        uint256 multiplierPerYear,
        uint256 jumpMultiplierPerYear,
        uint256 kink_
    ) private {
        baseRatePerBlock = baseRatePerYear / blocksPerYear;
        multiplierPerBlock = multiplierPerYear * 1e18 / (blocksPerYear * kink_);
        jumpMultiplierPerBlock = jumpMultiplierPerYear / blocksPerYear;
        kink = kink_;

        emit NewInterestParams(baseRatePerBlock, multiplierPerBlock, jumpMultiplierPerBlock, kink);
    }
}
