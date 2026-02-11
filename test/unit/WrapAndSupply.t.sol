// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {WrapAndSupply} from "src/utils/WrapAndSupply.sol";

import {MockGateway, MockHostMarket, MockWrappedNative} from "test/mocks/WrapAndSupplyMocks.t.sol";
import {BaseTest} from "test/utils/BaseTest.t.sol";

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

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true, address(helper));
        emit WrapAndSupply.WrappedAndSupplied(address(this), address(this), address(market), 2 ether);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        helper.wrapAndSupplyOnHostMarket{value: 2 ether}(address(market), address(this), 123);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(market.lastMintAmount(), 2 ether, "expected market.lastMintAmount() to equal 2 ether");
        assertEq(market.lastReceiver(), address(this), "expected market.lastReceiver() to equal address(this)");
        assertEq(market.lastMinAmount(), 123, "expected market.lastMinAmount() to equal 123");
        assertEq(
            wrapped.balanceOf(address(helper)), 2 ether, "expected wrapped.balanceOf(address(helper)) to equal 2 ether"
        );
        assertEq(
            wrapped.allowance(address(helper), address(market)),
            2 ether,
            "expected wrapped.allowance(address(helper), address(market)) to equal 2 ether"
        );
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

    function test_unit_wrapAndSupplyOnExtensionMarket_revertsWith_PanicArithmetic_whenGasFeeExceedsMsgValue() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        WrapAndSupply helper = new WrapAndSupply(address(wrapped));
        MockGateway gateway = new MockGateway(address(wrapped), 1 ether + 1);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        helper.wrapAndSupplyOnExtensionMarket{value: 1 ether}(address(gateway), address(this), bytes4(0));
    }

    function test_unit_wrapAndSupplyOnExtensionMarket_success_whenGasFeeZero() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        WrapAndSupply helper = new WrapAndSupply(address(wrapped));
        MockGateway gateway = new MockGateway(address(wrapped), 0);
        bytes4 selector = bytes4(keccak256("mintExternal(bytes,bytes,uint256[],uint256[],address)"));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true, address(helper));
        emit WrapAndSupply.WrappedAndSupplied(address(this), address(this), address(gateway), 1 ether);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        helper.wrapAndSupplyOnExtensionMarket{value: 1 ether}(address(gateway), address(this), selector);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(gateway.lastAmount(), 1 ether, "expected gateway.lastAmount() to equal 1 ether");
        assertEq(gateway.lastValue(), 0, "expected gateway.lastValue() to equal 0");
        assertEq(gateway.lastSelector(), selector, "expected gateway.lastSelector() to equal selector");
    }

    ////////////////////////////////////////////////////////////
    //                         Supply                         //
    ////////////////////////////////////////////////////////////

    // NOTE (as of 2026-02-11): unreachable invariant.
    // `_wrap` receives an amount derived from `msg.value` (`msg.value` or `msg.value - gasFee` after checked arithmetic),
    // so `amountToWrap > msg.value` cannot be reached through public entry points.
    function test_unit_unreachableInvariant_wrapAmountNeverExceedsMsgValue() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 sentValue = 1 ether;
        uint256 gasFee = 0.25 ether;
        WrapAndSupply helper = new WrapAndSupply(address(wrapped));
        MockGateway gateway = new MockGateway(address(wrapped), gasFee);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        helper.wrapAndSupplyOnExtensionMarket{value: sentValue}(address(gateway), address(this), bytes4(0));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertLe(gateway.lastAmount(), sentValue, "expected gateway.lastAmount() to be <= sentValue");
        assertEq(gateway.lastAmount(), sentValue - gasFee, "expected gateway.lastAmount() to equal sentValue - gasFee");
    }

    function test_fuzz_wrapAndSupplyOnExtensionMarket_success(
        uint256 amount,
        uint256 gasFee,
        address receiver,
        bytes4 selector
    ) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(receiver != address(0));
        amount = bound(amount, 1, 10 ether);
        gasFee = bound(gasFee, 0, amount - 1);

        WrapAndSupply helper = new WrapAndSupply(address(wrapped));
        MockGateway gateway = new MockGateway(address(wrapped), gasFee);
        uint256 expectedAmount = amount - gasFee;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true, address(helper));
        emit WrapAndSupply.WrappedAndSupplied(address(this), receiver, address(gateway), expectedAmount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        helper.wrapAndSupplyOnExtensionMarket{value: amount}(address(gateway), receiver, selector);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(gateway.lastAmount(), expectedAmount, "expected gateway.lastAmount() to equal expectedAmount");
        assertEq(gateway.lastReceiver(), receiver, "expected gateway.lastReceiver() to equal receiver");
        assertEq(gateway.lastSelector(), selector, "expected gateway.lastSelector() to equal selector");
        assertEq(gateway.lastValue(), gasFee, "expected gateway.lastValue() to equal gasFee");
        assertEq(
            wrapped.balanceOf(address(helper)),
            expectedAmount,
            "expected wrapped.balanceOf(address(helper)) to equal expectedAmount"
        );
        assertEq(
            wrapped.allowance(address(helper), address(gateway)),
            expectedAmount,
            "expected wrapped.allowance(address(helper), address(gateway)) to equal expectedAmount"
        );
    }
}
