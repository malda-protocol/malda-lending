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
    //                       Constructor                        //
    ////////////////////////////////////////////////////////////

    function test_unitConstructor_success_SetsAdmin() public view {
        assertEq(deployer.admin(), admin);
    }

    function test_unitConstructor_revertsWith_RevertWhenZeroAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, address(0), address(this)));
        new Deployer(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                     SetPendingAdmin                      //
    ////////////////////////////////////////////////////////////

    function test_unitSetPendingAdmin_success_Fuzz(address newAdmin) public {
        vm.assume(newAdmin != address(0));
        vm.assume(newAdmin != admin);

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit PendingAdminSet(newAdmin);
        deployer.setPendingAdmin(newAdmin);

        assertEq(deployer.pendingAdmin(), newAdmin);
    }

    function test_unitSetPendingAdmin_revertsWith_RevertWhenNotAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, admin, other));
        vm.prank(other);
        deployer.setPendingAdmin(other);
    }

    function test_unitSetPendingAdmin_revertsWith_RevertWhenZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, address(0), admin));
        deployer.setPendingAdmin(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                       AcceptAdmin                        //
    ////////////////////////////////////////////////////////////

    function test_unitAcceptAdmin_success_TransfersControl(address newAdmin) public {
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

    function test_unitAcceptAdmin_revertsWith_RevertWhenNotPending(address newAdmin) public {
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
    //                       SetNewAdmin                        //
    ////////////////////////////////////////////////////////////

    function test_unitSetNewAdmin_success_Updates(address newAdmin) public {
        vm.assume(newAdmin != address(0));
        vm.assume(newAdmin != admin);

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit AdminSet(newAdmin);
        deployer.setNewAdmin(newAdmin);

        assertEq(deployer.admin(), newAdmin);
    }

    function test_unitSetNewAdmin_revertsWith_RevertWhenZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, address(0), admin));
        deployer.setNewAdmin(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                         SaveEth                          //
    ////////////////////////////////////////////////////////////

    function test_unitSaveEth_success_Withdraws(uint96 amountRaw) public {
        uint256 amount = bound(amountRaw, 1, 5 ether);

        vm.deal(address(deployer), amount);

        uint256 adminBalanceBefore = admin.balance;
        vm.prank(admin);
        deployer.saveEth();

        assertEq(address(deployer).balance, 0);
        assertEq(admin.balance, adminBalanceBefore + amount);
    }

    function test_unitSaveEth_revertsWith_RevertWhenNotAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, admin, other));
        vm.prank(other);
        deployer.saveEth();
    }

    ////////////////////////////////////////////////////////////
    //                   CreateAndPrecompute                    //
    ////////////////////////////////////////////////////////////

    function test_unitCreateAndPrecompute_success_Fuzz(bytes32 salt, uint96 valueRaw, uint256 storedValueRaw) public {
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

    ////////////////////////////////////////////////////////////
    //                          Create                          //
    ////////////////////////////////////////////////////////////

    function test_unitCreate_revertsWith_RevertWhenNotAdmin(bytes32 salt) public {
        bytes memory code = type(DeployableMock).creationCode;

        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, admin, other));
        vm.prank(other);
        deployer.create(salt, code);
    }
}
