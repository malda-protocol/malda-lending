// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LZUnifiedBridge} from "src/rebalancer/bridges/LZUnifiedBridge.sol";
import {Base_Integration_Test} from "../Base_Integration_Test.t.sol";
import {weEthOftMessageExecutor} from "src/rebalancer/bridges/helpers/weEthOftMessageExecutor.sol";
import {MockRoles} from "test/mocks/MockRoles.sol";

import {console} from "forge-std/console.sol";

/// @title MockMarket
/// @author Malda Protocol
/// @notice Minimal mock market that exposes an underlying token address.
contract MockMarket {
    /// @notice Underlying token used by the market.
    address public underlying;

    /// @notice Creates a new mock market.
    /// @param _underlying Underlying token address.
    constructor(address _underlying) {
        underlying = _underlying;
    }
}

/// @title LZUnifiedBridge Integration Tests
/// @author Malda Protocol
/// @notice Fork-based integration tests for LZUnifiedBridge using weETH and rsETH endpoints.
contract LZUnifiedBridgeIntegrationTest is Base_Integration_Test {
    /// @notice Bridge under test.
    LZUnifiedBridge public bridge;
    /// @notice Mock roles contract used by the bridge.
    MockRoles public mockRoles;
    /// @notice OFT executor used for weETH flows.
    weEthOftMessageExecutor public executor;

    // weETH addresses
    address public constant WEETH_LINEA = 0x1Bf74C010E6320bab11e2e5A532b5AC15e0b8aA6;
    address public constant WEETH_BASE = 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A;
    address public constant WEETH_ETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address public constant WEETH_ADAPTER_ETH = 0xcd2eb13D6831d4602D80E5db9230A57596CDCA63;

    // rsETH addresses (kept here for convenience; not used in these tests yet)
    address public constant RSETH_LINEA = 0xD2671165570f41BBB3B0097893300b6EB6101E6C;
    address public constant RSETH_BASE = 0xEDfa23602D0EC14714057867A78d01e94176BEA0;
    address public constant RSETH_ETH = 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7;

    /// @notice LayerZero endpoint IDs per chain.
    uint32 public lineaLzId = 30183;
    uint32 public baseLzId = 30184;
    uint32 public ethLzId = 30101;

    /// @notice Test setup (forks, common fixtures).
    function setUp() public override {
        super.setUp();
    }

    /// @notice Allow this test contract to receive native tokens for fee payment.
    receive() external payable {}

    /// @notice weETH Linea -> Base send flow (fork test).
    function test_LineaToBase_weETH_SendFrom() external {
        vm.skip(true);
        vm.selectFork(lineaFork);

        mockRoles = new MockRoles();
        bridge = new LZUnifiedBridge(address(mockRoles), address(this));
        MockMarket market = new MockMarket(WEETH_LINEA);
        executor = new weEthOftMessageExecutor();

        mockRoles.setAllowed(address(this), true);
        bridge.setOftExecutorContract(WEETH_LINEA, address(executor));

        uint256 amount = 0.001e18; // 0.001 weETH

        deal(WEETH_LINEA, address(this), amount);
        IERC20(WEETH_LINEA).approve(address(bridge), amount);

        bytes memory message = abi.encode(address(market), amount, amount, bytes(""));

        uint256 balBefore = IERC20(WEETH_LINEA).balanceOf(address(this));

        bridge.sendMsg{value: 1 ether}(amount, address(market), baseLzId, WEETH_LINEA, message, bytes(""));

        uint256 balAfter = IERC20(WEETH_LINEA).balanceOf(address(this));

        assertEq(balAfter, balBefore - amount);
    }

    /// @notice weETH Base -> Linea send flow (requires Cancun).
    /// @dev Run with: forge test --mt test_BaseToLinea_weETH_SendFrom --evm-version cancun -vvvv
    function test_BaseToLinea_weETH_SendFrom() external {
        vm.skip(true);

        address impl = 0xde8A2C33655ACA88f258988ED74D1511876343D1;
        console.log("impl code length:", impl.code.length);

        mockRoles = new MockRoles();
        bridge = new LZUnifiedBridge(address(mockRoles), address(this));
        MockMarket market = new MockMarket(WEETH_BASE);
        executor = new weEthOftMessageExecutor();

        mockRoles.setAllowed(address(this), true);
        bridge.setOftExecutorContract(WEETH_BASE, address(executor));

        uint256 amount = 0.001e18; // 0.001 weETH

        deal(WEETH_BASE, address(this), amount);
        IERC20(WEETH_BASE).approve(address(bridge), amount);

        bytes memory message = abi.encode(address(market), amount, amount, bytes(""));

        uint256 balBefore = IERC20(WEETH_BASE).balanceOf(address(this));

        bridge.sendMsg{value: 1 ether}(amount, address(market), lineaLzId, WEETH_BASE, message, bytes(""));

        uint256 balAfter = IERC20(WEETH_BASE).balanceOf(address(this));

        assertEq(balAfter, balBefore - amount);
    }

    /// @notice weETH Ethereum -> Linea send flow (fork test).
    function test_EthToLinea_weETH_SendFrom() external {
        vm.skip(true);
        vm.selectFork(ethFork);

        mockRoles = new MockRoles();
        bridge = new LZUnifiedBridge(address(mockRoles), address(this));
        MockMarket market = new MockMarket(WEETH_ETH);
        executor = new weEthOftMessageExecutor();

        mockRoles.setAllowed(address(this), true);
        bridge.setBridgeContract(WEETH_ETH, WEETH_ADAPTER_ETH);
        bridge.setOftExecutorContract(WEETH_ETH, address(executor));

        uint256 amount = 0.001e18; // 0.001 weETH

        deal(WEETH_ETH, address(this), amount);
        IERC20(WEETH_ETH).approve(address(bridge), amount);

        bytes memory message = abi.encode(address(market), amount, amount, bytes(""));

        uint256 balBefore = IERC20(WEETH_ETH).balanceOf(address(this));

        bridge.sendMsg{value: 1 ether}(amount, address(market), lineaLzId, WEETH_ETH, message, bytes(""));

        uint256 balAfter = IERC20(WEETH_ETH).balanceOf(address(this));

        assertEq(balAfter, balBefore - amount);
    }
}
