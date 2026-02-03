// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";
import {LZUnifiedBridge} from "src/rebalancer/bridges/LZUnifiedBridge.sol";
import {MockRoles} from "test/mocks/MockRoles.sol";
import {
    LZBridgeMockExecutor,
    LZBridgeMockOFT,
    LZBridgeRevertingExecutor
} from "test/v2/mocks/rebalancer/LZUnifiedBridgeMocks.t.sol";
import {MockMarket} from "test/v2/mocks/rebalancer/AcrossBridgeMocks.t.sol";
import {BaseForkTest} from "test/v2/utils/BaseForkTest.t.sol";

/// @title LZUnifiedBridge Fork Tests
/// @author Malda Protocol
/// @notice Fork-based tests for LZUnifiedBridge using weETH and rsETH endpoints
contract LZUnifiedBridgeForkTest is BaseForkTest {
    /// @notice Bridge under test
    LZUnifiedBridge public bridge;
    /// @notice Mock roles contract used by the bridge
    MockRoles public mockRoles;
    /// @notice Mock OFT used for send fee quotes
    LZBridgeMockOFT public oft;
    /// @notice Mock executor used for send flows
    LZBridgeMockExecutor public executor;

    // weETH addresses
    address public constant WEETH_LINEA = 0x1Bf74C010E6320bab11e2e5A532b5AC15e0b8aA6;
    address public constant WEETH_BASE = 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A;
    address public constant WEETH_ETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address public constant WEETH_ADAPTER_ETH = 0xcd2eb13D6831d4602D80E5db9230A57596CDCA63;

    // rsETH addresses (kept here for convenience; not used in these tests yet)
    address public constant RSETH_LINEA = 0xD2671165570f41BBB3B0097893300b6EB6101E6C;
    address public constant RSETH_BASE = 0xEDfa23602D0EC14714057867A78d01e94176BEA0;
    address public constant RSETH_ETH = 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7;

    /// @notice LayerZero endpoint IDs per chain
    uint32 public lineaLzId = 30183;
    uint32 public baseLzId = 30184;
    uint32 public ethLzId = 30101;

    /// @notice Test setup (forks, common fixtures)
    function setUp() public override {
        super.setUp();
    }

    /// @notice Allow this test contract to receive native tokens for fee payment
    receive() external payable {}

    /// @notice weETH Linea -> Base send flow (fork test)

    ////////////////////////////////////////////////////////////
    //                        SendMsg                         //
    ////////////////////////////////////////////////////////////

    function test_fork_sendMsg_success_lineaToBaseWeEth() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _selectLineaFork();

        MockMarket market = _deployBridge(WEETH_LINEA);
        oft.setQuoteFee(0.1 ether, 0);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 amount = 0.001e18;
        bytes memory message = _message(address(market), amount, amount);
        bytes memory extraData = _extraData(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit LZUnifiedBridge.MsgSent(baseLzId, address(market), amount, amount, bytes32("guid"));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg{value: 0.1 ether}(amount, address(market), baseLzId, WEETH_LINEA, message, extraData);
    }

    /// @notice weETH Base -> Linea send flow (requires Cancun)
    /// @dev Run with: forge test --mt test_BaseToLinea_weETH_SendFrom --evm-version cancun -vvvv

    function test_fork_sendMsg_success_baseToLineaWeEth() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _selectBaseFork();

        MockMarket market = _deployBridge(WEETH_BASE);
        oft.setQuoteFee(0.1 ether, 0);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 amount = 0.001e18;
        bytes memory message = _message(address(market), amount, amount);
        bytes memory extraData = _extraData(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit LZUnifiedBridge.MsgSent(lineaLzId, address(market), amount, amount, bytes32("guid"));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg{value: 0.1 ether}(amount, address(market), lineaLzId, WEETH_BASE, message, extraData);
    }

    /// @notice weETH Ethereum -> Linea send flow (fork test)

    function test_fork_sendMsg_success_ethToLineaWeEth() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _selectEthFork();

        MockMarket market = _deployBridge(WEETH_ETH);
        oft.setQuoteFee(0.1 ether, 0);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 amount = 0.001e18;
        bytes memory message = _message(address(market), amount, amount);
        bytes memory extraData = _extraData(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit LZUnifiedBridge.MsgSent(lineaLzId, address(market), amount, amount, bytes32("guid"));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg{value: 0.1 ether}(amount, address(market), lineaLzId, WEETH_ETH, message, extraData);
    }

    function test_fork_sendMsg_revertsWith_BaseBridge_NotAuthorized() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _selectLineaFork();
        mockRoles = new MockRoles();
        bridge = new LZUnifiedBridge(address(mockRoles), address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(1, address(0), baseLzId, WEETH_LINEA, _message(address(0), 1, 1), _extraData(address(this)));
    }

    function test_fork_sendMsg_revertsWith_LZBridge_ChainNotRegistered() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _selectLineaFork();
        MockMarket market = _deployBridge(WEETH_LINEA);
        oft.setQuoteFee(0, 0);
        bytes memory message = _message(address(market), 1, 1);
        bytes memory extraData = _extraData(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_ChainNotRegistered.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(1, address(market), 0, WEETH_LINEA, message, extraData);
    }

    function test_fork_sendMsg_revertsWith_LZBridge_DestinationMismatch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _selectLineaFork();
        MockMarket market = _deployBridge(WEETH_LINEA);
        oft.setQuoteFee(0, 0);
        bytes memory message = _message(users.alice, 1, 1);
        bytes memory extraData = _extraData(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_DestinationMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(1, address(market), baseLzId, WEETH_LINEA, message, extraData);
    }

    function test_fork_sendMsg_revertsWith_LZBridge_TokenMismatch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _selectLineaFork();
        MockMarket market = _deployBridge(WEETH_LINEA);
        oft.setQuoteFee(0, 0);
        bytes memory message = _message(address(market), 1, 1);
        bytes memory extraData = _extraData(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_TokenMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(1, address(market), baseLzId, WEETH_BASE, message, extraData);
    }

    function test_fork_sendMsg_revertsWith_LZBridge_ExecutorNotSet() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _selectLineaFork();
        MockMarket market = _deployBridge(WEETH_LINEA);
        bridge.setOftExecutorContract(WEETH_LINEA, address(0));
        oft.setQuoteFee(0, 0);
        bytes memory message = _message(address(market), 1, 1);
        bytes memory extraData = _extraData(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_ExecutorNotSet.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(1, address(market), baseLzId, WEETH_LINEA, message, extraData);
    }

    function test_fork_sendMsg_revertsWith_LZBridge_NotEnoughFees() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _selectLineaFork();
        MockMarket market = _deployBridge(WEETH_LINEA);
        oft.setQuoteFee(1 ether, 0);
        bytes memory message = _message(address(market), 1, 1);
        bytes memory extraData = _extraData(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_NotEnoughFees.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg{value: 0.1 ether}(1, address(market), baseLzId, WEETH_LINEA, message, extraData);
    }

    function test_fork_sendMsg_revertsWith_BaseBridge_AmountMismatch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _selectLineaFork();
        MockMarket market = _deployBridge(WEETH_LINEA);
        oft.setQuoteFee(0, 0);
        bytes memory message = _message(address(market), 1, 1);
        bytes memory extraData = _extraData(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_AmountMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(2, address(market), baseLzId, WEETH_LINEA, message, extraData);
    }

    function test_fork_sendMsg_revertsWith_LZBridge_RefunderNotValid() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _selectLineaFork();
        MockMarket market = _deployBridge(WEETH_LINEA);
        oft.setQuoteFee(0, 0);
        bytes memory message = _message(address(market), 1, 1);
        bytes memory extraData = _extraData(address(0));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_RefunderNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(1, address(market), baseLzId, WEETH_LINEA, message, extraData);
    }

    function test_fork_sendMsg_revertsWith_LZBridge_ExecutorNoCode() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _selectLineaFork();
        MockMarket market = _deployBridge(WEETH_LINEA);
        bridge.setOftExecutorContract(WEETH_LINEA, address(1));
        oft.setQuoteFee(0, 0);
        bytes memory message = _message(address(market), 1, 1);
        bytes memory extraData = _extraData(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_ExecutorNoCode.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(1, address(market), baseLzId, WEETH_LINEA, message, extraData);
    }

    function test_fork_sendMsg_revertsWith_ExecutorRevert() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _selectLineaFork();
        MockMarket market = _deployBridge(WEETH_LINEA);
        bridge.setOftExecutorContract(WEETH_LINEA, address(new LZBridgeRevertingExecutor()));
        oft.setQuoteFee(0, 0);
        bytes memory message = _message(address(market), 1, 1);
        bytes memory extraData = _extraData(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZBridgeRevertingExecutor.ExecutorRevert.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(1, address(market), baseLzId, WEETH_LINEA, message, extraData);
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _deployBridge(address underlying) internal returns (MockMarket market) {
        mockRoles = new MockRoles();
        mockRoles.setAllowed(address(this), true);

        bridge = new LZUnifiedBridge(address(mockRoles), address(this));
        market = new MockMarket(underlying);
        oft = new LZBridgeMockOFT(underlying);
        executor = new LZBridgeMockExecutor();

        bridge.setBridgeContract(underlying, address(oft));
        bridge.setOftExecutorContract(underlying, address(executor));
    }

    function _message(address market, uint256 amount, uint256 minAmount) internal pure returns (bytes memory) {
        return abi.encode(market, amount, minAmount, bytes(""));
    }

    function _extraData(address refunder) internal pure returns (bytes memory) {
        return abi.encode(refunder);
    }
}
