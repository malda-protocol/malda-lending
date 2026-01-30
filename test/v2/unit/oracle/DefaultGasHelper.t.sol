// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

import {DefaultGasHelper} from "src/oracles/gas/DefaultGasHelper.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DefaultGasHelperTest is BaseTest {
    event GasFeeUpdated(uint32 indexed dstChainId, uint256 amount);

    DefaultGasHelper internal helper;
    address internal owner;
    address internal other;

    function setUp() public override {
        super.setUp();
        owner = users.admin;
        other = users.bob;
        helper = new DefaultGasHelper(owner);
    }

    ////////////////////////////////////////////////////////////
    //                         Owner                          //
    ////////////////////////////////////////////////////////////

    function test_unit_owner_success_setsOwner() public view {
        assertEq(helper.owner(), owner);
    }

    ////////////////////////////////////////////////////////////
    //                     GasFeeUpdated                      //
    ////////////////////////////////////////////////////////////

    function test_unit_gasFeeUpdated_success_updatesAndEmits(uint32 chainId, uint256 amount) public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit GasFeeUpdated(chainId, amount);
        helper.setGasFee(chainId, amount);

        assertEq(helper.gasFees(chainId), amount);
    }

    ////////////////////////////////////////////////////////////
    //                       SetGasFee                        //
    ////////////////////////////////////////////////////////////

    function test_unit_setGasFee_revertsWith_OwnableUnauthorizedAccount() public {
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, other));
        helper.setGasFee(1, 1);
    }
}
