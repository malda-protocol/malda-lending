// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";

import {DefaultGasHelper} from "src/oracles/gas/DefaultGasHelper.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DefaultGasHelperTest is Test {
    event GasFeeUpdated(uint32 indexed dstChainId, uint256 amount);

    DefaultGasHelper internal helper;
    address internal owner;
    address internal other;

    function setUp() public {
        owner = address(this);
        other = vm.addr(55);
        helper = new DefaultGasHelper(owner);
    }

    function test_Constructor_SetsOwner() public view {
        assertEq(helper.owner(), owner);
    }

    function test_SetGasFee_UpdatesAndEmits(uint32 chainId, uint256 amount) public {
        vm.expectEmit(true, false, false, true);
        emit GasFeeUpdated(chainId, amount);
        helper.setGasFee(chainId, amount);

        assertEq(helper.gasFees(chainId), amount);
    }

    function test_SetGasFee_RevertWhenNotOwner() public {
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, other));
        helper.setGasFee(1, 1);
    }
}
