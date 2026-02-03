// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {HypernativeFirewallProtected} from "src/libraries/HypernativeFirewallProtected.sol";

import {MockFirewall} from "test/mocks/MockFirewall.sol";
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

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

    modifier whenFirewallInitialized() {
        harness.initFirewall(address(firewall), address(this));
        _;
    }

    ////////////////////////////////////////////////////////////
    //                      initFirewall                      //
    ////////////////////////////////////////////////////////////

    function test_unit_initFirewall_revertsWith_HypernativeFirewallProtected_NotValid() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(HypernativeFirewallProtected.HypernativeFirewallProtected_NotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.initFirewall(address(0), address(this));
    }

    function test_unit_initFirewall_success() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(harness));
        emit HypernativeFirewallProtected.FirewallAdminChanged(address(0), address(this));
        vm.expectEmit(true, true, false, true, address(harness));
        emit HypernativeFirewallProtected.FirewallAddressChanged(address(0), address(firewall));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.initFirewall(address(firewall), address(this));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(harness.hypernativeFirewallAdmin(), address(this), "assertEq failed: values do not match");
        assertEq(harness.getFirewallAddress(), address(firewall), "assertEq failed: values do not match");
        assertEq(harness.getAdminAddress(), address(this), "assertEq failed: values do not match");
    }

    ////////////////////////////////////////////////////////////
    //             onlyFirewallApprovedAllowEOA               //
    ////////////////////////////////////////////////////////////

    function test_fuzz_onlyFirewallApprovedAllowEOA_success_forEOA(address eoa) public whenFirewallInitialized {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(eoa.code.length == 0);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(eoa, eoa);
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callOnlyFirewallApprovedAllowEOA();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(firewall.validateBlacklistedCount(), 0, "assertEq failed: values do not match");
        assertEq(harness.callCount(), 1, "assertEq failed: values do not match");
    }

    function test_unit_onlyFirewallApprovedAllowEOA_success_forContractCaller() public whenFirewallInitialized {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        firewall.setExpectedForbiddenContext(address(caller), address(caller));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.bob, users.bob);
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        caller.callApprovedAllowEOA(harness);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(firewall.validateBlacklistedCount(), 1, "assertEq failed: values do not match");
        assertEq(harness.callCount(), 1, "assertEq failed: values do not match");
    }

    ////////////////////////////////////////////////////////////
    //                 callOnlyFirewallAdmin                  //
    ////////////////////////////////////////////////////////////

    function test_unit_callOnlyFirewallAdmin_revertsWith_HypernativeFirewallProtected_NotAdmin()
        public
        whenFirewallInitialized
    {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(HypernativeFirewallProtected.HypernativeFirewallProtected_NotAdmin.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callOnlyFirewallAdmin();
    }

    function test_unit_callOnlyFirewallAdmin_success() public whenFirewallInitialized {
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callOnlyFirewallAdmin();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(harness.callCount(), 1, "assertEq failed: values do not match");
    }

    ////////////////////////////////////////////////////////////
    //                       setFirewall                      //
    ////////////////////////////////////////////////////////////

    function test_unit_setFirewall_success() public whenFirewallInitialized {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockFirewall firewall2 = new MockFirewall();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(harness));
        emit HypernativeFirewallProtected.FirewallAddressChanged(address(firewall), address(firewall2));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.setFirewall(address(firewall2));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(harness.getFirewallAddress(), address(firewall2), "assertEq failed: values do not match");

        harness.setIsStrictMode(true);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(harness.isStrictMode());
    }

    ////////////////////////////////////////////////////////////
    //                  changeFirewallAdmin                   //
    ////////////////////////////////////////////////////////////

    function test_unit_changeFirewallAdmin_revertsWith_HypernativeFirewallProtected_NotValid()
        public
        whenFirewallInitialized
    {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(HypernativeFirewallProtected.HypernativeFirewallProtected_NotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.changeFirewallAdmin(address(0));
    }

    function test_unit_changeFirewallAdmin_success() public whenFirewallInitialized {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address newAdmin = users.carol;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(harness));
        emit HypernativeFirewallProtected.FirewallAdminChanged(address(this), newAdmin);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.changeFirewallAdmin(newAdmin);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(harness.getAdminAddress(), newAdmin, "assertEq failed: values do not match");

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(newAdmin);
        harness.setIsStrictMode(true);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(harness.isStrictMode());
    }

    ////////////////////////////////////////////////////////////
    //                    firewallRegister                    //
    ////////////////////////////////////////////////////////////

    function test_unit_firewallRegister_success() public whenFirewallInitialized {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        harness.setIsStrictMode(true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.firewallRegister(users.alice);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(firewall.registerCount(), 1, "assertEq failed: values do not match");
        assertEq(firewall.lastRegistered(), users.alice, "assertEq failed: values do not match");
        assertTrue(firewall.lastStrictMode());
    }
}
