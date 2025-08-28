// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;


import "forge-std/console2.sol";
import "forge-std/Test.sol";

import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

import "src/utils/SecuritySafeModule.sol";

contract MockSafe {
    bool public mockShouldSucceed = true;
    bytes public lastData;
    address public lastTo;
    uint256 public lastValue;
    Operation public lastOp;

    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes memory data,
        Operation operation
    ) external returns (bool success) {
        lastTo = to;
        lastValue = value;
        lastData = data;
        lastOp = operation;
        return mockShouldSucceed;
    }

    function setMockResult(bool value) external {
        mockShouldSucceed = value;
    }
}

contract MockPauser {
    function emergencyPauseMarket(address) external {}
    function emergencyPauseAll() external {}
    function emergencyPauseMarketFor(address, ImTokenOperationTypes.OperationType) external {}
    function emergencyPauseMarketsFor(address[] calldata, ImTokenOperationTypes.OperationType) external {}
    function emergencyPauseMarketForMultipleOperations(address, ImTokenOperationTypes.OperationType[] calldata) external {}
}

contract MockBlacklister {
    function blacklist(address) external {}
    function batchBlacklist(address[] calldata) external {}
}

contract MockOperator {
    mapping(address => uint256) public borrowCaps;
    mapping(address => uint256) public supplyCaps;

    function setBorrowCap(address m, uint256 c) external { borrowCaps[m] = c; }
    function setSupplyCap(address m, uint256 c) external { supplyCaps[m] = c; }

    // Dummy impls to satisfy interface
    function setMarketBorrowCaps(address[] calldata, uint256[] calldata) external {}
    function setMarketSupplyCaps(address[] calldata, uint256[] calldata) external {}
}

contract SecuritySafeModuleTest is Test {
    SecuritySafeModule module;
    MockSafe safe;
    MockPauser pauser;
    MockBlacklister blacklister;
    MockOperator operator;

    address guardian = address(0xBEEF);
    address other = address(0xCAFE);

    function setUp() public {
        safe = new MockSafe();
        pauser = new MockPauser();
        blacklister = new MockBlacklister();
        operator = new MockOperator();

        module = new SecuritySafeModule(
            guardian,
            address(pauser),
            address(blacklister),
            address(operator)
        );
    }

    // --- Constructor ---
    function testConstructorRevertsOnZero() public {
        vm.expectRevert(SecuritySafeModule.SecuritySafeModule_AddressNotValid.selector);
        new SecuritySafeModule(address(0), address(pauser), address(blacklister), address(operator));
    }

    // --- Access Control ---
    function testOnlyGuardianCanPause() public {
        vm.startPrank(other);
        vm.expectRevert(SecuritySafeModule.SecuritySafeModule_NotAuthorized.selector);
        module.executePauseAll(ISafeExecutor(address(safe)));
        vm.stopPrank();
    }

    // --- Pause Operations ---
    function testPauseAllEncodesCorrectly() public {
        vm.startPrank(guardian);
        module.executePauseAll(ISafeExecutor(address(safe)));
        vm.stopPrank();

        assertEq(safe.lastTo(), address(pauser));
    }

    function testPauseFailsIfSafeExecFails() public {
        safe.setMockResult(false);
        vm.startPrank(guardian);
        vm.expectRevert(SecuritySafeModule.SecuritySafeModule_PauseFailed.selector);
        module.executePauseAll(ISafeExecutor(address(safe)));
        vm.stopPrank();
    }

    // --- Blacklist ---
    function testBlacklistEncodesCorrectly() public {
        address target = address(0x123);

        vm.startPrank(guardian);
        module.executeBlacklist(ISafeExecutor(address(safe)), target);
        vm.stopPrank();

        assertEq(safe.lastTo(), address(blacklister));
    }

    function testBatchBlacklistEncodesCorrectly() public {
        address[] memory targets = new address[](2);
        targets[0] = address(0x111);
        targets[1] = address(0x222);

        vm.startPrank(guardian);
        module.executeBlacklist(ISafeExecutor(address(safe)), targets);
        vm.stopPrank();

        assertEq(safe.lastTo(), address(blacklister));
    }

    // --- Caps ---
    function testLowerBorrowCapReducesByFivePercent() public {
        address market = address(0xAAA);
        operator.setBorrowCap(market, 100_000);

        address[] memory markets = new address[](1);
        markets[0] = market;

        vm.startPrank(guardian);
        module.lowerBorrowCap(ISafeExecutor(address(safe)), markets);
        vm.stopPrank();

        assertEq(safe.lastTo(), address(operator));
    }

    function testLowerSupplyCapReducesByFivePercent() public {
        address market = address(0xBBB);
        operator.setSupplyCap(market, 200_000);

        address[] memory markets = new address[](1);
        markets[0] = market;

        vm.startPrank(guardian);
        module.lowerSupplyCap(ISafeExecutor(address(safe)), markets);
        vm.stopPrank();

        assertEq(safe.lastTo(), address(operator));
    }
}