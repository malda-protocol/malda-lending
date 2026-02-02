// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {DefaultGasHelper} from "src/oracles/gas/DefaultGasHelper.sol";

import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

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

    function test_unit_constructor_success_setsOwner() external view {
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(helper.owner(), owner);
    }

    ////////////////////////////////////////////////////////////
    //                        setGasFee                       //
    ////////////////////////////////////////////////////////////

    function test_fuzz_setGasFee_success_updatesMappingAndEmits(uint32 chainId, uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(owner);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true);
        emit DefaultGasHelper.GasFeeUpdated(chainId, amount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        helper.setGasFee(chainId, amount);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(helper.gasFees(chainId), amount);
    }

    function test_unit_setGasFee_revertsWith_OwnableUnauthorizedAccount() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(nonOwner);
        helper.setGasFee(1, 1);
    }
}
