// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {DefaultGasHelper} from "src/oracles/gas/DefaultGasHelper.sol";

import {BaseTest} from "test/utils/BaseTest.t.sol";

contract DefaultGasHelperTest is BaseTest {
    DefaultGasHelper internal helper;
    address internal owner;
    address internal nonOwner;

    function setUp() public override {
        super.setUp();
        owner = users.admin;
        nonOwner = users.bob;
        helper = new DefaultGasHelper(owner);
    }

    ////////////////////////////////////////////////////////////
    //                        constructor                     //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_success() external view {
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(helper.owner(), owner, "expected helper.owner() to equal owner");
    }

    function test_unit_constructor_revertsWith_OwnableInvalidOwner() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new DefaultGasHelper(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                        setGasFee                       //
    ////////////////////////////////////////////////////////////
    function test_unit_setGasFee_revertsWith_OwnableUnauthorizedAccount() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(nonOwner);
        helper.setGasFee(1, 1);
    }

    function test_fuzz_setGasFee_success(uint32 chainId, uint256 firstAmount, uint256 secondAmount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(owner);
        helper.setGasFee(chainId, firstAmount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true);
        emit DefaultGasHelper.GasFeeUpdated(chainId, secondAmount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(owner);
        helper.setGasFee(chainId, secondAmount);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(helper.gasFees(chainId), secondAmount, "expected helper.gasFees(chainId) to equal secondAmount");
    }
}
