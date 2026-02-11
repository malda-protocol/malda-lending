// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ExponentialNoError} from "src/utils/ExponentialNoError.sol";

contract ExponentialNoErrorHarness is ExponentialNoError {
    function callLessThanExp(uint256 left, uint256 right) external pure returns (bool) {
        return lessThanExp(Exp({mantissa: left}), Exp({mantissa: right}));
    }

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

    function callMulExpExp(uint256 a, uint256 b) external pure returns (uint256) {
        return mul_(Exp({mantissa: a}), Exp({mantissa: b})).mantissa;
    }

    function callMulExpScalar(uint256 a, uint256 b) external pure returns (uint256) {
        return mul_(Exp({mantissa: a}), b).mantissa;
    }

    function callMulUintExp(uint256 a, uint256 b) external pure returns (uint256) {
        return mul_(a, Exp({mantissa: b}));
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

    function callDivExpExp(uint256 a, uint256 b) external pure returns (uint256) {
        return div_(Exp({mantissa: a}), Exp({mantissa: b})).mantissa;
    }

    function callDivUintExp(uint256 a, uint256 b) external pure returns (uint256) {
        return div_(a, Exp({mantissa: b}));
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

    function callTruncate(uint256 mantissa) external pure returns (uint256) {
        return truncate(Exp({mantissa: mantissa}));
    }

    function callMulScalarTruncate(uint256 mantissa, uint256 scalar) external pure returns (uint256) {
        return mul_ScalarTruncate(Exp({mantissa: mantissa}), scalar);
    }

    function callMulScalarTruncateAddUInt(uint256 mantissa, uint256 scalar, uint256 addend)
        external
        pure
        returns (uint256)
    {
        return mul_ScalarTruncateAddUInt(Exp({mantissa: mantissa}), scalar, addend);
    }
}
