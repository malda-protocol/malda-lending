// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {IPauser} from "src/interfaces/IPauser.sol";
import {Pauser_Unit_Shared} from "../shared/Pauser_Unit_Shared.t.sol";

contract Pauser_removePausableMarket is Pauser_Unit_Shared {
    function _setRegistered(address market, bool value) internal {
        bytes32 slot = keccak256(abi.encode(market, uint256(1)));
        vm.store(address(pauser), slot, bytes32(uint256(value ? 1 : 0)));
    }

    function test_RevertWhen_ContractIsNotRegistered() external {
        vm.expectRevert(IPauser.Pauser_EntryNotFound.selector);
        pauser.removePausableMarket(address(mWethHost));
    }

    function test_WhenContractIsRegistered() external {
        pauser.addPausableMarket(address(mWethHost), IPauser.PausableType.Host);
        pauser.addPausableMarket(address(mWethExtension), IPauser.PausableType.Extension);

        // it should remove it from the pausable contracts array
        // it should remove the registered entry
        pauser.removePausableMarket(address(mWethHost));

        assertFalse(pauser.registeredContracts(address(mWethHost)));
        assertEq(uint256(pauser.contractTypes(address(mWethHost))), uint256(IPauser.PausableType.NonPausable));

        (address market, IPauser.PausableType marketType) = pauser.pausableContracts(0);
        assertEq(market, address(mWethExtension));
        assertEq(uint256(marketType), uint256(IPauser.PausableType.Extension));

        vm.expectRevert();
        pauser.pausableContracts(1);
    }

    function test_RevertWhen_RegisteredButNotInArray() external {
        pauser.addPausableMarket(address(mWethHost), IPauser.PausableType.Host);

        address phantom = address(0xBEEF);
        _setRegistered(phantom, true);

        vm.expectRevert(IPauser.Pauser_EntryNotFound.selector);
        pauser.removePausableMarket(phantom);
    }
}
