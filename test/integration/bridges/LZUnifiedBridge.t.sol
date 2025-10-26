// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LZUnifiedBridge} from "src/rebalancer/bridges/LZUnifiedBridge.sol";
import {Base_Integration_Test} from "../Base_Integration_Test.t.sol";

import {MockRoles} from "test/mocks/MockRoles.sol";

import "forge-std/console.sol";

contract MockMarket {
    address public underlying;
    constructor(address _underlying) {
        underlying = _underlying;
    }
}

contract LZUnifiedBridgeIntegrationTest is Base_Integration_Test {
    LZUnifiedBridge bridge;
    MockRoles mockRoles;

    // weETH addresses
    address constant WEETH_LINEA = 0x1Bf74C010E6320bab11e2e5A532b5AC15e0b8aA6;
    address constant WEETH_BASE  = 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A;
    address constant WEETH_ETH   = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address constant WEETH_ADAPTER_ETH = 0xcd2eb13D6831d4602D80E5db9230A57596CDCA63;

    address constant RSETH_LINEA = 0xD2671165570f41BBB3B0097893300b6EB6101E6C;
    address constant RSETH_BASE  = 0xEDfa23602D0EC14714057867A78d01e94176BEA0;
    address constant RSETH_ETH   = 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7;

    uint32 lineaLzId = 30183;
    uint32 baseLzId = 30184;
    uint32 ethLzId = 30101;

    function setUp() public override {
        super.setUp();
    }
    receive() external payable {}

    /// weETH Linea -> Base 
    function test_LineaToBase_weETH_SendFrom() external {
        vm.selectFork(lineaFork);
        mockRoles = new MockRoles();
        bridge = new LZUnifiedBridge(address(mockRoles));
        MockMarket market = new MockMarket(WEETH_LINEA);

        mockRoles.setAllowed(address(this), true);

        uint256 amount = 0.001e18; // 0.001 weETH

        deal(WEETH_LINEA, address(this), amount);
        IERC20(WEETH_LINEA).approve(address(bridge), amount);

        bytes memory message = abi.encode(
            address(market), 
            amount,
            amount, 
            bytes("") 
        );

        uint256 balBefore = IERC20(WEETH_LINEA).balanceOf(address(this));

        bridge.sendMsg{value: 1 ether}(
            amount,
            address(market),
            baseLzId,
            WEETH_LINEA,
            message,
            bytes("")
        );

        uint256 balAfter = IERC20(WEETH_LINEA).balanceOf(address(this));

        assertEq(balAfter, balBefore - amount);
    }

    // need to be run with --evm-version cancun
    //$ forge test --mt test_BaseToLinea_weETH_SendFrom --evm-version cancun -vvvv

    function test_BaseToLinea_weETH_SendFrom() external {
        address impl = 0xde8A2C33655ACA88f258988ED74D1511876343D1;
        console.log("impl code length:", impl.code.length);
        
        // address lzEndpoint = 0x1a44076050125825900e736c501f859c50fE728c;
        // bytes memory stub = hex"600060005560016000fd"; // dummy code: returns cleanly
        // vm.etch(lzEndpoint, stub);

        mockRoles = new MockRoles();
        bridge = new LZUnifiedBridge(address(mockRoles));
        MockMarket market = new MockMarket(WEETH_BASE);

        mockRoles.setAllowed(address(this), true);

        uint256 amount = 0.001e18; // 0.001 weETH

        deal(WEETH_BASE, address(this), amount);
        IERC20(WEETH_BASE).approve(address(bridge), amount);

        bytes memory message = abi.encode(
            address(market), 
            amount,
            amount, 
            bytes("") 
        );

        uint256 balBefore = IERC20(WEETH_BASE).balanceOf(address(this));

        bridge.sendMsg{value: 1 ether}(
            amount,
            address(market),
            lineaLzId,
            WEETH_BASE,
            message,
            bytes("")
        );

        uint256 balAfter = IERC20(WEETH_BASE).balanceOf(address(this));

        assertEq(balAfter, balBefore - amount);
    }

    function test_EthToLinea_weETH_SendFrom() external {
        vm.selectFork(ethFork);
        mockRoles = new MockRoles();
        bridge = new LZUnifiedBridge(address(mockRoles));
        MockMarket market = new MockMarket(WEETH_ETH);

        mockRoles.setAllowed(address(this), true);
        bridge.setBridgeContract(WEETH_ETH, WEETH_ADAPTER_ETH);

        uint256 amount = 0.001e18; // 0.001 weETH

        deal(WEETH_ETH, address(this), amount);
        IERC20(WEETH_ETH).approve(address(bridge), amount);

        bytes memory message = abi.encode(
            address(market), 
            amount,
            amount, 
            bytes("") 
        );

        uint256 balBefore = IERC20(WEETH_ETH).balanceOf(address(this));

        bridge.sendMsg{value: 1 ether}(
            amount,
            address(market),
            lineaLzId,
            WEETH_ETH,
            message,
            bytes("")
        );

        uint256 balAfter = IERC20(WEETH_ETH).balanceOf(address(this));

        assertEq(balAfter, balBefore - amount);
    }
}