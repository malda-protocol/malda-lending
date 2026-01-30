// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";
import {ExponentialNoError} from "src/utils/ExponentialNoError.sol";

contract ExponentialNoErrorHarness is ExponentialNoError {
    function callLessThanOrEqualExp(uint256 left, uint256 right) external pure returns (bool) {
        return lessThanOrEqualExp(Exp({mantissa: left}), Exp({mantissa: right}));
    }

    function callGreaterThanExp(uint256 left, uint256 right) external pure returns (bool) {
        return greaterThanExp(Exp({mantissa: left}), Exp({mantissa: right}));
    }

    function callIsZeroExp(uint256 value) external pure returns (bool) {
        return isZeroExp(Exp({mantissa: value}));
    }

    function callSafe224(uint256 n, string calldata errorMessage) external pure returns (uint224) {
        return safe224(n, errorMessage);
    }

    function callSafe32(uint256 n, string calldata errorMessage) external pure returns (uint32) {
        return safe32(n, errorMessage);
    }

    function callAddExp(uint256 a, uint256 b) external pure returns (uint256) {
        return add_(Exp({mantissa: a}), Exp({mantissa: b})).mantissa;
    }

    function callAddDouble(uint256 a, uint256 b) external pure returns (uint256) {
        return add_(Double({mantissa: a}), Double({mantissa: b})).mantissa;
    }

    function callSubExp(uint256 a, uint256 b) external pure returns (uint256) {
        return sub_(Exp({mantissa: a}), Exp({mantissa: b})).mantissa;
    }

    function callSubDouble(uint256 a, uint256 b) external pure returns (uint256) {
        return sub_(Double({mantissa: a}), Double({mantissa: b})).mantissa;
    }

    function callSubUint(uint256 a, uint256 b) external pure returns (uint256) {
        return sub_(a, b);
    }

    function callMulDoubleDouble(uint256 a, uint256 b) external pure returns (uint256) {
        return mul_(Double({mantissa: a}), Double({mantissa: b})).mantissa;
    }

    function callMulDoubleScalar(uint256 a, uint256 b) external pure returns (uint256) {
        return mul_(Double({mantissa: a}), b).mantissa;
    }

    function callMulUintDouble(uint256 a, uint256 b) external pure returns (uint256) {
        return mul_(a, Double({mantissa: b}));
    }

    function callDivExpScalar(uint256 a, uint256 b) external pure returns (uint256) {
        return div_(Exp({mantissa: a}), b).mantissa;
    }

    function callDivDoubleDouble(uint256 a, uint256 b) external pure returns (uint256) {
        return div_(Double({mantissa: a}), Double({mantissa: b})).mantissa;
    }

    function callDivDoubleScalar(uint256 a, uint256 b) external pure returns (uint256) {
        return div_(Double({mantissa: a}), b).mantissa;
    }

    function callDivUintDouble(uint256 a, uint256 b) external pure returns (uint256) {
        return div_(a, Double({mantissa: b}));
    }

    function callDivUpUint(uint256 a, uint256 b) external pure returns (uint256) {
        return divUp_(a, b);
    }

    function callDivUpExp(uint256 a, uint256 b) external pure returns (uint256) {
        return divUp_(a, Exp({mantissa: b}));
    }

    function callFraction(uint256 a, uint256 b) external pure returns (uint256) {
        return fraction(a, b).mantissa;
    }
}

