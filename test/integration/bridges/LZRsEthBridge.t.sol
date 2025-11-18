// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LZRsEthBridge} from "src/rebalancer/bridges/deprecated/LZRsEthBridge.sol";
import {Base_Integration_Test} from "../Base_Integration_Test.t.sol";
import {MockRoles} from "test/mocks/MockRoles.sol";

import {LZOptions} from "src/libraries/LZOptions.sol";
import "forge-std/console.sol";

contract MockMarket {
    address public underlying;
    constructor(address _underlying) {
        underlying = _underlying;
    }
}

contract LZUnifiedBridgeIntegrationTest is Base_Integration_Test {
    LZRsEthBridge bridge;
    MockRoles mockRoles;

    // markets
    address constant RSETH_LINEA = 0xD2671165570f41BBB3B0097893300b6EB6101E6C;
    address constant RSETH_BASE  = 0xEDfa23602D0EC14714057867A78d01e94176BEA0;
    address constant RSETH_ETH   = 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7;

    // OFTs
    address constant RSETH_LINEA_OFT = 0x4186BFC76E2E237523CBC30FD220FE055156b41F;
    address constant RSETH_BASE_OFT  = 0x1Bc71130A0e39942a7658878169764Bbd8A45993;

    // LZ EIDs
    uint32 lineaLzId = 30183;
    uint32 baseLzId  = 30184;
    uint32 ethLzId   = 30101;

    function setUp() public override {
        super.setUp();
    }

    receive() external payable {}

    /// rsETH Base -> Linea
    function test_BaseToLinea_rsETH_SendFrom() external {
        vm.skip(true); //because of cancun flag
        vm.selectFork(baseFork);
        mockRoles = new MockRoles();
        bridge = new LZRsEthBridge(address(mockRoles), address(this));
        MockMarket market = new MockMarket(RSETH_BASE);

        mockRoles.setAllowed(address(this), true);
        bridge.setBridgeContract(RSETH_BASE, RSETH_BASE_OFT);

        uint256 amount = 10000000000000; // 0.001 rsETH (legacy)

        deal(RSETH_BASE, address(this), amount);
        IERC20(RSETH_BASE).approve(address(bridge), amount);

        bytes memory extraOptions = buildComposeOptions(
            250_000,  // gas for OFT lzReceive (mint + enqueue compose)
            250_000   // gas for LZRsEthBridge.lzCompose (withdraw + transfer)
        );

        bytes memory message = abi.encode(
            0xa31963C753f277f7d82d98F56b2C374256925eB7,
            amount,
            amount,
            ""
        );

        console.logBytes(message);

        uint256 balBefore = IERC20(RSETH_BASE).balanceOf(address(this));

        bridge.sendMsg{value: 1 ether}(
            amount,
            address(market),
            lineaLzId,
            RSETH_BASE,
            message,
            bytes("")
        );

        uint256 balAfter = IERC20(RSETH_BASE).balanceOf(address(this));
        assertEq(balAfter, balBefore - amount);
    }

    function buildComposeOptions(uint128 gasForReceive, uint128 gasForCompose) internal pure returns (bytes memory) {
        bytes memory extraOptions = LZOptions
            .addExecutorLzComposeOption(
                LZOptions.addExecutorLzReceiveOption(
                    LZOptions.newOptions(),
                    250_000,
                    0        
                ),
                0,        
                250_000,  
                0         
            );
        return extraOptions;
    }
}
