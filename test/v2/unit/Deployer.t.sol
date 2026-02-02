// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Deployer} from "src/utils/Deployer.sol";

import {DeployableMock} from "test/v2/mocks/DeployerMocks.t.sol";
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract DeployerTest is BaseTest {
    Deployer internal deployer;
    address internal admin;
    address internal other;

    function setUp() public override {
        super.setUp();
        admin = users.admin;
        other = users.bob;

        deployer = new Deployer(admin);
        vm.deal(admin, 10 ether);
    }

    ////////////////////////////////////////////////////////////
    //                      constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_NotAuthorized() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, address(0), address(this)));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new Deployer(address(0));
    }

    function test_unit_constructor_success_setsAdmin() external {
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        Deployer newDeployer = new Deployer(admin);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(newDeployer.admin(), admin);
        assertEq(newDeployer.pendingAdmin(), address(0));
    }

    ////////////////////////////////////////////////////////////
    //                         admin                          //
    ////////////////////////////////////////////////////////////

    function test_unit_admin_success_returnsAdmin() external view {
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(deployer.admin(), admin);
    }

    ////////////////////////////////////////////////////////////
    //                    setPendingAdmin                     //
    ////////////////////////////////////////////////////////////

    function test_fuzz_setPendingAdmin_success_emits(address newAdmin) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(newAdmin != address(0));
        vm.assume(newAdmin != admin);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true);
        emit Deployer.PendingAdminSet(newAdmin);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(admin);
        deployer.setPendingAdmin(newAdmin);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(deployer.pendingAdmin(), newAdmin);
    }

    function test_unit_setPendingAdmin_revertsWith_NotAuthorized() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, admin, other));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(other);
        deployer.setPendingAdmin(other);
    }

    ////////////////////////////////////////////////////////////
    //                      setNewAdmin                       //
    ////////////////////////////////////////////////////////////

    function test_unit_setNewAdmin_revertsWith_NotAuthorized() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, address(0), admin));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(admin);
        deployer.setNewAdmin(address(0));
    }

    function test_fuzz_setNewAdmin_success_updates(address newAdmin) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(newAdmin != address(0));
        vm.assume(newAdmin != admin);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true);
        emit Deployer.AdminSet(newAdmin);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(admin);
        deployer.setNewAdmin(newAdmin);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(deployer.admin(), newAdmin);
    }

    ////////////////////////////////////////////////////////////
    //                       acceptAdmin                      //
    ////////////////////////////////////////////////////////////

    function test_fuzz_acceptAdmin_success_transfersAdmin(address newAdmin) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(newAdmin != address(0));
        vm.assume(newAdmin != admin);
        vm.assume(newAdmin != other);

        vm.prank(admin);
        deployer.setPendingAdmin(newAdmin);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true);
        emit Deployer.AdminAccepted(newAdmin);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(newAdmin);
        deployer.acceptAdmin();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(deployer.admin(), newAdmin);
        assertEq(deployer.pendingAdmin(), address(0));
    }

    function test_fuzz_acceptAdmin_revertsWith_NotAuthorized(address newAdmin) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(newAdmin != address(0));
        vm.assume(newAdmin != admin);
        vm.assume(newAdmin != other);

        vm.prank(admin);
        deployer.setPendingAdmin(newAdmin);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, newAdmin, other));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(other);
        deployer.acceptAdmin();
    }

    function test_fuzz_setNewAdmin_revertsWith_NotAuthorized_afterAccept(address newAdmin) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(newAdmin != address(0));
        vm.assume(newAdmin != admin);

        vm.prank(admin);
        deployer.setPendingAdmin(newAdmin);

        vm.prank(newAdmin);
        deployer.acceptAdmin();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, newAdmin, admin));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(admin);
        deployer.setNewAdmin(admin);
    }

    ////////////////////////////////////////////////////////////
    //                         saveEth                        //
    ////////////////////////////////////////////////////////////

    function test_unit_saveEth_revertsWith_NotAuthorized() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, admin, other));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(other);
        deployer.saveEth();
    }

    function test_fuzz_saveEth_success(uint96 amountRaw) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amount = bound(amountRaw, 1, 5 ether);
        vm.deal(address(deployer), amount);
        uint256 adminBalanceBefore = admin.balance;

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(admin);
        deployer.saveEth();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(address(deployer).balance, 0);
        assertEq(admin.balance, adminBalanceBefore + amount);
    }

    ////////////////////////////////////////////////////////////
    //                          create                        //
    ////////////////////////////////////////////////////////////

    function test_fuzz_create_success(bytes32 salt, uint96 valueRaw, uint256 storedValueRaw) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 value = bound(valueRaw, 0, 1 ether);
        uint256 storedValue = bound(storedValueRaw, 0, 1e18);

        bytes memory code = abi.encodePacked(type(DeployableMock).creationCode, abi.encode(storedValue));
        address expected = deployer.precompute(salt);

        vm.deal(admin, value);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(admin);
        address deployed = deployer.create{value: value}(salt, code);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(deployed, expected);
        assertGt(deployed.code.length, 0);
        assertEq(DeployableMock(payable(deployed)).value(), storedValue);
        assertEq(deployed.balance, value);
    }

    function test_fuzz_create_revertsWith_NotAuthorized(bytes32 salt) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory code = type(DeployableMock).creationCode;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, admin, other));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(other);
        deployer.create(salt, code);
    }
}
