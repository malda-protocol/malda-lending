// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {WrapAndSupply} from "src/utils/WrapAndSupply.sol";

import {MockGateway, MockHostMarket, MockWrappedNative} from "test/v2/mocks/WrapAndSupplyMocks.t.sol";
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract WrapAndSupplyTest is BaseTest {
    MockWrappedNative internal wrapped;

    function setUp() public override {
        super.setUp();
        wrapped = new MockWrappedNative();
    }

    ////////////////////////////////////////////////////////////
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_WrapAndSupply_AddressNotValid() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(WrapAndSupply.WrapAndSupply_AddressNotValid.selector);
        new WrapAndSupply(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                     MockHostMarket                     //
    ////////////////////////////////////////////////////////////

    function test_unit_mockHostMarket_revertsWith_WrapAndSupply_AddressNotValid_whenReceiverZero() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        WrapAndSupply helper = new WrapAndSupply(address(wrapped));
        MockHostMarket market = new MockHostMarket(address(wrapped));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(WrapAndSupply.WrapAndSupply_AddressNotValid.selector);
        helper.wrapAndSupplyOnHostMarket{value: 1 ether}(address(market), address(0), 1);
    }

    function test_unit_mockHostMarket_revertsWith_WrapAndSupply_AddressNotValid_whenWrappedMismatch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        WrapAndSupply helper = new WrapAndSupply(address(wrapped));
        MockHostMarket market = new MockHostMarket(users.alice);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(WrapAndSupply.WrapAndSupply_AddressNotValid.selector);
        helper.wrapAndSupplyOnHostMarket{value: 1 ether}(address(market), address(this), 1);
    }

    ////////////////////////////////////////////////////////////
    //               WrapAndSupplyOnHostMarket                //
    ////////////////////////////////////////////////////////////

    function test_unit_wrapAndSupplyOnHostMarket_revertsWith_WrapAndSupply_AmountNotValid() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        WrapAndSupply helper = new WrapAndSupply(address(wrapped));
        MockHostMarket market = new MockHostMarket(address(wrapped));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(WrapAndSupply.WrapAndSupply_AmountNotValid.selector);
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        helper.wrapAndSupplyOnHostMarket(address(market), address(this), 1);
    }

    ////////////////////////////////////////////////////////////
    //                     MockHostMarket                     //
    ////////////////////////////////////////////////////////////

    function test_unit_wrapAndSupplyOnHostMarket_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        WrapAndSupply helper = new WrapAndSupply(address(wrapped));
        MockHostMarket market = new MockHostMarket(address(wrapped));

        helper.wrapAndSupplyOnHostMarket{value: 2 ether}(address(market), address(this), 123);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(market.lastMintAmount(), 2 ether, "assertEq failed: values do not match");
        assertEq(market.lastReceiver(), address(this), "assertEq failed: values do not match");
        assertEq(market.lastMinAmount(), 123, "assertEq failed: values do not match");
        assertEq(wrapped.balanceOf(address(helper)), 2 ether, "assertEq failed: values do not match");
        assertEq(wrapped.allowance(address(helper), address(market)), 2 ether, "assertEq failed: values do not match");
    }

    ////////////////////////////////////////////////////////////
    //                         Bytes4                         //
    ////////////////////////////////////////////////////////////

    function test_unit_wrapAndSupplyOnExtensionMarket_revertsWith_WrapAndSupply_AddressNotValid_whenReceiverZero()
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        WrapAndSupply helper = new WrapAndSupply(address(wrapped));
        MockGateway gateway = new MockGateway(address(wrapped), 0.1 ether);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(WrapAndSupply.WrapAndSupply_AddressNotValid.selector);
        helper.wrapAndSupplyOnExtensionMarket{value: 1 ether}(address(gateway), address(0), bytes4(0));
    }

    function test_unit_wrapAndSupplyOnExtensionMarket_revertsWith_WrapAndSupply_AddressNotValid_whenWrappedMismatch()
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        WrapAndSupply helper = new WrapAndSupply(address(wrapped));
        MockGateway gateway = new MockGateway(users.alice, 0.1 ether);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(WrapAndSupply.WrapAndSupply_AddressNotValid.selector);
        helper.wrapAndSupplyOnExtensionMarket{value: 1 ether}(address(gateway), address(this), bytes4(0));
    }

    function test_unit_wrapAndSupplyOnExtensionMarket_revertsWith_WrapAndSupply_AmountNotValid() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        WrapAndSupply helper = new WrapAndSupply(address(wrapped));
        MockGateway gateway = new MockGateway(address(wrapped), 1 ether);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(WrapAndSupply.WrapAndSupply_AmountNotValid.selector);
        helper.wrapAndSupplyOnExtensionMarket{value: 1 ether}(address(gateway), address(this), bytes4(0));
    }

    ////////////////////////////////////////////////////////////
    //                         Supply                         //
    ////////////////////////////////////////////////////////////

    function test_fuzz_supply_success(uint256 amount, uint256 gasFee) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, 1, 10 ether);
        gasFee = bound(gasFee, 0, amount - 1);

        WrapAndSupply helper = new WrapAndSupply(address(wrapped));
        MockGateway gateway = new MockGateway(address(wrapped), gasFee);

        bytes4 selector = bytes4(keccak256("supply(uint256)"));
        helper.wrapAndSupplyOnExtensionMarket{value: amount}(address(gateway), address(this), selector);

        uint256 expectedAmount = amount - gasFee;

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(gateway.lastAmount(), expectedAmount, "assertEq failed: values do not match");
        assertEq(gateway.lastReceiver(), address(this), "assertEq failed: values do not match");
        assertEq(gateway.lastSelector(), selector, "assertEq failed: values do not match");
        assertEq(gateway.lastValue(), gasFee, "assertEq failed: values do not match");
        assertEq(wrapped.balanceOf(address(helper)), expectedAmount, "assertEq failed: values do not match");
        assertEq(
            wrapped.allowance(address(helper), address(gateway)), expectedAmount, "assertEq failed: values do not match"
        );
    }
}
