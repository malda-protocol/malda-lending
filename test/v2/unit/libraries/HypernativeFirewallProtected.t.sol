// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";
import {HypernativeFirewallProtected} from "src/libraries/HypernativeFirewallProtected.sol";
import {MockFirewall} from "test/mocks/MockFirewall.sol";

contract FirewallHarness is HypernativeFirewallProtected {
    bytes32 internal constant FIREWALL_SLOT = bytes32(uint256(keccak256("eip1967.hypernative.firewall")) - 1);
    bytes32 internal constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.hypernative.admin")) - 1);
    bytes32 internal constant MODE_SLOT = bytes32(uint256(keccak256("eip1967.hypernative.is_strict_mode")) - 1);

    uint256 public callCount;

    function initFirewall(address firewall, address admin) external {
        _initHypernativeFirewall(firewall, admin);
    }

    function callOnlyFirewallApprovedAllowEOA() external onlyFirewallApprovedAllowEOA {
        callCount++;
    }

    function callOnlyFirewallAdmin() external onlyFirewallAdmin {
        callCount++;
    }

    function getFirewallAddress() external view returns (address) {
        return _getAddressBySlot(FIREWALL_SLOT);
    }

    function getAdminAddress() external view returns (address) {
        return _getAddressBySlot(ADMIN_SLOT);
    }

    function isStrictMode() external view returns (bool) {
        return _getValueBySlot(MODE_SLOT) == 1;
    }
}

contract FirewallCaller {
    function callApprovedAllowEOA(FirewallHarness harness) external {
        harness.callOnlyFirewallApprovedAllowEOA();
    }
}

contract HypernativeFirewallProtectedTest is BaseTest {
    FirewallHarness internal harness;
    MockFirewall internal firewall;
    FirewallCaller internal caller;

    function setUp() public override {
        super.setUp();
        harness = new FirewallHarness();
        firewall = new MockFirewall();
        caller = new FirewallCaller();
    }

    ////////////////////////////////////////////////////////////
    //             InitFirewallRevertsOnZeroAddress             //
    ////////////////////////////////////////////////////////////

    function test_unitInitFirewallRevertsOnZeroAddress_revertsWith() public {
        vm.expectRevert(HypernativeFirewallProtected.HypernativeFirewallProtected_NotValid.selector);
        harness.initFirewall(address(0), address(this));
    }

    ////////////////////////////////////////////////////////////
    //            OnlyFirewallApprovedAllowEOAForEOA            //
    ////////////////////////////////////////////////////////////

    function test_unitOnlyFirewallApprovedAllowEOAForEOA_success() public {
        harness.initFirewall(address(firewall), address(this));

        address eoa = users.alice;
        vm.prank(eoa, eoa);
        harness.callOnlyFirewallApprovedAllowEOA();

        // EOAs bypass firewall checks entirely (early return when code.length == 0)
        assertEq(firewall.validateBlacklistedCount(), 0);
    }

    ////////////////////////////////////////////////////////////
    //   OnlyFirewallApprovedAllowEOACallsContextForContract    //
    ////////////////////////////////////////////////////////////

    function test_unitOnlyFirewallApprovedAllowEOACallsContextForContract_success() public {
        harness.initFirewall(address(firewall), address(this));
        address origin = users.bob;
        firewall.setExpectedForbiddenContext(address(caller), address(caller));

        vm.prank(origin, origin);
        caller.callApprovedAllowEOA(harness);

        assertEq(firewall.validateBlacklistedCount(), 1);
    }

    ////////////////////////////////////////////////////////////
    //                 OnlyFirewallAdminGuards                  //
    ////////////////////////////////////////////////////////////

    function test_unitOnlyFirewallAdminGuards_success() public {
        harness.initFirewall(address(firewall), address(this));

        vm.prank(users.alice);
        vm.expectRevert(HypernativeFirewallProtected.HypernativeFirewallProtected_NotAdmin.selector);
        harness.callOnlyFirewallAdmin();

        harness.callOnlyFirewallAdmin();
        assertEq(harness.callCount(), 1);
    }

    ////////////////////////////////////////////////////////////
    //                 SetFirewallAndStrictMode                 //
    ////////////////////////////////////////////////////////////

    function test_unitSetFirewallAndStrictMode_success() public {
        harness.initFirewall(address(firewall), address(this));

        MockFirewall firewall2 = new MockFirewall();
        harness.setFirewall(address(firewall2));
        assertEq(harness.getFirewallAddress(), address(firewall2));

        harness.setIsStrictMode(true);
        assertTrue(harness.isStrictMode());
    }

    ////////////////////////////////////////////////////////////
    //                   ChangeFirewallAdmin                    //
    ////////////////////////////////////////////////////////////

    function test_unitChangeFirewallAdmin_success() public {
        harness.initFirewall(address(firewall), address(this));
        address newAdmin = users.carol;

        vm.expectRevert(HypernativeFirewallProtected.HypernativeFirewallProtected_NotValid.selector);
        harness.changeFirewallAdmin(address(0));

        harness.changeFirewallAdmin(newAdmin);
        assertEq(harness.getAdminAddress(), newAdmin);

        vm.prank(newAdmin);
        harness.setIsStrictMode(true);
        assertTrue(harness.isStrictMode());
    }

    ////////////////////////////////////////////////////////////
    //          HypernativeFirewallAdminReturnsCurrent          //
    ////////////////////////////////////////////////////////////

    function test_unitHypernativeFirewallAdminReturnsCurrent_success() public {
        harness.initFirewall(address(firewall), address(this));

        assertEq(harness.hypernativeFirewallAdmin(), address(this));
    }

    ////////////////////////////////////////////////////////////
    //              FirewallRegisterUsesStrictMode              //
    ////////////////////////////////////////////////////////////

    function test_unitFirewallRegisterUsesStrictMode_success() public {
        harness.initFirewall(address(firewall), address(this));

        harness.setIsStrictMode(true);

        harness.firewallRegister(users.alice);
        assertEq(firewall.registerCount(), 1);
        assertTrue(firewall.lastStrictMode());
    }
}
