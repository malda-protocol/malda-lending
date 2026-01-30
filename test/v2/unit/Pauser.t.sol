// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {Pauser} from "src/pauser/Pauser.sol";
import {IPauser} from "src/interfaces/IPauser.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

import {BasePauserTest} from "test/v2/utils/BasePauserTest.t.sol";

contract PauserTest is BasePauserTest {
    ////////////////////////////////////////////////////////////
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_Pauser_AddressNotValid_variant2() external {
        vm.expectRevert(IPauser.Pauser_AddressNotValid.selector);
        new Pauser(address(0), address(1), address(this));
    }

    function test_unit_constructor_revertsWith_Pauser_AddressNotValid() external {
        vm.expectRevert(IPauser.Pauser_AddressNotValid.selector);
        new Pauser(address(1), address(0), address(this));
    }

    ////////////////////////////////////////////////////////////
    //                   AddPausableMarket                    //
    ////////////////////////////////////////////////////////////

    function test_unit_addPausableMarket_revertsWith_Pauser_AddressNotValid() external {
        vm.expectRevert(IPauser.Pauser_AddressNotValid.selector);
        pauser.addPausableMarket(address(0), IPauser.PausableType.Host);

        vm.expectRevert(IPauser.Pauser_AddressNotValid.selector);
        pauser.addPausableMarket(address(0), IPauser.PausableType.Extension);
    }

    function test_unit_addPausableMarket_success() external {
        pauser.addPausableMarket(address(mWethHost), IPauser.PausableType.Host);
        assertTrue(pauser.registeredContracts(address(mWethHost)));
        assertEq(uint256(pauser.contractTypes(address(mWethHost))), uint256(IPauser.PausableType.Host));
    }

    ////////////////////////////////////////////////////////////
    //                EmergencyPauseMarketFor                 //
    ////////////////////////////////////////////////////////////

    function test_unit_emergencyPauseMarketFor_revertsWith_Pauser_NotAuthorized_whenContractDoesNotHaveThePAUSE()
        external
    {
        pauser.addPausableMarket(address(mWethHost), IPauser.PausableType.Host);
        pauser.addPausableMarket(address(mWethExtension), IPauser.PausableType.Extension);

        vm.expectRevert(IPauser.Pauser_NotAuthorized.selector);
        pauser.emergencyPauseAll();

        vm.expectRevert(IPauser.Pauser_NotAuthorized.selector);
        pauser.emergencyPauseMarket(address(mWethHost));

        vm.expectRevert(IPauser.Pauser_NotAuthorized.selector);
        pauser.emergencyPauseMarketFor(address(mWethHost), ImTokenOperationTypes.OperationType.AmountIn);
    }

    modifier whenContractHasThePAUSE_MANAGERRole() {
        roles.allowFor(address(this), roles.PAUSE_MANAGER(), true);
        roles.allowFor(address(pauser), roles.GUARDIAN_PAUSE(), true);
        _;
    }

    ////////////////////////////////////////////////////////////
    //                   AddPausableMarket                    //
    ////////////////////////////////////////////////////////////

    function test_unit_addPausableMarket_success_variant3() external whenContractHasThePAUSE_MANAGERRole {
        pauser.addPausableMarket(address(mWethHost), IPauser.PausableType.Host);

        assertFalse(operator.isPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Mint));
        pauser.emergencyPauseMarket(address(mWethHost));
        assertTrue(operator.isPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Mint));
        assertTrue(operator.isPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Seize));
        assertTrue(operator.isPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Transfer));
        assertTrue(operator.isPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Borrow));
        assertTrue(operator.isPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Repay));
        assertTrue(operator.isPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Redeem));

        pauser.addPausableMarket(address(mWethExtension), IPauser.PausableType.Extension);
        assertFalse(mWethExtension.isPaused(ImTokenOperationTypes.OperationType.Mint));
        pauser.emergencyPauseMarket(address(mWethExtension));
        assertTrue(mWethExtension.isPaused(ImTokenOperationTypes.OperationType.AmountIn));
        assertTrue(mWethExtension.isPaused(ImTokenOperationTypes.OperationType.AmountInHere));
        assertTrue(mWethExtension.isPaused(ImTokenOperationTypes.OperationType.AmountOut));
        assertTrue(mWethExtension.isPaused(ImTokenOperationTypes.OperationType.AmountOutHere));
        assertTrue(mWethExtension.isPaused(ImTokenOperationTypes.OperationType.Mint));
        assertTrue(mWethExtension.isPaused(ImTokenOperationTypes.OperationType.Seize));
        assertTrue(mWethExtension.isPaused(ImTokenOperationTypes.OperationType.Transfer));
        assertTrue(mWethExtension.isPaused(ImTokenOperationTypes.OperationType.Borrow));
        assertTrue(mWethExtension.isPaused(ImTokenOperationTypes.OperationType.Repay));
        assertTrue(mWethExtension.isPaused(ImTokenOperationTypes.OperationType.Redeem));
    }

    function test_unit_addPausableMarket_success_variant2() external whenContractHasThePAUSE_MANAGERRole {
        pauser.addPausableMarket(address(mWethHost), IPauser.PausableType.Host);
        assertFalse(operator.isPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Mint));
        pauser.emergencyPauseMarketFor(address(mWethHost), ImTokenOperationTypes.OperationType.Mint);
        assertTrue(operator.isPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Mint));
        assertFalse(operator.isPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Redeem));

        pauser.addPausableMarket(address(mWethExtension), IPauser.PausableType.Extension);
        assertFalse(mWethExtension.isPaused(ImTokenOperationTypes.OperationType.Mint));
        pauser.emergencyPauseMarketFor(address(mWethExtension), ImTokenOperationTypes.OperationType.Mint);
        assertTrue(mWethExtension.isPaused(ImTokenOperationTypes.OperationType.Mint));
    }

    ////////////////////////////////////////////////////////////
    //                   EmergencyPauseAll                    //
    ////////////////////////////////////////////////////////////

    function test_unit_emergencyPauseAll_success() external whenContractHasThePAUSE_MANAGERRole {
        pauser.addPausableMarket(address(mWethHost), IPauser.PausableType.Host);
        pauser.addPausableMarket(address(mWethExtension), IPauser.PausableType.Extension);
        pauser.emergencyPauseAll();

        assertTrue(operator.isPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Mint));
        assertTrue(operator.isPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Seize));
        assertTrue(operator.isPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Transfer));
        assertTrue(operator.isPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Borrow));
        assertTrue(operator.isPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Repay));
        assertTrue(operator.isPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Redeem));

        assertTrue(mWethExtension.isPaused(ImTokenOperationTypes.OperationType.AmountIn));
        assertTrue(mWethExtension.isPaused(ImTokenOperationTypes.OperationType.AmountInHere));
        assertTrue(mWethExtension.isPaused(ImTokenOperationTypes.OperationType.AmountOut));
        assertTrue(mWethExtension.isPaused(ImTokenOperationTypes.OperationType.AmountOutHere));
        assertTrue(mWethExtension.isPaused(ImTokenOperationTypes.OperationType.Seize));
        assertTrue(mWethExtension.isPaused(ImTokenOperationTypes.OperationType.Transfer));
        assertTrue(mWethExtension.isPaused(ImTokenOperationTypes.OperationType.Borrow));
        assertTrue(mWethExtension.isPaused(ImTokenOperationTypes.OperationType.Repay));
        assertTrue(mWethExtension.isPaused(ImTokenOperationTypes.OperationType.Redeem));
    }

    ////////////////////////////////////////////////////////////
    //                  EmergencyPauseMarket                  //
    ////////////////////////////////////////////////////////////

    function test_unit_emergencyPauseMarket_revertsWith_Pauser_ContractNotEnabled()
        external
        whenContractHasThePAUSE_MANAGERRole
    {
        vm.expectRevert(IPauser.Pauser_ContractNotEnabled.selector);
        pauser.emergencyPauseMarket(users.bob);
    }

    ////////////////////////////////////////////////////////////
    //                   AddPausableMarket                    //
    ////////////////////////////////////////////////////////////

    function test_fuzz_addPausableMarket_success(uint8 opIndex) external whenContractHasThePAUSE_MANAGERRole {
        opIndex = uint8(bound(opIndex, 0, 11));
        ImTokenOperationTypes.OperationType opType = ImTokenOperationTypes.OperationType(opIndex);

        pauser.addPausableMarket(address(mWethHost), IPauser.PausableType.Host);
        assertFalse(operator.isPaused(address(mWethHost), opType));

        pauser.emergencyPauseMarketFor(address(mWethHost), opType);
        assertTrue(operator.isPaused(address(mWethHost), opType));
    }

    function test_fuzz_addPausableMarket_success_variant2(uint8 opIndex) external whenContractHasThePAUSE_MANAGERRole {
        opIndex = uint8(bound(opIndex, 0, 11));
        ImTokenOperationTypes.OperationType opType = ImTokenOperationTypes.OperationType(opIndex);

        pauser.addPausableMarket(address(mWethExtension), IPauser.PausableType.Extension);
        assertFalse(mWethExtension.isPaused(opType));

        pauser.emergencyPauseMarketFor(address(mWethExtension), opType);
        assertTrue(mWethExtension.isPaused(opType));
    }

    function _setRegistered(address market, bool value) internal {
        bytes32 slot = keccak256(abi.encode(market, uint256(2)));
        vm.store(address(pauser), slot, bytes32(uint256(value ? 1 : 0)));
    }

    ////////////////////////////////////////////////////////////
    //                  RemovePausableMarket                  //
    ////////////////////////////////////////////////////////////

    function test_unit_removePausableMarket_revertsWith_Pauser_EntryNotFound_variant2() external {
        vm.expectRevert(IPauser.Pauser_EntryNotFound.selector);
        pauser.removePausableMarket(address(mWethHost));
    }

    ////////////////////////////////////////////////////////////
    //                   PausableContracts                    //
    ////////////////////////////////////////////////////////////

    function test_unit_pausableContracts_revertsWith() external {
        pauser.addPausableMarket(address(mWethHost), IPauser.PausableType.Host);
        pauser.addPausableMarket(address(mWethExtension), IPauser.PausableType.Extension);

        pauser.removePausableMarket(address(mWethHost));

        assertFalse(pauser.registeredContracts(address(mWethHost)));
        assertEq(uint256(pauser.contractTypes(address(mWethHost))), uint256(IPauser.PausableType.NonPausable));

        (address market, IPauser.PausableType marketType) = pauser.pausableContracts(0);
        assertEq(market, address(mWethExtension));
        assertEq(uint256(marketType), uint256(IPauser.PausableType.Extension));

        vm.expectRevert();
        pauser.pausableContracts(1);
    }

    ////////////////////////////////////////////////////////////
    //                  RemovePausableMarket                  //
    ////////////////////////////////////////////////////////////

    function test_unit_removePausableMarket_revertsWith_Pauser_EntryNotFound() external {
        pauser.addPausableMarket(address(mWethHost), IPauser.PausableType.Host);

        address phantom = users.bob;
        _setRegistered(phantom, true);

        vm.expectRevert(IPauser.Pauser_EntryNotFound.selector);
        pauser.removePausableMarket(phantom);
    }
}
