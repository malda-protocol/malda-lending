// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";

import {Deployer} from "src/utils/Deployer.sol";

contract DeployableMock {
    uint256 public value;

    constructor(uint256 _value) payable {
        value = _value;
    }
}

contract DeployerTest is Test {
    event AdminSet(address indexed _admin);
    event PendingAdminSet(address indexed _admin);
    event AdminAccepted(address indexed _admin);

    Deployer internal deployer;
    address internal admin;
    address internal other;

    function setUp() public {
        admin = vm.addr(31);
        other = vm.addr(32);

        deployer = new Deployer(admin);
        vm.deal(admin, 10 ether);
    }

    function test_Constructor_SetsAdmin() public {
        assertEq(deployer.admin(), admin);
    }

    function test_Constructor_RevertWhenZeroAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, address(0), address(this)));
        new Deployer(address(0));
    }

    function test_SetPendingAdmin_Fuzz(address newAdmin) public {
        vm.assume(newAdmin != address(0));
        vm.assume(newAdmin != admin);

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit PendingAdminSet(newAdmin);
        deployer.setPendingAdmin(newAdmin);

        assertEq(deployer.pendingAdmin(), newAdmin);
    }

    function test_SetPendingAdmin_RevertWhenNotAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, admin, other));
        vm.prank(other);
        deployer.setPendingAdmin(other);
    }

    function test_SetPendingAdmin_RevertWhenZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, address(0), admin));
        deployer.setPendingAdmin(address(0));
    }

    function test_AcceptAdmin_TransfersControl(address newAdmin) public {
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

    function test_AcceptAdmin_RevertWhenNotPending(address newAdmin) public {
        vm.assume(newAdmin != address(0));
        vm.assume(newAdmin != admin);

        vm.prank(admin);
        deployer.setPendingAdmin(newAdmin);

        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, newAdmin, other));
        deployer.acceptAdmin();
    }

    function test_SetNewAdmin_Updates(address newAdmin) public {
        vm.assume(newAdmin != address(0));
        vm.assume(newAdmin != admin);

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit AdminSet(newAdmin);
        deployer.setNewAdmin(newAdmin);

        assertEq(deployer.admin(), newAdmin);
    }

    function test_SetNewAdmin_RevertWhenZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, address(0), admin));
        deployer.setNewAdmin(address(0));
    }

    function test_SaveEth_Withdraws(uint96 amountRaw) public {
        uint256 amount = bound(amountRaw, 1, 5 ether);

        vm.deal(address(deployer), amount);

        uint256 adminBalanceBefore = admin.balance;
        vm.prank(admin);
        deployer.saveEth();

        assertEq(address(deployer).balance, 0);
        assertEq(admin.balance, adminBalanceBefore + amount);
    }

    function test_SaveEth_RevertWhenNotAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, admin, other));
        vm.prank(other);
        deployer.saveEth();
    }

    function test_CreateAndPrecompute_Fuzz(bytes32 salt, uint96 valueRaw, uint256 storedValueRaw) public {
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

    function test_Create_RevertWhenNotAdmin(bytes32 salt) public {
        bytes memory code = type(DeployableMock).creationCode;

        vm.expectRevert(abi.encodeWithSelector(Deployer.NotAuthorized.selector, admin, other));
        vm.prank(other);
        deployer.create(salt, code);
    }
}
