// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {stdError} from "forge-std/StdError.sol";

import {ExponentialNoErrorHarness} from "test/harness/ExponentialNoErrorHarness.sol";
import {BaseTest} from "test/utils/BaseTest.t.sol";

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
    //                     CallLessThanExp                    //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callLessThanExp_success(uint256 left, uint256 right) external view {
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callLessThanExp(left, right),
            left < right,
            "expected harness.callLessThanExp(left, right) to equal left < right"
        );
    }

    ////////////////////////////////////////////////////////////
    //                 CallLessThanOrEqualExp                 //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callLessThanOrEqualExp_success(uint256 left, uint256 right) external view {
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callLessThanOrEqualExp(left, right),
            left <= right,
            "expected harness.callLessThanOrEqualExp(left, right) to equal left <= right"
        );
    }

    ////////////////////////////////////////////////////////////
    //                   CallGreaterThanExp                   //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callGreaterThanExp_success(uint256 left, uint256 right) external view {
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callGreaterThanExp(left, right),
            left > right,
            "expected harness.callGreaterThanExp(left, right) to equal left > right"
        );
    }

    ////////////////////////////////////////////////////////////
    //                     CallIsZeroExp                      //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callIsZeroExp_success(uint256 value) external view {
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(harness.callIsZeroExp(value), value == 0, "expected harness.callIsZeroExp(value) to equal value == 0");
    }

    ////////////////////////////////////////////////////////////
    //                      CallSafe224                       //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callSafe224_success(uint224 value) external view {
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callSafe224(uint256(value), "SAFE224"),
            value,
            "safe224 conversion did not return the original value"
        );
    }

    function test_fuzz_callSafe224_revertsWith_SAFE224_revertsWhenTooLarge(uint256 value) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        value = bound(value, uint256(type(uint224).max) + 1, type(uint256).max);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert("SAFE224");

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callSafe224(value, "SAFE224");
    }

    ////////////////////////////////////////////////////////////
    //                       CallSafe32                       //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callSafe32_success(uint32 value) external view {
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callSafe32(uint256(value), "SAFE32"), value, "safe32 conversion did not return the original value"
        );
    }

    function test_fuzz_callSafe32_revertsWith_SAFE32_revertsWhenTooLarge(uint256 value) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        value = bound(value, uint256(type(uint32).max) + 1, type(uint256).max);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert("SAFE32");

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callSafe32(value, "SAFE32");
    }

    ////////////////////////////////////////////////////////////
    //                       CallAddExp                       //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callAddExp_success(uint256 left, uint256 right) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        left = bound(left, 0, DOUBLE_SCALE);
        right = bound(right, 0, DOUBLE_SCALE);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callAddExp(left, right),
            left + right,
            "expected harness.callAddExp(left, right) to equal left + right"
        );
    }

    ////////////////////////////////////////////////////////////
    //                     CallAddDouble                      //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callAddDouble_success(uint256 left, uint256 right) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        left = bound(left, 0, DOUBLE_SCALE);
        right = bound(right, 0, DOUBLE_SCALE);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callAddDouble(left, right),
            left + right,
            "expected harness.callAddDouble(left, right) to equal left + right"
        );
    }

    ////////////////////////////////////////////////////////////
    //                      CallTruncate                      //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callTruncate_success(uint256 mantissa) external view {
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callTruncate(mantissa),
            mantissa / EXP_SCALE,
            "expected harness.callTruncate(mantissa) to equal mantissa / EXP_SCALE"
        );
    }

    ////////////////////////////////////////////////////////////
    //                  CallMulScalarTruncate                //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callMulScalarTruncate_success(uint256 mantissa, uint256 scalar) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 maxScalar = type(uint256).max / DOUBLE_SCALE;
        mantissa = bound(mantissa, 0, DOUBLE_SCALE);
        scalar = bound(scalar, 0, maxScalar);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callMulScalarTruncate(mantissa, scalar),
            (mantissa * scalar) / EXP_SCALE,
            "expected harness.callMulScalarTruncate(mantissa, scalar) to equal (mantissa * scalar) / EXP_SCALE"
        );
    }

    ////////////////////////////////////////////////////////////
    //               CallMulScalarTruncateAddUInt            //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callMulScalarTruncateAddUInt_success(uint256 mantissa, uint256 scalar, uint256 addend)
        external
        view
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 maxScalar = type(uint256).max / DOUBLE_SCALE;
        mantissa = bound(mantissa, 0, DOUBLE_SCALE);
        scalar = bound(scalar, 0, maxScalar);
        addend = bound(addend, 0, DOUBLE_SCALE);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callMulScalarTruncateAddUInt(mantissa, scalar, addend),
            ((mantissa * scalar) / EXP_SCALE) + addend,
            "expected harness.callMulScalarTruncateAddUInt(mantissa, scalar, addend) to equal ((mantissa * scalar) / EXP_SCALE) + addend"
        );
    }

    ////////////////////////////////////////////////////////////
    //                       CallSubExp                       //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callSubExp_success(uint256 left, uint256 right) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        left = bound(left, 0, DOUBLE_SCALE);
        right = bound(right, 0, left);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callSubExp(left, right),
            left - right,
            "expected harness.callSubExp(left, right) to equal left - right"
        );
    }

    function test_fuzz_callSubExp_revertsWith_ArithmeticError_whenRightGreaterThanLeft(uint256 left, uint256 right)
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        left = bound(left, 0, DOUBLE_SCALE - 1);
        right = bound(right, left + 1, DOUBLE_SCALE);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(stdError.arithmeticError);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callSubExp(left, right);
    }

    ////////////////////////////////////////////////////////////
    //                     CallSubDouble                      //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callSubDouble_success(uint256 left, uint256 right) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        left = bound(left, 0, DOUBLE_SCALE);
        right = bound(right, 0, left);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callSubDouble(left, right),
            left - right,
            "expected harness.callSubDouble(left, right) to equal left - right"
        );
    }

    function test_fuzz_callSubDouble_revertsWith_ArithmeticError_whenRightGreaterThanLeft(uint256 left, uint256 right)
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        left = bound(left, 0, DOUBLE_SCALE - 1);
        right = bound(right, left + 1, DOUBLE_SCALE);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(stdError.arithmeticError);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callSubDouble(left, right);
    }

    ////////////////////////////////////////////////////////////
    //                      CallSubUint                       //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callSubUint_success(uint256 left, uint256 right) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        left = bound(left, 0, DOUBLE_SCALE);
        right = bound(right, 0, left);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callSubUint(left, right),
            left - right,
            "expected harness.callSubUint(left, right) to equal left - right"
        );
    }

    function test_fuzz_callSubUint_revertsWith_ArithmeticError_whenRightGreaterThanLeft(uint256 left, uint256 right)
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        left = bound(left, 0, DOUBLE_SCALE - 1);
        right = bound(right, left + 1, DOUBLE_SCALE);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(stdError.arithmeticError);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callSubUint(left, right);
    }

    ////////////////////////////////////////////////////////////
    //                    CallMulExpExp                       //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callMulExpExp_success(uint256 left, uint256 right) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        left = bound(left, 0, DOUBLE_SCALE);
        right = bound(right, 0, DOUBLE_SCALE);
        uint256 expected = (left * right) / EXP_SCALE;

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callMulExpExp(left, right),
            expected,
            "expected harness.callMulExpExp(left, right) to equal expected"
        );
    }

    ////////////////////////////////////////////////////////////
    //                   CallMulExpScalar                     //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callMulExpScalar_success(uint256 mantissa, uint256 scalar) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mantissa = bound(mantissa, 0, DOUBLE_SCALE);
        scalar = bound(scalar, 0, EXP_SCALE);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callMulExpScalar(mantissa, scalar),
            mantissa * scalar,
            "expected harness.callMulExpScalar(mantissa, scalar) to equal mantissa * scalar"
        );
    }

    ////////////////////////////////////////////////////////////
    //                    CallMulUintExp                      //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callMulUintExp_success(uint256 value, uint256 mantissa) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        value = bound(value, 0, DOUBLE_SCALE);
        mantissa = bound(mantissa, 0, DOUBLE_SCALE);
        uint256 expected = (value * mantissa) / EXP_SCALE;

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callMulUintExp(value, mantissa),
            expected,
            "expected harness.callMulUintExp(value, mantissa) to equal expected"
        );
    }

    ////////////////////////////////////////////////////////////
    //                  CallMulDoubleDouble                   //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callMulDoubleDouble_success(uint256 left, uint256 right) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        left = bound(left, 0, DOUBLE_SCALE);
        right = bound(right, 0, DOUBLE_SCALE);
        uint256 expected = (left * right) / DOUBLE_SCALE;

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callMulDoubleDouble(left, right),
            expected,
            "expected harness.callMulDoubleDouble(left, right) to equal expected"
        );
    }

    ////////////////////////////////////////////////////////////
    //                  CallMulDoubleScalar                   //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callMulDoubleScalar_success(uint256 mantissa, uint256 scalar) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mantissa = bound(mantissa, 0, DOUBLE_SCALE);
        scalar = bound(scalar, 0, EXP_SCALE);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callMulDoubleScalar(mantissa, scalar),
            mantissa * scalar,
            "expected harness.callMulDoubleScalar(mantissa, scalar) to equal mantissa * scalar"
        );
    }

    ////////////////////////////////////////////////////////////
    //                   CallMulUintDouble                    //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callMulUintDouble_success(uint256 value, uint256 mantissa) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        value = bound(value, 0, DOUBLE_SCALE);
        mantissa = bound(mantissa, 0, DOUBLE_SCALE);
        uint256 expected = (value * mantissa) / DOUBLE_SCALE;

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callMulUintDouble(value, mantissa),
            expected,
            "expected harness.callMulUintDouble(value, mantissa) to equal expected"
        );
    }

    ////////////////////////////////////////////////////////////
    //                    CallDivExpScalar                    //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callDivExpScalar_success(uint256 mantissa, uint256 divisor) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mantissa = bound(mantissa, 0, DOUBLE_SCALE);
        divisor = bound(divisor, 1, DOUBLE_SCALE);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callDivExpScalar(mantissa, divisor),
            mantissa / divisor,
            "expected harness.callDivExpScalar(mantissa, divisor) to equal mantissa / divisor"
        );
    }

    function test_fuzz_callDivExpScalar_revertsWith_DivisionError_whenDivisorIsZero(uint256 mantissa) external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(stdError.divisionError);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callDivExpScalar(mantissa, 0);
    }

    ////////////////////////////////////////////////////////////
    //                    CallDivExpExp                       //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callDivExpExp_success(uint256 left, uint256 right) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        left = bound(left, 0, MAX_DOUBLE_NUMERATOR);
        right = bound(right, 1, DOUBLE_SCALE);
        uint256 expected = (left * EXP_SCALE) / right;

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callDivExpExp(left, right),
            expected,
            "expected harness.callDivExpExp(left, right) to equal expected"
        );
    }

    function test_fuzz_callDivExpExp_revertsWith_DivisionError_whenRightIsZero(uint256 left) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 maxLeft = type(uint256).max / EXP_SCALE;
        left = bound(left, 0, maxLeft);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(stdError.divisionError);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callDivExpExp(left, 0);
    }

    ////////////////////////////////////////////////////////////
    //                    CallDivUintExp                      //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callDivUintExp_success(uint256 value, uint256 mantissa) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 maxValue = type(uint256).max / EXP_SCALE;
        value = bound(value, 0, maxValue);
        mantissa = bound(mantissa, 1, DOUBLE_SCALE);
        uint256 expected = (value * EXP_SCALE) / mantissa;

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callDivUintExp(value, mantissa),
            expected,
            "expected harness.callDivUintExp(value, mantissa) to equal expected"
        );
    }

    function test_fuzz_callDivUintExp_revertsWith_DivisionError_whenMantissaIsZero(uint256 value) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 maxValue = type(uint256).max / EXP_SCALE;
        value = bound(value, 0, maxValue);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(stdError.divisionError);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callDivUintExp(value, 0);
    }

    ////////////////////////////////////////////////////////////
    //                  CallDivDoubleDouble                   //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callDivDoubleDouble_success(uint256 left, uint256 right) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        left = bound(left, 0, MAX_DOUBLE_NUMERATOR);
        right = bound(right, 1, DOUBLE_SCALE);
        uint256 expected = (left * DOUBLE_SCALE) / right;

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callDivDoubleDouble(left, right),
            expected,
            "expected harness.callDivDoubleDouble(left, right) to equal expected"
        );
    }

    function test_fuzz_callDivDoubleDouble_revertsWith_DivisionError_whenRightIsZero(uint256 left) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        left = bound(left, 0, MAX_DOUBLE_NUMERATOR);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(stdError.divisionError);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callDivDoubleDouble(left, 0);
    }

    ////////////////////////////////////////////////////////////
    //                  CallDivDoubleScalar                   //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callDivDoubleScalar_success(uint256 mantissa, uint256 divisor) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mantissa = bound(mantissa, 0, DOUBLE_SCALE);
        divisor = bound(divisor, 1, DOUBLE_SCALE);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callDivDoubleScalar(mantissa, divisor),
            mantissa / divisor,
            "expected harness.callDivDoubleScalar(mantissa, divisor) to equal mantissa / divisor"
        );
    }

    function test_fuzz_callDivDoubleScalar_revertsWith_DivisionError_whenDivisorIsZero(uint256 mantissa) external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(stdError.divisionError);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callDivDoubleScalar(mantissa, 0);
    }

    ////////////////////////////////////////////////////////////
    //                   CallDivUintDouble                    //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callDivUintDouble_success(uint256 value, uint256 mantissa) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        value = bound(value, 0, MAX_DOUBLE_NUMERATOR);
        mantissa = bound(mantissa, 1, DOUBLE_SCALE);
        uint256 expected = (value * DOUBLE_SCALE) / mantissa;

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callDivUintDouble(value, mantissa),
            expected,
            "expected harness.callDivUintDouble(value, mantissa) to equal expected"
        );
    }

    function test_fuzz_callDivUintDouble_revertsWith_DivisionError_whenMantissaIsZero(uint256 value) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 maxValue = type(uint256).max / DOUBLE_SCALE;
        value = bound(value, 0, maxValue);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(stdError.divisionError);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callDivUintDouble(value, 0);
    }

    ////////////////////////////////////////////////////////////
    //                     CallDivUpUint                      //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callDivUpUint_revertsWith_DIV_BY_ZERO_DIV_revertsWhenDivisorZero(uint256 value) external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert("DIV_BY_ZERO");

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callDivUpUint(value, 0);
    }

    function test_fuzz_callDivUpUint_success_whenDividendIsOne(uint256 divisor) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        divisor = bound(divisor, 1, DOUBLE_SCALE);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(harness.callDivUpUint(0, divisor), 0, "expected harness.callDivUpUint(0, divisor) to equal 0");
    }

    function test_fuzz_callDivUpUint_success_withNonZeroValue(uint256 value, uint256 divisor) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        value = bound(value, 1, DOUBLE_SCALE);
        divisor = bound(divisor, 1, EXP_SCALE);
        uint256 expected = (value + divisor - 1) / divisor;

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callDivUpUint(value, divisor),
            expected,
            "expected harness.callDivUpUint(value, divisor) to equal expected"
        );
    }

    ////////////////////////////////////////////////////////////
    //                      CallDivUpExp                      //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callDivUpExp_success(uint256 value, uint256 mantissa) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 maxValue = type(uint256).max / EXP_SCALE;
        value = bound(value, 0, maxValue);
        mantissa = bound(mantissa, 1, DOUBLE_SCALE);
        uint256 scaled = value * EXP_SCALE;
        uint256 expected = scaled == 0 ? 0 : 1 + ((scaled - 1) / mantissa);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callDivUpExp(value, mantissa),
            expected,
            "expected harness.callDivUpExp(value, mantissa) to equal expected"
        );
    }

    function test_fuzz_callDivUpExp_revertsWith_DIV_BY_ZERO_whenMantissaIsZero(uint256 value) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 maxValue = type(uint256).max / EXP_SCALE;
        value = bound(value, 0, maxValue);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert("DIV_BY_ZERO");

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callDivUpExp(value, 0);
    }

    ////////////////////////////////////////////////////////////
    //                      CallFraction                      //
    ////////////////////////////////////////////////////////////

    function test_fuzz_callFraction_success(uint256 value, uint256 divisor) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        value = bound(value, 0, MAX_DOUBLE_NUMERATOR);
        divisor = bound(divisor, 1, DOUBLE_SCALE);
        uint256 expected = (value * DOUBLE_SCALE) / divisor;

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            harness.callFraction(value, divisor),
            expected,
            "expected harness.callFraction(value, divisor) to equal expected"
        );
    }

    function test_fuzz_callFraction_revertsWith_DivisionError_whenDivisorIsZero(uint256 value) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        value = bound(value, 0, MAX_DOUBLE_NUMERATOR);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(stdError.divisionError);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callFraction(value, 0);
    }
}
