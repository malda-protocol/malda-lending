// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Vm} from "forge-std/Vm.sol";

import {Roles} from "src/Roles.sol";
import {LZOptions} from "src/libraries/LZOptions.sol";
import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";
import {LZUnifiedBridge} from "src/rebalancer/bridges/LZUnifiedBridge.sol";

import {
    ComposeRevertingExecutor,
    DummyMarket,
    LZSendExecutor,
    ProcessRevertingExecutor,
    RevertingExecutor
} from "test/v2/mocks/rebalancer/LZUnifiedBridgeForkMocks.t.sol";
import {BaseForkTest} from "test/v2/utils/BaseForkTest.t.sol";

/// @title LZUnifiedBridge Fork Tests
/// @author Malda Protocol
/// @notice Fork-based tests for LZUnifiedBridge that run against real OFT contracts on real forks (no mocks).
contract LZUnifiedBridgeForkTest is BaseForkTest {
    Roles internal roles;
    LZUnifiedBridge internal bridge;
    LZSendExecutor internal executor;

    // weETH addresses
    address internal constant WEETH_LINEA = 0x1Bf74C010E6320bab11e2e5A532b5AC15e0b8aA6;
    address internal constant WEETH_BASE = 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A;
    address internal constant WEETH_ETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address internal constant WEETH_ADAPTER_ETH = 0xcd2eb13D6831d4602D80E5db9230A57596CDCA63;

    // Token holders at the pinned fork blocks (used to fund test addresses without `deal`).
    address internal constant WEETH_LINEA_HOLDER = 0x3E944fF6573a62cb9D55e39CC954Ebbdcffb7984;
    address internal constant WEETH_BASE_HOLDER = 0x52Aa899454998Be5b000Ad077a46Bbe360F4e497;
    address internal constant WEETH_ETH_HOLDER = 0x394a1e1b934cb4F4a0dC17BDD592ec078741542F;

    // Rich native token sources (WETH contracts hold the chain's native ETH).
    address internal constant LINEA_WETH = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;
    address internal constant BASE_WETH = 0x4200000000000000000000000000000000000006;
    address internal constant ETH_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // LayerZero endpoint IDs per chain
    uint32 internal constant LINEA_LZ_ID = 30_183;
    uint32 internal constant BASE_LZ_ID = 30_184;

    uint256 internal constant DEFAULT_SEND_AMOUNT = 0.001e18;
    // The OFT rounds/normalizes amounts to shared decimals, so tiny `amountLD` values can revert.
    uint256 internal constant _MIN_OFT_AMOUNT = 1e12;
    uint256 internal constant _SMALL_AMOUNT = 1;
    address internal constant _BOGUS_ADDRESS = address(0xBEEF);
    address internal constant _NON_ZERO_ADDRESS = address(1);

    function setUp() public override {
        super.setUp();
    }

    receive() external payable {}

    ////////////////////////////////////////////////////////////
    //                        SendMsg                         //
    ////////////////////////////////////////////////////////////

    function test_fork_constructor_revertsWith_LZBridge_EndpointZero() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        roles = new Roles(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_EndpointZero.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new LZUnifiedBridge(address(roles), address(0));
    }

    function test_fork_sendMsg_revertsWith_BaseBridge_NotAuthorized_whenNotRebalancer() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();
        _configureWeEthExecutor(WEETH_LINEA, address(0));

        DummyMarket market = new DummyMarket(WEETH_LINEA);
        bytes memory message = abi.encode(address(market), _SMALL_AMOUNT, _SMALL_AMOUNT, bytes(""));
        bytes memory extraData = abi.encode(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.prank(users.alice);
        vm.expectRevert(BaseBridge.BaseBridge_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(_SMALL_AMOUNT, address(market), BASE_LZ_ID, WEETH_LINEA, message, extraData);
    }

    function test_fork_sendMsg_success_lineaToBaseWeEth() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();
        _configureWeEthExecutor(WEETH_LINEA, address(0));

        DummyMarket market = new DummyMarket(WEETH_LINEA);

        uint256 amount = DEFAULT_SEND_AMOUNT;
        _fundErc20FromHolder(WEETH_LINEA, WEETH_LINEA_HOLDER, address(this), amount);
        IERC20(WEETH_LINEA).approve(address(bridge), amount);

        bytes memory options = _defaultOptions();
        bytes memory message = abi.encode(address(market), amount, amount, options);
        bytes memory extraData = abi.encode(address(this));

        uint256 fee = bridge.getFee(BASE_LZ_ID, message, extraData);
        _selfFundEth(LINEA_WETH, fee);

        uint256 balanceBefore = IERC20(WEETH_LINEA).balanceOf(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, false, address(bridge));
        emit LZUnifiedBridge.MsgSent(BASE_LZ_ID, address(market), 0, 0, bytes32(0));
        vm.recordLogs();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg{value: fee}(amount, address(market), BASE_LZ_ID, WEETH_LINEA, message, extraData);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 balanceAfter = IERC20(WEETH_LINEA).balanceOf(address(this));
        assertEq(balanceAfter, balanceBefore - amount, "rebalancer weETH balance did not decrease by amount");

        (uint32 dstEid, address loggedMarket, uint256 amountLD, uint256 minAmountLD, bytes32 guid) = _findMsgSent();
        assertEq(uint256(dstEid), uint256(BASE_LZ_ID), "dstChainId is not BASE_LZ_ID");
        assertEq(loggedMarket, address(market), "market in MsgSent is not the expected market");
        assertEq(amountLD, amount, "amountLD in MsgSent is not amount");
        assertEq(minAmountLD, amount, "minAmountLD in MsgSent is not amount");
        assertTrue(guid != bytes32(0), "MsgSent guid is zero");
    }

    function test_fork_sendMsg_success_baseToLineaWeEth() external {
        _selectBaseFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();
        _configureWeEthExecutor(WEETH_BASE, address(0));

        DummyMarket market = new DummyMarket(WEETH_BASE);

        uint256 amount = DEFAULT_SEND_AMOUNT;
        _fundErc20FromHolder(WEETH_BASE, WEETH_BASE_HOLDER, address(this), amount);
        IERC20(WEETH_BASE).approve(address(bridge), amount);

        bytes memory options = _defaultOptions();
        bytes memory message = abi.encode(address(market), amount, amount, options);
        bytes memory extraData = abi.encode(address(this));

        uint256 fee = bridge.getFee(LINEA_LZ_ID, message, extraData);
        _selfFundEth(BASE_WETH, fee);

        uint256 balanceBefore = IERC20(WEETH_BASE).balanceOf(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, false, address(bridge));
        emit LZUnifiedBridge.MsgSent(LINEA_LZ_ID, address(market), 0, 0, bytes32(0));
        vm.recordLogs();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg{value: fee}(amount, address(market), LINEA_LZ_ID, WEETH_BASE, message, extraData);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 balanceAfter = IERC20(WEETH_BASE).balanceOf(address(this));
        assertEq(balanceAfter, balanceBefore - amount, "rebalancer weETH(Base) balance did not decrease by amount");

        (uint32 dstEid, address loggedMarket, uint256 amountLD, uint256 minAmountLD, bytes32 guid) = _findMsgSent();
        assertEq(uint256(dstEid), uint256(LINEA_LZ_ID), "dstChainId is not LINEA_LZ_ID");
        assertEq(loggedMarket, address(market), "market in MsgSent is not the expected market");
        assertEq(amountLD, amount, "amountLD in MsgSent is not amount");
        assertEq(minAmountLD, amount, "minAmountLD in MsgSent is not amount");
        assertTrue(guid != bytes32(0), "MsgSent guid is zero");
    }

    function test_fork_sendMsg_success_ethToLineaWeEth() external {
        _selectEthFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();
        _configureWeEthExecutor(WEETH_ETH, WEETH_ADAPTER_ETH);

        DummyMarket market = new DummyMarket(WEETH_ETH);

        uint256 amount = DEFAULT_SEND_AMOUNT;
        _fundErc20FromHolder(WEETH_ETH, WEETH_ETH_HOLDER, address(this), amount);
        IERC20(WEETH_ETH).approve(address(bridge), amount);

        bytes memory options = _defaultOptions();
        bytes memory message = abi.encode(address(market), amount, amount, options);
        bytes memory extraData = abi.encode(address(this));

        uint256 fee = bridge.getFee(LINEA_LZ_ID, message, extraData);
        _selfFundEth(ETH_WETH, fee);

        uint256 balanceBefore = IERC20(WEETH_ETH).balanceOf(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, false, address(bridge));
        emit LZUnifiedBridge.MsgSent(LINEA_LZ_ID, address(market), 0, 0, bytes32(0));
        vm.recordLogs();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg{value: fee}(amount, address(market), LINEA_LZ_ID, WEETH_ETH, message, extraData);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 balanceAfter = IERC20(WEETH_ETH).balanceOf(address(this));
        assertEq(balanceAfter, balanceBefore - amount, "rebalancer weETH(Mainnet) balance did not decrease by amount");

        (uint32 dstEid, address loggedMarket, uint256 amountLD, uint256 minAmountLD, bytes32 guid) = _findMsgSent();
        assertEq(uint256(dstEid), uint256(LINEA_LZ_ID), "dstChainId is not LINEA_LZ_ID");
        assertEq(loggedMarket, address(market), "market in MsgSent is not the expected market");
        assertEq(amountLD, amount, "amountLD in MsgSent is not amount");
        assertEq(minAmountLD, amount, "minAmountLD in MsgSent is not amount");
        assertTrue(guid != bytes32(0), "MsgSent guid is zero");
    }

    function test_fork_sendMsg_revertsWith_LZBridge_ChainNotRegistered() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();
        _configureWeEthExecutor(WEETH_LINEA, address(0));

        DummyMarket market = new DummyMarket(WEETH_LINEA);
        bytes memory message = abi.encode(address(market), _SMALL_AMOUNT, _SMALL_AMOUNT, bytes(""));
        bytes memory extraData = abi.encode(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_ChainNotRegistered.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(_SMALL_AMOUNT, address(market), 0, WEETH_LINEA, message, extraData);
    }

    function test_fork_sendMsg_revertsWith_LZBridge_DestinationMismatch() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();
        _configureWeEthExecutor(WEETH_LINEA, address(0));

        DummyMarket market = new DummyMarket(WEETH_LINEA);
        bytes memory message = abi.encode(users.alice, _SMALL_AMOUNT, _SMALL_AMOUNT, bytes(""));
        bytes memory extraData = abi.encode(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_DestinationMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(_SMALL_AMOUNT, address(market), BASE_LZ_ID, WEETH_LINEA, message, extraData);
    }

    function test_fork_sendMsg_revertsWith_LZBridge_TokenMismatch() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();
        _configureWeEthExecutor(WEETH_LINEA, address(0));

        DummyMarket market = new DummyMarket(WEETH_LINEA);
        bytes memory message = abi.encode(address(market), _SMALL_AMOUNT, _SMALL_AMOUNT, bytes(""));
        bytes memory extraData = abi.encode(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_TokenMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(_SMALL_AMOUNT, address(market), BASE_LZ_ID, WEETH_BASE, message, extraData);
    }

    function test_fork_sendMsg_revertsWith_LZBridge_ExecutorNotSet() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();

        DummyMarket market = new DummyMarket(WEETH_LINEA);
        bytes memory message = abi.encode(address(market), _SMALL_AMOUNT, _SMALL_AMOUNT, bytes(""));
        bytes memory extraData = abi.encode(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_ExecutorNotSet.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(_SMALL_AMOUNT, address(market), BASE_LZ_ID, WEETH_LINEA, message, extraData);
    }

    function test_fork_sendMsg_revertsWith_LZBridge_NotEnoughFees() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();
        _configureWeEthExecutor(WEETH_LINEA, address(0));

        DummyMarket market = new DummyMarket(WEETH_LINEA);
        bytes memory message = abi.encode(address(market), _MIN_OFT_AMOUNT, _MIN_OFT_AMOUNT, _defaultOptions());
        bytes memory extraData = abi.encode(address(this));

        uint256 fee = bridge.getFee(BASE_LZ_ID, message, extraData);
        _selfFundEth(LINEA_WETH, fee);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_NotEnoughFees.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg{value: fee - 1}(_MIN_OFT_AMOUNT, address(market), BASE_LZ_ID, WEETH_LINEA, message, extraData);
    }

    function test_fork_sendMsg_revertsWith_BaseBridge_AmountMismatch() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();
        _configureWeEthExecutor(WEETH_LINEA, address(0));

        DummyMarket market = new DummyMarket(WEETH_LINEA);
        bytes memory message = abi.encode(address(market), _MIN_OFT_AMOUNT, _MIN_OFT_AMOUNT, _defaultOptions());
        bytes memory extraData = abi.encode(address(this));

        uint256 fee = bridge.getFee(BASE_LZ_ID, message, extraData);
        _selfFundEth(LINEA_WETH, fee);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_AmountMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg{value: fee}(_MIN_OFT_AMOUNT + 1, address(market), BASE_LZ_ID, WEETH_LINEA, message, extraData);
    }

    function test_fork_sendMsg_revertsWith_LZBridge_RefunderNotValid() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();
        _configureWeEthExecutor(WEETH_LINEA, address(0));

        DummyMarket market = new DummyMarket(WEETH_LINEA);
        bytes memory message = abi.encode(address(market), _MIN_OFT_AMOUNT, _MIN_OFT_AMOUNT, _defaultOptions());
        bytes memory extraData = abi.encode(address(0));

        uint256 fee = bridge.getFee(BASE_LZ_ID, message, extraData);
        _selfFundEth(LINEA_WETH, fee);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_RefunderNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg{value: fee}(_MIN_OFT_AMOUNT, address(market), BASE_LZ_ID, WEETH_LINEA, message, extraData);
    }

    function test_fork_sendMsg_revertsWith_LZBridge_ExecutorNoCode() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();
        _configureWeEthExecutor(WEETH_LINEA, address(0));

        DummyMarket market = new DummyMarket(WEETH_LINEA);
        bytes memory message = abi.encode(address(market), _MIN_OFT_AMOUNT, _MIN_OFT_AMOUNT, _defaultOptions());
        bytes memory extraData = abi.encode(address(this));

        uint256 fee = bridge.getFee(BASE_LZ_ID, message, extraData);
        _selfFundEth(LINEA_WETH, fee);

        bridge.setOftExecutorContract(WEETH_LINEA, _NON_ZERO_ADDRESS);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_ExecutorNoCode.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg{value: fee}(_MIN_OFT_AMOUNT, address(market), BASE_LZ_ID, WEETH_LINEA, message, extraData);
    }

    function test_fork_sendMsg_revertsWith_ExecutorRevert() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();
        _configureWeEthExecutor(WEETH_LINEA, address(0));

        DummyMarket market = new DummyMarket(WEETH_LINEA);
        bytes memory message = abi.encode(address(market), _MIN_OFT_AMOUNT, _MIN_OFT_AMOUNT, _defaultOptions());
        bytes memory extraData = abi.encode(address(this));

        uint256 fee = bridge.getFee(BASE_LZ_ID, message, extraData);
        _selfFundEth(LINEA_WETH, fee);

        bridge.setOftExecutorContract(WEETH_LINEA, address(new RevertingExecutor()));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(RevertingExecutor.ExecutorRevert.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg{value: fee}(_MIN_OFT_AMOUNT, address(market), BASE_LZ_ID, WEETH_LINEA, message, extraData);
    }

    function test_fork_sendMsg_revertsWith_LZBridge_DestinationMismatch_withMultipleInputs() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();
        _configureWeEthExecutor(WEETH_LINEA, address(0));

        DummyMarket market = new DummyMarket(WEETH_LINEA);
        bytes memory message = abi.encode(address(market), _SMALL_AMOUNT, _SMALL_AMOUNT, bytes(""));
        bytes memory extraData = abi.encode(address(this));

        address[3] memory wrongMarkets = [users.alice, users.bob, _BOGUS_ADDRESS];
        uint256 revertedCalls;

        // ~~~~~~~~~~ Expectations / Call ~~~~~~~~~~
        for (uint256 i; i < wrongMarkets.length; ++i) {
            vm.expectRevert(LZUnifiedBridge.LZBridge_DestinationMismatch.selector);
            bridge.sendMsg(_SMALL_AMOUNT, wrongMarkets[i], BASE_LZ_ID, WEETH_LINEA, message, extraData);
            ++revertedCalls;
        }

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(revertedCalls, wrongMarkets.length, "not all destination-mismatch inputs reverted");
    }

    function test_fork_sendMsg_revertsWith_LZBridge_TokenMismatch_withMultipleInputs() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();
        _configureWeEthExecutor(WEETH_LINEA, address(0));

        DummyMarket market = new DummyMarket(WEETH_LINEA);
        bytes memory message = abi.encode(address(market), _SMALL_AMOUNT, _SMALL_AMOUNT, bytes(""));
        bytes memory extraData = abi.encode(address(this));

        address[3] memory wrongTokens = [users.alice, users.bob, WEETH_BASE];
        uint256 revertedCalls;

        // ~~~~~~~~~~ Expectations / Call ~~~~~~~~~~
        for (uint256 i; i < wrongTokens.length; ++i) {
            vm.expectRevert(LZUnifiedBridge.LZBridge_TokenMismatch.selector);
            bridge.sendMsg(_SMALL_AMOUNT, address(market), BASE_LZ_ID, wrongTokens[i], message, extraData);
            ++revertedCalls;
        }

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(revertedCalls, wrongTokens.length, "not all token-mismatch inputs reverted");
    }

    ////////////////////////////////////////////////////////////
    //                    Config / Fees                       //
    ////////////////////////////////////////////////////////////

    function test_fork_setBridgeContract_success_emitsEvent() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(bridge));
        emit LZUnifiedBridge.BridgeContractSet(WEETH_LINEA, WEETH_ADAPTER_ETH);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.setBridgeContract(WEETH_LINEA, WEETH_ADAPTER_ETH);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(bridge.bridgeContracts(WEETH_LINEA), WEETH_ADAPTER_ETH, "bridge contract not set");
    }

    function test_fork_setBridgeContract_revertsWith_BaseBridge_NotAuthorized() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.prank(users.alice);
        vm.expectRevert(BaseBridge.BaseBridge_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.setBridgeContract(WEETH_LINEA, WEETH_ADAPTER_ETH);
    }

    function test_fork_setOftExecutorContract_success_emitsEvent() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(bridge));
        emit LZUnifiedBridge.OftExecutorSet(WEETH_LINEA, address(executor));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.setOftExecutorContract(WEETH_LINEA, address(executor));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(bridge.oftExecutors(WEETH_LINEA), address(executor), "executor not set");
    }

    function test_fork_setOftExecutorContract_revertsWith_BaseBridge_NotAuthorized() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.prank(users.alice);
        vm.expectRevert(BaseBridge.BaseBridge_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.setOftExecutorContract(WEETH_LINEA, address(executor));
    }

    function test_fork_getFee_revertsWith_LZBridge_ChainNotRegistered() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();

        DummyMarket market = new DummyMarket(WEETH_LINEA);
        bytes memory message = abi.encode(address(market), _SMALL_AMOUNT, _SMALL_AMOUNT, bytes(""));
        bytes memory extraData = abi.encode(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_ChainNotRegistered.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.getFee(0, message, extraData);
    }

    ////////////////////////////////////////////////////////////
    //                      lzCompose                         //
    ////////////////////////////////////////////////////////////

    function test_fork_lzCompose_revertsWith_LZBridge_OnlyEndpoint() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();
        _configureWeEthExecutor(WEETH_LINEA, address(0));

        DummyMarket market = new DummyMarket(WEETH_LINEA);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_OnlyEndpoint.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.lzCompose(WEETH_LINEA, bytes32(0), abi.encode(address(market)), address(0), bytes(""));
    }

    function test_fork_lzCompose_revertsWith_LZBridge_BadFrom() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();
        _configureWeEthExecutor(WEETH_LINEA, address(0));

        DummyMarket market = new DummyMarket(WEETH_LINEA);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.prank(_NON_ZERO_ADDRESS);
        vm.expectRevert(LZUnifiedBridge.LZBridge_BadFrom.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.lzCompose(_BOGUS_ADDRESS, bytes32(0), abi.encode(address(market)), address(0), bytes(""));
    }

    function test_fork_lzCompose_revertsWith_LZBridge_ExecutorNotSet() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();

        DummyMarket market = new DummyMarket(WEETH_LINEA);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.prank(_NON_ZERO_ADDRESS);
        vm.expectRevert(LZUnifiedBridge.LZBridge_ExecutorNotSet.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.lzCompose(WEETH_LINEA, bytes32(0), abi.encode(address(market)), address(0), bytes(""));
    }

    function test_fork_lzCompose_revertsWith_ExecutorRevert() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();
        bridge.setOftExecutorContract(WEETH_LINEA, address(new ComposeRevertingExecutor()));

        DummyMarket market = new DummyMarket(WEETH_LINEA);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.prank(_NON_ZERO_ADDRESS);
        vm.expectRevert(ComposeRevertingExecutor.ComposeRevert.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.lzCompose(WEETH_LINEA, bytes32(0), abi.encode(address(market)), address(0), bytes(""));
    }

    function test_fork_lzCompose_success() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();
        _configureWeEthExecutor(WEETH_LINEA, address(0));

        DummyMarket market = new DummyMarket(WEETH_LINEA);
        address executorBefore = bridge.oftExecutors(WEETH_LINEA);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true, address(bridge));
        emit LZSendExecutor.ComposeExecuted(address(market), WEETH_LINEA, WEETH_LINEA);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(_NON_ZERO_ADDRESS);
        bridge.lzCompose(WEETH_LINEA, bytes32(0), abi.encode(address(market)), address(0), bytes(""));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(bridge.oftExecutors(WEETH_LINEA), executorBefore, "executor changed after lzCompose");
    }

    ////////////////////////////////////////////////////////////
    //                ProcessUncomposedMessages               //
    ////////////////////////////////////////////////////////////

    function test_fork_processUncomposedMessages_revertsWith_BaseBridge_NotAuthorized() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();
        _configureWeEthExecutor(WEETH_LINEA, address(0));

        DummyMarket market = new DummyMarket(WEETH_LINEA);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.prank(users.alice);
        vm.expectRevert(BaseBridge.BaseBridge_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.processUncomposedMessages(address(market));
    }

    function test_fork_processUncomposedMessages_revertsWith_LZBridge_ExecutorNotSet() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();

        DummyMarket market = new DummyMarket(WEETH_LINEA);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_ExecutorNotSet.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.processUncomposedMessages(address(market));
    }

    function test_fork_processUncomposedMessages_revertsWith_ExecutorRevert() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();
        bridge.setOftExecutorContract(WEETH_LINEA, address(new ProcessRevertingExecutor()));

        DummyMarket market = new DummyMarket(WEETH_LINEA);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ProcessRevertingExecutor.ProcessRevert.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.processUncomposedMessages(address(market));
    }

    function test_fork_processUncomposedMessages_success() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _deployBridge();
        _configureWeEthExecutor(WEETH_LINEA, address(0));

        DummyMarket market = new DummyMarket(WEETH_LINEA);
        address executorBefore = bridge.oftExecutors(WEETH_LINEA);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true, address(bridge));
        emit LZSendExecutor.UncomposedProcessed(address(market), WEETH_LINEA, WEETH_LINEA);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.processUncomposedMessages(address(market));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            bridge.oftExecutors(WEETH_LINEA), executorBefore, "executor changed after processing uncomposed messages"
        );
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _deployBridge() internal {
        roles = new Roles(address(this));
        roles.allowFor(address(this), roles.REBALANCER(), true);
        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), true);

        // `ENDPOINT` is only used by lzCompose, not by sendMsg. It must be non-zero.
        bridge = new LZUnifiedBridge(address(roles), _NON_ZERO_ADDRESS);

        executor = new LZSendExecutor();
    }

    function _configureWeEthExecutor(address underlying, address bridgeContract) internal {
        if (bridgeContract != address(0)) {
            bridge.setBridgeContract(underlying, bridgeContract);
        }
        bridge.setOftExecutorContract(underlying, address(executor));
    }

    function _defaultOptions() internal pure returns (bytes memory options) {
        options = LZOptions.newOptions();
        options = LZOptions.addExecutorLzReceiveOption(options, 200_000, 0);
        options = LZOptions.addExecutorLzComposeOption(options, 0, 400_000, 0);
    }

    function _findMsgSent()
        internal
        view
        returns (uint32 dstEid, address market, uint256 amountLD, uint256 minAmountLD, bytes32 guid)
    {
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 sig = LZUnifiedBridge.MsgSent.selector;

        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory e = entries[i];
            if (e.emitter != address(bridge)) continue;
            if (e.topics.length == 0 || e.topics[0] != sig) continue;

            dstEid = uint32(uint256(e.topics[1]));
            market = address(uint160(uint256(e.topics[2])));
            (amountLD, minAmountLD, guid) = abi.decode(e.data, (uint256, uint256, bytes32));
            return (dstEid, market, amountLD, minAmountLD, guid);
        }

        revert("MsgSent event not found");
    }
}
