// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {mTokenStorage} from "src/mToken/mTokenStorage.sol";

import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

contract GoodInterestRateModel {
    function isInterestRateModel() external pure returns (bool) {
        return true;
    }
}

contract BadInterestRateModel {
    function isInterestRateModel() external pure returns (bool) {
        return false;
    }
}

contract mTokenConfiguration_test is mToken_Unit_Shared {
    function test_RevertWhen_NonAdminSetOperator() external {
        vm.prank(alice);
        vm.expectRevert(mTokenStorage.mt_OnlyAdmin.selector);
        mWeth.setOperator(address(operator));
    }

    function test_SetOperator_Updates() external {
        address newOperator = address(0xBEEF);
        mWeth.setOperator(newOperator);

        assertEq(mWeth.operator(), newOperator);
    }

    function test_SetOperator_RevertWhenZero() external {
        vm.expectRevert(mTokenStorage.mt_OperatorNotValid.selector);
        mWeth.setOperator(address(0));
    }

    function test_RevertWhen_NonAdminSetInterestRateModel() external {
        GoodInterestRateModel newModel = new GoodInterestRateModel();

        vm.prank(alice);
        vm.expectRevert(mTokenStorage.mt_OnlyAdmin.selector);
        mWeth.setInterestRateModel(address(newModel));
    }

    function test_SetInterestRateModel_Updates() external {
        GoodInterestRateModel newModel = new GoodInterestRateModel();
        mWeth.setInterestRateModel(address(newModel));

        assertEq(mWeth.interestRateModel(), address(newModel));
    }

    function test_SetInterestRateModel_RevertWhenInvalid() external {
        BadInterestRateModel badModel = new BadInterestRateModel();

        vm.expectRevert(mTokenStorage.mt_MarketMethodNotValid.selector);
        mWeth.setInterestRateModel(address(badModel));
    }

    function test_SetBorrowRateMaxMantissa_NoSupply(uint256 newMax) external {
        newMax = bound(newMax, 0, 1e18);
        mWeth.setBorrowRateMaxMantissa(newMax);

        assertEq(mWeth.borrowRateMaxMantissa(), newMax);
    }

    function test_SetBorrowRateMaxMantissa_WithSupply(uint256 mintAmount, uint256 newMax) external {
        operator.supportMarket(address(mWeth));

        mintAmount = bound(mintAmount, SMALL, LARGE);
        newMax = bound(newMax, 0, 1e18);

        _getTokens(weth, address(this), mintAmount);
        weth.approve(address(mWeth), mintAmount);
        mWeth.mint(mintAmount, address(this), 0);

        mWeth.setBorrowRateMaxMantissa(newMax);

        assertEq(mWeth.borrowRateMaxMantissa(), newMax);
    }

    function test_SetPendingAdmin_RevertWhenZero() external {
        vm.expectRevert(mTokenStorage.mt_AddressNotValid.selector);
        mWeth.setPendingAdmin(payable(address(0)));
    }

    function test_SetPendingAdmin_RevertWhenNotAdmin() external {
        vm.prank(alice);
        vm.expectRevert(mTokenStorage.mt_OnlyAdmin.selector);
        mWeth.setPendingAdmin(payable(bob));
    }

    function test_SetPendingAdmin_AndAcceptAdmin() external {
        address newAdmin = address(0xCAFE);

        mWeth.setPendingAdmin(payable(newAdmin));
        assertEq(mWeth.pendingAdmin(), newAdmin);

        vm.prank(newAdmin);
        mWeth.acceptAdmin();

        assertEq(mWeth.admin(), newAdmin);
        assertEq(mWeth.pendingAdmin(), address(0));
    }

    function test_AcceptAdmin_RevertWhenNotPending() external {
        vm.expectRevert(mTokenStorage.mt_OnlyAdmin.selector);
        mWeth.acceptAdmin();
    }
}
