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

contract BatchSubmitterCallTargetMock {
    bool internal _repayShouldRevert;
    bool internal _liquidateShouldRevert;
    bool internal _mintShouldRevert;

    function setRevertFlags(bool repayShouldRevert, bool liquidateShouldRevert, bool mintShouldRevert) external {
        _repayShouldRevert = repayShouldRevert;
        _liquidateShouldRevert = liquidateShouldRevert;
        _mintShouldRevert = mintShouldRevert;
    }

    function mintExternal(bytes calldata, bytes calldata, uint256[] calldata, uint256[] calldata, address)
        external
        view
    {
        if (_mintShouldRevert) {
            revert("MINT_FAIL");
        }
    }

    function repayExternal(bytes calldata, bytes calldata, uint256[] calldata, address) external view {
        if (_repayShouldRevert) {
            revert("REPAY_FAIL");
        }
    }

    function liquidateExternal(
        bytes calldata,
        bytes calldata,
        address[] calldata,
        uint256[] calldata,
        address[] calldata,
        address
    ) external view {
        if (_liquidateShouldRevert) {
            revert("LIQUIDATE_FAIL");
        }
    }
}
