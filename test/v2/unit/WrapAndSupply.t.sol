// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

import {WrapAndSupply} from "src/utils/WrapAndSupply.sol";
import {MockGateway, MockHostMarket, MockWrappedNative} from "test/v2/mocks/WrapAndSupplyMocks.t.sol";

contract WrapAndSupplyTest is BaseTest {
    MockWrappedNative internal wrapped;

    function setUp() public override {
        super.setUp();
        wrapped = new MockWrappedNative();
    }

    ////////////////////////////////////////////////////////////
    //                       Constructor                        //
    ////////////////////////////////////////////////////////////

    function test_unitConstructor_revertsWith_revertWhenWrappedNativeZero() external {
        vm.expectRevert(WrapAndSupply.WrapAndSupply_AddressNotValid.selector);
        new WrapAndSupply(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                WrapAndSupplyOnHostMarket                 //
    ////////////////////////////////////////////////////////////

    function test_unitWrapAndSupplyOnHostMarket_revertsWith_revertWhenReceiverZero() external {
        WrapAndSupply helper = new WrapAndSupply(address(wrapped));
        MockHostMarket market = new MockHostMarket(address(wrapped));

        vm.expectRevert(WrapAndSupply.WrapAndSupply_AddressNotValid.selector);
        helper.wrapAndSupplyOnHostMarket{value: 1 ether}(address(market), address(0), 1);
    }

    function test_unitWrapAndSupplyOnHostMarket_revertsWith_revertWhenUnderlyingMismatch() external {
        WrapAndSupply helper = new WrapAndSupply(address(wrapped));
        MockHostMarket market = new MockHostMarket(users.alice);

        vm.expectRevert(WrapAndSupply.WrapAndSupply_AddressNotValid.selector);
        helper.wrapAndSupplyOnHostMarket{value: 1 ether}(address(market), address(this), 1);
    }

    function test_unitWrapAndSupplyOnHostMarket_revertsWith_revertWhenAmountZero() external {
        WrapAndSupply helper = new WrapAndSupply(address(wrapped));
        MockHostMarket market = new MockHostMarket(address(wrapped));

        vm.expectRevert(WrapAndSupply.WrapAndSupply_AmountNotValid.selector);
        helper.wrapAndSupplyOnHostMarket(address(market), address(this), 1);
    }

    function test_unitWrapAndSupplyOnHostMarket_success_success() external {
        WrapAndSupply helper = new WrapAndSupply(address(wrapped));
        MockHostMarket market = new MockHostMarket(address(wrapped));

        helper.wrapAndSupplyOnHostMarket{value: 2 ether}(address(market), address(this), 123);

        assertEq(market.lastMintAmount(), 2 ether);
        assertEq(market.lastReceiver(), address(this));
        assertEq(market.lastMinAmount(), 123);
        assertEq(wrapped.balanceOf(address(helper)), 2 ether);
        assertEq(wrapped.allowance(address(helper), address(market)), 2 ether);
    }

    ////////////////////////////////////////////////////////////
    //              WrapAndSupplyOnExtensionMarket              //
    ////////////////////////////////////////////////////////////

    function test_unitWrapAndSupplyOnExtensionMarket_revertsWith_revertWhenReceiverZero() external {
        WrapAndSupply helper = new WrapAndSupply(address(wrapped));
        MockGateway gateway = new MockGateway(address(wrapped), 0.1 ether);

        vm.expectRevert(WrapAndSupply.WrapAndSupply_AddressNotValid.selector);
        helper.wrapAndSupplyOnExtensionMarket{value: 1 ether}(address(gateway), address(0), bytes4(0));
    }

    function test_unitWrapAndSupplyOnExtensionMarket_revertsWith_revertWhenUnderlyingMismatch() external {
        WrapAndSupply helper = new WrapAndSupply(address(wrapped));
        MockGateway gateway = new MockGateway(users.alice, 0.1 ether);

        vm.expectRevert(WrapAndSupply.WrapAndSupply_AddressNotValid.selector);
        helper.wrapAndSupplyOnExtensionMarket{value: 1 ether}(address(gateway), address(this), bytes4(0));
    }

    function test_unitWrapAndSupplyOnExtensionMarket_revertsWith_revertWhenAmountZeroAfterFee() external {
        WrapAndSupply helper = new WrapAndSupply(address(wrapped));
        MockGateway gateway = new MockGateway(address(wrapped), 1 ether);

        vm.expectRevert(WrapAndSupply.WrapAndSupply_AmountNotValid.selector);
        helper.wrapAndSupplyOnExtensionMarket{value: 1 ether}(address(gateway), address(this), bytes4(0));
    }

    function test_unitWrapAndSupplyOnExtensionMarket_success_success() external {
        WrapAndSupply helper = new WrapAndSupply(address(wrapped));
        MockGateway gateway = new MockGateway(address(wrapped), 0.1 ether);

        bytes4 selector = bytes4(keccak256("supply(uint256)"));
        helper.wrapAndSupplyOnExtensionMarket{value: 1 ether}(address(gateway), address(this), selector);

        assertEq(gateway.lastAmount(), 0.9 ether);
        assertEq(gateway.lastReceiver(), address(this));
        assertEq(gateway.lastSelector(), selector);
        assertEq(gateway.lastValue(), 0.1 ether);
        assertEq(wrapped.balanceOf(address(helper)), 0.9 ether);
        assertEq(wrapped.allowance(address(helper), address(gateway)), 0.9 ether);
    }
}
