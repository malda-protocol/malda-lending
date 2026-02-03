// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IPauser} from "src/interfaces/IPauser.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";
import {Pauser} from "src/pauser/Pauser.sol";
import {Roles} from "src/Roles.sol";

import {BasePauserTest} from "test/v2/utils/BasePauserTest.t.sol";

contract PauserTest is BasePauserTest {
    ////////////////////////////////////////////////////////////
    //                      constructor                       //
    ////////////////////////////////////////////////////////////

    function test_fuzz_constructor_revertsWith_Pauser_AddressNotValid(bool zeroRoles, bool zeroOperator) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        if (!zeroRoles && !zeroOperator) {
            zeroRoles = true;
        }
        address rolesAddress = zeroRoles ? address(0) : address(roles);
        address operatorAddress = zeroOperator ? address(0) : address(operator);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IPauser.Pauser_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new Pauser(rolesAddress, operatorAddress, address(this));
    }

    ////////////////////////////////////////////////////////////
    //                   addPausableMarket                    //
    ////////////////////////////////////////////////////////////

    function test_fuzz_addPausableMarket_revertsWith_Pauser_AddressNotValid(bool isHost) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IPauser.PausableType pausableType = isHost ? IPauser.PausableType.Host : IPauser.PausableType.Extension;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IPauser.Pauser_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        pauser.addPausableMarket(address(0), pausableType);
    }

    function test_fuzz_addPausableMarket_success(bool isHost) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address market = isHost ? address(mWethHost) : address(mWethExtension);
        IPauser.PausableType pausableType = isHost ? IPauser.PausableType.Host : IPauser.PausableType.Extension;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(pauser));
        emit IPauser.MarketAdded(market, pausableType);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        pauser.addPausableMarket(market, pausableType);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(pauser.registeredContracts(market));
        assertEq(uint256(pauser.contractTypes(market)), uint256(pausableType), "assertEq failed: values do not match");
    }

    ////////////////////////////////////////////////////////////
    //                emergencyPauseMarketFor                 //
    ////////////////////////////////////////////////////////////

    function test_unit_emergencyPauseMarketFor_revertsWith_Pauser_NotAuthorized() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _addPausableMarket(address(mWethHost), IPauser.PausableType.Host);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IPauser.Pauser_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        pauser.emergencyPauseMarketFor(address(mWethHost), ImTokenOperationTypes.OperationType.Mint);
    }

    function test_fuzz_emergencyPauseMarketFor_success(bool isHost, uint8 opIndex) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _grantPauseManager(address(this));
        opIndex = uint8(bound(opIndex, 0, 11));
        ImTokenOperationTypes.OperationType opType = ImTokenOperationTypes.OperationType(opIndex);

        address market = isHost ? address(mWethHost) : address(mWethExtension);
        IPauser.PausableType pausableType = isHost ? IPauser.PausableType.Host : IPauser.PausableType.Extension;
        _addPausableMarket(market, pausableType);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(pauser));
        emit IPauser.MarketPausedFor(market, opType);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        pauser.emergencyPauseMarketFor(market, opType);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        if (isHost) {
            assertTrue(operator.isPaused(market, opType));
        } else {
            assertTrue(mWethExtension.isPaused(opType));
        }
    }

    ////////////////////////////////////////////////////////////
    //                  emergencyPauseMarket                  //
    ////////////////////////////////////////////////////////////

    function test_unit_emergencyPauseMarket_revertsWith_Pauser_ContractNotEnabled() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _grantPauseManager(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IPauser.Pauser_ContractNotEnabled.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        pauser.emergencyPauseMarket(users.bob);
    }

    function test_fuzz_emergencyPauseMarket_success(bool isHost) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _grantPauseManager(address(this));
        address market = isHost ? address(mWethHost) : address(mWethExtension);
        IPauser.PausableType pausableType = isHost ? IPauser.PausableType.Host : IPauser.PausableType.Extension;
        _addPausableMarket(market, pausableType);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        _expectMarketPausedForAllOperations(market);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        pauser.emergencyPauseMarket(market);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        _assertMarketPausedForAllOperations(market, isHost);
    }

    ////////////////////////////////////////////////////////////
    //                   emergencyPauseAll                    //
    ////////////////////////////////////////////////////////////

    function test_unit_emergencyPauseAll_revertsWith_Pauser_NotAuthorized() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _addPausableMarket(address(mWethHost), IPauser.PausableType.Host);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IPauser.Pauser_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        pauser.emergencyPauseAll();
    }

    function test_unit_emergencyPauseAll_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _grantPauseManager(address(this));
        _addPausableMarket(address(mWethHost), IPauser.PausableType.Host);
        _addPausableMarket(address(mWethExtension), IPauser.PausableType.Extension);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        _expectMarketPausedForAllOperations(address(mWethHost));
        _expectMarketPausedForAllOperations(address(mWethExtension));
        vm.expectEmit(false, false, false, true, address(pauser));
        emit IPauser.PauseAll();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        pauser.emergencyPauseAll();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        _assertMarketPausedForAllOperations(address(mWethHost), true);
        _assertMarketPausedForAllOperations(address(mWethExtension), false);
    }

    ////////////////////////////////////////////////////////////
    //                  removePausableMarket                  //
    ////////////////////////////////////////////////////////////

    function test_unit_removePausableMarket_revertsWith_Pauser_EntryNotFound() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IPauser.Pauser_EntryNotFound.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        pauser.removePausableMarket(address(mWethHost));
    }

    function test_unit_removePausableMarket_revertsWith_Pauser_EntryNotFound_whenSlotRegistered() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _addPausableMarket(address(mWethHost), IPauser.PausableType.Host);

        address phantom = users.bob;
        _setRegistered(phantom, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IPauser.Pauser_EntryNotFound.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        pauser.removePausableMarket(phantom);
    }

    function test_unit_removePausableMarket_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _addPausableMarket(address(mWethHost), IPauser.PausableType.Host);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true, address(pauser));
        emit IPauser.MarketRemoved(address(mWethHost));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        pauser.removePausableMarket(address(mWethHost));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(pauser.registeredContracts(address(mWethHost)));
        assertEq(
            uint256(pauser.contractTypes(address(mWethHost))),
            uint256(IPauser.PausableType.NonPausable),
            "assertEq failed: values do not match"
        );
    }

    ////////////////////////////////////////////////////////////
    //                   pausableContracts                    //
    ////////////////////////////////////////////////////////////

    function test_unit_pausableContracts_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _addPausableMarket(address(mWethHost), IPauser.PausableType.Host);
        _addPausableMarket(address(mWethExtension), IPauser.PausableType.Extension);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true, address(pauser));
        emit IPauser.MarketRemoved(address(mWethHost));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        pauser.removePausableMarket(address(mWethHost));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(pauser.registeredContracts(address(mWethHost)));
        assertEq(
            uint256(pauser.contractTypes(address(mWethHost))),
            uint256(IPauser.PausableType.NonPausable),
            "assertEq failed: values do not match"
        );

        (address market, IPauser.PausableType marketType) = pauser.pausableContracts(0);
        assertEq(market, address(mWethExtension), "assertEq failed: values do not match");
        assertEq(uint256(marketType), uint256(IPauser.PausableType.Extension), "assertEq failed: values do not match");

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        pauser.pausableContracts(1);
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _allowRole(address target, bytes32 role, bool allowed) internal {
        vm.expectEmit(true, true, false, true, address(roles));
        emit Roles.Allowed(target, role, allowed);

        roles.allowFor(target, role, allowed);
    }

    function _addPausableMarket(address market, IPauser.PausableType pausableType) internal {
        vm.expectEmit(true, true, false, true, address(pauser));
        emit IPauser.MarketAdded(market, pausableType);

        pauser.addPausableMarket(market, pausableType);
    }

    function _grantPauseManager(address caller) internal {
        _allowRole(caller, roles.PAUSE_MANAGER(), true);
        _allowRole(address(pauser), roles.GUARDIAN_PAUSE(), true);
    }

    function _setRegistered(address market, bool value) internal {
        bytes32 slot = keccak256(abi.encode(market, uint256(2)));
        vm.store(address(pauser), slot, bytes32(uint256(value ? 1 : 0)));
    }

    function _expectMarketPausedForAllOperations(address market) internal {
        ImTokenOperationTypes.OperationType[12] memory ops = [
            ImTokenOperationTypes.OperationType.AmountIn,
            ImTokenOperationTypes.OperationType.AmountOut,
            ImTokenOperationTypes.OperationType.AmountInHere,
            ImTokenOperationTypes.OperationType.AmountOutHere,
            ImTokenOperationTypes.OperationType.Mint,
            ImTokenOperationTypes.OperationType.Borrow,
            ImTokenOperationTypes.OperationType.Transfer,
            ImTokenOperationTypes.OperationType.Seize,
            ImTokenOperationTypes.OperationType.Repay,
            ImTokenOperationTypes.OperationType.Redeem,
            ImTokenOperationTypes.OperationType.Liquidate,
            ImTokenOperationTypes.OperationType.Rebalancing
        ];

        for (uint256 i; i < ops.length; ++i) {
            vm.expectEmit(true, true, false, true, address(pauser));
            emit IPauser.MarketPausedFor(market, ops[i]);
        }

        vm.expectEmit(true, false, false, true, address(pauser));
        emit IPauser.MarketPaused(market);
    }

    function _assertMarketPausedForAllOperations(address market, bool isHost) internal {
        ImTokenOperationTypes.OperationType[12] memory ops = [
            ImTokenOperationTypes.OperationType.AmountIn,
            ImTokenOperationTypes.OperationType.AmountOut,
            ImTokenOperationTypes.OperationType.AmountInHere,
            ImTokenOperationTypes.OperationType.AmountOutHere,
            ImTokenOperationTypes.OperationType.Mint,
            ImTokenOperationTypes.OperationType.Borrow,
            ImTokenOperationTypes.OperationType.Transfer,
            ImTokenOperationTypes.OperationType.Seize,
            ImTokenOperationTypes.OperationType.Repay,
            ImTokenOperationTypes.OperationType.Redeem,
            ImTokenOperationTypes.OperationType.Liquidate,
            ImTokenOperationTypes.OperationType.Rebalancing
        ];

        for (uint256 i; i < ops.length; ++i) {
            if (isHost) {
                assertTrue(operator.isPaused(market, ops[i]));
            } else {
                assertTrue(mWethExtension.isPaused(ops[i]));
            }
        }
    }
}