contract ExponentialNoErrorTest is BaseTest {
    ExponentialNoErrorHarness internal harness;

    uint256 internal constant EXP_SCALE = 1e18;
    uint256 internal constant DOUBLE_SCALE = 1e36;
    uint256 internal constant MAX_DOUBLE_NUMERATOR = type(uint256).max / DOUBLE_SCALE;

    function setUp() public override {
        super.setUp();
        harness = new ExponentialNoErrorHarness();
    }

    ////////////////////////////////////////////////////////////
    //                 CallLessThanOrEqualExp                 //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callLessThanOrEqualExp_success(uint256 left, uint256 right) external view {
        assertEq(harness.callLessThanOrEqualExp(left, right), left <= right);
    }

    ////////////////////////////////////////////////////////////
    //                   CallGreaterThanExp                   //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callGreaterThanExp_success(uint256 left, uint256 right) external view {
        assertEq(harness.callGreaterThanExp(left, right), left > right);
    }

    ////////////////////////////////////////////////////////////
    //                     CallIsZeroExp                      //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callIsZeroExp_success(uint256 value) external view {
        assertEq(harness.callIsZeroExp(value), value == 0);
    }

    ////////////////////////////////////////////////////////////
    //                      CallSafe224                       //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callSafe224_success(uint224 value) external view {
        assertEq(harness.callSafe224(uint256(value), "SAFE224"), value);
    }

    function test_fuzz_callSafe224_revertsWith_SAFE224_revertsWhenTooLarge(uint256 value) external {
        value = bound(value, uint256(type(uint224).max) + 1, type(uint256).max);
        vm.expectRevert("SAFE224");
        harness.callSafe224(value, "SAFE224");
    }

    ////////////////////////////////////////////////////////////
    //                       CallSafe32                       //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callSafe32_success(uint32 value) external view {
        assertEq(harness.callSafe32(uint256(value), "SAFE32"), value);
    }

    function test_fuzz_callSafe32_revertsWith_SAFE32_revertsWhenTooLarge(uint256 value) external {
        value = bound(value, uint256(type(uint32).max) + 1, type(uint256).max);
        vm.expectRevert("SAFE32");
        harness.callSafe32(value, "SAFE32");
    }

    ////////////////////////////////////////////////////////////
    //                       CallAddExp                       //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callAddExp_success(uint256 left, uint256 right) external view {
        left = bound(left, 0, DOUBLE_SCALE);
        right = bound(right, 0, DOUBLE_SCALE);
        assertEq(harness.callAddExp(left, right), left + right);
    }

    ////////////////////////////////////////////////////////////
    //                     CallAddDouble                      //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callAddDouble_success_variant2(uint256 left, uint256 right) external view {
        left = bound(left, 0, DOUBLE_SCALE);
        right = bound(right, 0, DOUBLE_SCALE);
        assertEq(harness.callAddDouble(left, right), left + right);
    }

    ////////////////////////////////////////////////////////////
    //                       CallSubExp                       //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callSubExp_success_variant3(uint256 left, uint256 right) external view {
        left = bound(left, 0, DOUBLE_SCALE);
        right = bound(right, 0, left);
        assertEq(harness.callSubExp(left, right), left - right);
    }

    ////////////////////////////////////////////////////////////
    //                     CallSubDouble                      //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callSubDouble_success_variant4(uint256 left, uint256 right) external view {
        left = bound(left, 0, DOUBLE_SCALE);
        right = bound(right, 0, left);
        assertEq(harness.callSubDouble(left, right), left - right);
    }

    ////////////////////////////////////////////////////////////
    //                      CallSubUint                       //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callSubUint_success_variant5(uint256 left, uint256 right) external view {
        left = bound(left, 0, DOUBLE_SCALE);
        right = bound(right, 0, left);
        assertEq(harness.callSubUint(left, right), left - right);
    }

    ////////////////////////////////////////////////////////////
    //                  CallMulDoubleDouble                   //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callMulDoubleDouble_success_variant6(uint256 left, uint256 right) external view {
        left = bound(left, 0, DOUBLE_SCALE);
        right = bound(right, 0, DOUBLE_SCALE);
        uint256 expected = (left * right) / DOUBLE_SCALE;
        assertEq(harness.callMulDoubleDouble(left, right), expected);
    }

    ////////////////////////////////////////////////////////////
    //                  CallMulDoubleScalar                   //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callMulDoubleScalar_success_variant7(uint256 mantissa, uint256 scalar) external view {
        mantissa = bound(mantissa, 0, DOUBLE_SCALE);
        scalar = bound(scalar, 0, EXP_SCALE);
        assertEq(harness.callMulDoubleScalar(mantissa, scalar), mantissa * scalar);
    }

    ////////////////////////////////////////////////////////////
    //                   CallMulUintDouble                    //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callMulUintDouble_success_variant8(uint256 value, uint256 mantissa) external view {
        value = bound(value, 0, DOUBLE_SCALE);
        mantissa = bound(mantissa, 0, DOUBLE_SCALE);
        uint256 expected = (value * mantissa) / DOUBLE_SCALE;
        assertEq(harness.callMulUintDouble(value, mantissa), expected);
    }

    ////////////////////////////////////////////////////////////
    //                    CallDivExpScalar                    //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callDivExpScalar_success_variant9(uint256 mantissa, uint256 divisor) external view {
        mantissa = bound(mantissa, 0, DOUBLE_SCALE);
        divisor = bound(divisor, 1, DOUBLE_SCALE);
        assertEq(harness.callDivExpScalar(mantissa, divisor), mantissa / divisor);
    }

    ////////////////////////////////////////////////////////////
    //                  CallDivDoubleDouble                   //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callDivDoubleDouble_success_variant10(uint256 left, uint256 right) external view {
        left = bound(left, 0, MAX_DOUBLE_NUMERATOR);
        right = bound(right, 1, DOUBLE_SCALE);
        uint256 expected = (left * DOUBLE_SCALE) / right;
        assertEq(harness.callDivDoubleDouble(left, right), expected);
    }

    ////////////////////////////////////////////////////////////
    //                  CallDivDoubleScalar                   //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callDivDoubleScalar_success_variant11(uint256 mantissa, uint256 divisor) external view {
        mantissa = bound(mantissa, 0, DOUBLE_SCALE);
        divisor = bound(divisor, 1, DOUBLE_SCALE);
        assertEq(harness.callDivDoubleScalar(mantissa, divisor), mantissa / divisor);
    }

    ////////////////////////////////////////////////////////////
    //                   CallDivUintDouble                    //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callDivUintDouble_success_variant12(uint256 value, uint256 mantissa) external view {
        value = bound(value, 0, MAX_DOUBLE_NUMERATOR);
        mantissa = bound(mantissa, 1, DOUBLE_SCALE);
        uint256 expected = (value * DOUBLE_SCALE) / mantissa;
        assertEq(harness.callDivUintDouble(value, mantissa), expected);
    }

    ////////////////////////////////////////////////////////////
    //                     CallDivUpUint                      //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callDivUpUint_revertsWith_DIV_BY_ZERO_DIV_revertsWhenDivisorZero(uint256 value) external {
        vm.expectRevert("DIV_BY_ZERO");
        harness.callDivUpUint(value, 0);
    }

    function test_fuzz_callDivUpUint_success_variant13(uint256 divisor) external view {
        divisor = bound(divisor, 1, DOUBLE_SCALE);
        assertEq(harness.callDivUpUint(0, divisor), 0);
    }

    function test_fuzz_callDivUpUint_success_variant2(uint256 value, uint256 divisor) external view {
        value = bound(value, 1, DOUBLE_SCALE);
        divisor = bound(divisor, 1, EXP_SCALE);
        uint256 expected = (value + divisor - 1) / divisor;
        assertEq(harness.callDivUpUint(value, divisor), expected);
    }

    ////////////////////////////////////////////////////////////
    //                      CallDivUpExp                      //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callDivUpExp_success_variant14(uint256 value, uint256 mantissa) external view {
        uint256 maxValue = type(uint256).max / EXP_SCALE;
        value = bound(value, 0, maxValue);
        mantissa = bound(mantissa, 1, DOUBLE_SCALE);
        uint256 scaled = value * EXP_SCALE;
        uint256 expected = scaled == 0 ? 0 : 1 + ((scaled - 1) / mantissa);
        assertEq(harness.callDivUpExp(value, mantissa), expected);
    }

    ////////////////////////////////////////////////////////////
    //                      CallFraction                      //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callFraction_success_variant15(uint256 value, uint256 divisor) external view {
        value = bound(value, 0, MAX_DOUBLE_NUMERATOR);
        divisor = bound(divisor, 1, DOUBLE_SCALE);
        uint256 expected = (value * DOUBLE_SCALE) / divisor;
        assertEq(harness.callFraction(value, divisor), expected);
    }
}
