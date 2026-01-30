// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

import {Deployer} from "src/utils/Deployer.sol";
import {DeployableMock} from "test/v2/mocks/DeployerMocks.t.sol";

contract DeployerTest is BaseTest {
    event AdminSet(address indexed _admin);
    event PendingAdminSet(address indexed _admin);
    event AdminAccepted(address indexed _admin);

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
    //                         Admin                          //
    ////////////////////////////////////////////////////////////

    function test_unit_admin_success_setsAdmin() public view {
        assertEq(deployer.admin(), admin);
    }

    ////////////////////////////////////////////////////////////
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_NotAuthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, address(0), address(this)));
        new Deployer(address(0));
    }

    function test_unit_constructor_success() public {
        Deployer newDeployer = new Deployer(admin);

        assertEq(newDeployer.admin(), admin);
        assertEq(newDeployer.pendingAdmin(), address(0));
    }

    ////////////////////////////////////////////////////////////
    //                    SetPendingAdmin                     //
    ////////////////////////////////////////////////////////////

    function test_unit_setPendingAdmin_success(address newAdmin) public {
        vm.assume(newAdmin != address(0));
        vm.assume(newAdmin != admin);

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit PendingAdminSet(newAdmin);
        deployer.setPendingAdmin(newAdmin);

        assertEq(deployer.pendingAdmin(), newAdmin);
    }

    function test_unit_setPendingAdmin_revertsWith_NotAuthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, admin, other));
        vm.prank(other);
        deployer.setPendingAdmin(other);
    }

    ////////////////////////////////////////////////////////////
    //                      SetNewAdmin                       //
    ////////////////////////////////////////////////////////////

    function test_unit_setNewAdmin_revertsWith_NotAuthorized() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, address(0), admin));
        deployer.setNewAdmin(address(0));
    }

    function test_unit_setNewAdmin_success_updates(address newAdmin) public {
        vm.assume(newAdmin != address(0));
        vm.assume(newAdmin != admin);

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit AdminSet(newAdmin);
        deployer.setNewAdmin(newAdmin);

        assertEq(deployer.admin(), newAdmin);
    }

    ////////////////////////////////////////////////////////////
    //                      AcceptAdmin                       //
    ////////////////////////////////////////////////////////////

    function test_unit_acceptAdmin_revertsWith_NotAuthorized_variant1(address newAdmin) public {
        vm.assume(newAdmin != address(0));
        vm.assume(newAdmin != admin);
        vm.assume(newAdmin != other);

        vm.prank(admin);
        deployer.setPendingAdmin(newAdmin);

        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, newAdmin, other));
        deployer.acceptAdmin();
    }

    ////////////////////////////////////////////////////////////
    //                      SetNewAdmin                       //
    ////////////////////////////////////////////////////////////

    function test_unit_setNewAdmin_revertsWith_NotAuthorized_variant2(address newAdmin) public {
        vm.assume(newAdmin != address(0));
        vm.assume(newAdmin != admin);

        vm.prank(admin);
        deployer.setPendingAdmin(newAdmin);

        vm.prank(newAdmin);
        vm.expectEmit(true, false, false, true);
        emit AdminAccepted(newAdmin);
        deployer.acceptAdmin();

        assertEq(deployer.admin(), newAdmin);
        assertEq(deployer.pendingAdmin(), address(0));

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, newAdmin, admin));
        deployer.setNewAdmin(admin);
    }

    // TODO: Test acceptAdmin success

    ////////////////////////////////////////////////////////////
    //                        SaveEth                         //
    ////////////////////////////////////////////////////////////

    function test_unit_saveEth_revertsWith_NotAuthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, admin, other));
        vm.prank(other);
        deployer.saveEth();
    }

    function test_unit_saveEth_success(uint96 amountRaw) public {
        uint256 amount = bound(amountRaw, 1, 5 ether);

        vm.deal(address(deployer), amount);

        uint256 adminBalanceBefore = admin.balance;
        vm.prank(admin);
        deployer.saveEth();

        assertEq(address(deployer).balance, 0);
        assertEq(admin.balance, adminBalanceBefore + amount);
    }

    ////////////////////////////////////////////////////////////
    //                         Create                         //
    ////////////////////////////////////////////////////////////

    function test_fuzz_create_success(bytes32 salt, uint96 valueRaw, uint256 storedValueRaw) public {
        uint256 value = bound(valueRaw, 0, 1 ether);
        uint256 storedValue = bound(storedValueRaw, 0, 1e18);

        bytes memory code = abi.encodePacked(type(DeployableMock).creationCode, abi.encode(storedValue));
        address expected = deployer.precompute(salt);

        vm.deal(admin, value);
        vm.prank(admin);
        address deployed = deployer.create{value: value}(salt, code);

        assertEq(deployed, expected);
        assertGt(deployed.code.length, 0);
        assertEq(DeployableMock(payable(deployed)).value(), storedValue);
        assertEq(deployed.balance, value);
    }

    function test_unit_create_revertsWith_NotAuthorized(bytes32 salt) public {
        bytes memory code = type(DeployableMock).creationCode;

        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, admin, other));
        vm.prank(other);
        deployer.create(salt, code);
    }
}
