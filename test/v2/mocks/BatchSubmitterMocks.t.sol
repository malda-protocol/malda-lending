// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

contract MockBatchHost {
    function repayExternal(bytes calldata, bytes calldata, uint256[] calldata, address) external {}

    function liquidateExternal(
        bytes calldata,
        bytes calldata,
        address[] calldata,
        uint256[] calldata,
        address[] calldata,
        address
    ) external {}
}
