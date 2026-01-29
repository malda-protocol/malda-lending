// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {BaseOftMessageExecutor} from "src/rebalancer/bridges/helpers/BaseOftMessageExecutor.sol";
import {rsEthOftMessageExecutor} from "src/rebalancer/bridges/helpers/rsEthOftMessageExecutor.sol";
import {weEthOftMessageExecutor} from "src/rebalancer/bridges/helpers/weEthOftMessageExecutor.sol";

import {
    SendParam,
    MessagingFee,
    ILayerZeroOFT,
    ILayerZeroOFTWrapper,
    OFTLimit,
    OFTReceipt,
    OFTFeeDetail
} from "src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol";
import {MessagingReceipt} from "src/interfaces/external/layerzero/v2/ILayerZeroEndpointV2.sol";

contract TestToken is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}

contract MockOFTToken is ERC20, ILayerZeroOFT {
    MessagingFee public lastFee;
    SendParam public lastParams;
    address public lastRefund;
    address public innerToken;

    constructor(string memory name_, string memory symbol_, address innerToken_) ERC20(name_, symbol_) {
        innerToken = innerToken_;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function oftVersion() external pure returns (bytes4 interfaceId, uint64 version) {
        return (bytes4(0), 0);
    }

    function token() external view returns (address) {
        return innerToken;
    }

    function approvalRequired() external pure returns (bool) {
        return false;
    }

    function sharedDecimals() external pure returns (uint8) {
        return 18;
    }

    function quoteOFT(SendParam calldata)
        external
        pure
        returns (OFTLimit memory, OFTFeeDetail[] memory, OFTReceipt memory)
    {
        return (OFTLimit({minAmountLD: 0, maxAmountLD: 0}), new OFTFeeDetail[](0), OFTReceipt(0, 0));
    }

    function quoteSend(SendParam calldata, bool) external pure returns (MessagingFee memory) {
        return MessagingFee({nativeFee: 0, lzTokenFee: 0});
    }

    function send(SendParam calldata _sendParam, MessagingFee calldata _fee, address _refundAddress)
        external
        payable
        returns (MessagingReceipt memory receipt, OFTReceipt memory oftReceipt)
    {
        lastParams = _sendParam;
        lastFee = _fee;
        lastRefund = _refundAddress;
        receipt = MessagingReceipt({guid: bytes32("guid"), nonce: 1, fee: _fee});
        oftReceipt = OFTReceipt({amountSentLD: _sendParam.amountLD, amountReceivedLD: _sendParam.amountLD});
    }
}

contract MockWrapperToken is TestToken, ILayerZeroOFTWrapper {
    mapping(address token => bool allowed) public allowed;
    bool public mintOnWithdraw = true;

    constructor(string memory name_, string memory symbol_) TestToken(name_, symbol_) {}

    function setAllowed(address token, bool ok) external {
        allowed[token] = ok;
    }

    function setMintOnWithdraw(bool ok) external {
        mintOnWithdraw = ok;
    }

    function allowedTokens(address token) external view virtual returns (bool) {
        return allowed[token];
    }

    function deposit(address asset, uint256 _amount) external {
        ERC20(asset).transferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, _amount);
    }

    function withdraw(address asset, uint256 _amount) external {
        _burn(msg.sender, _amount);
        if (mintOnWithdraw) {
            MockOFTToken(asset).mint(msg.sender, _amount);
        }
    }
}

contract RevertingWrapperToken is MockWrapperToken {
    constructor() MockWrapperToken("RevertWrapper", "RW") {}

    function allowedTokens(address) external pure override returns (bool) {
        revert("no-oft");
    }
}

contract RevertingOFTToken {
    function token() external pure returns (address) {
        revert("no-oft");
    }
}

contract BaseOftExecutorHarness is BaseOftMessageExecutor {
    function executeSend(address, address, SendParam calldata, MessagingFee calldata, address, address)
        external
        payable
        override
        returns (MessagingReceipt memory)
    {
        revert("not implemented");
    }

    function pullFromRebalancer(address underlying, uint256 amount, address rebalancer) external {
        _pullFromRebalancer(underlying, amount, rebalancer);
    }

    function approveToken(address token, address spender, uint256 amount) external {
        _approve(token, spender, amount);
    }

    function sendOFT(address oft, SendParam calldata params, MessagingFee calldata fees, address refundAddress)
        external
        payable
        returns (MessagingReceipt memory)
    {
        return _sendOFT(oft, params, fees, refundAddress);
    }

    function fallbackToUnderlying(address market, address underlying, address bridgeContract) external {
        _fallbackToUnderlying(market, underlying, bridgeContract);
    }

    function verifyMinted(address oft, uint256 required) external view {
        _verifyMinted(oft, required);
    }
}

contract BaseOftMessageExecutorTest is Test {
    BaseOftExecutorHarness internal harness;

    function setUp() public {
        harness = new BaseOftExecutorHarness();
    }

    function test_pullFromRebalancer_transfers() external {
        TestToken underlying = new TestToken("U", "U");
        address rebalancer = address(0xBEEF);
        underlying.mint(rebalancer, 1e18);

        vm.prank(rebalancer);
        underlying.approve(address(harness), 1e18);

        harness.pullFromRebalancer(address(underlying), 1e18, rebalancer);
        assertEq(underlying.balanceOf(address(harness)), 1e18);
    }

    function test_pullFromRebalancer_revertWhenSenderIsRebalancer() external {
        TestToken underlying = new TestToken("U", "U");
        vm.expectRevert(BaseOftMessageExecutor.Executor_NotRebalancer.selector);
        harness.pullFromRebalancer(address(underlying), 1e18, address(this));
    }

    function test_fallbackToUnderlying_transfersWhenUnderlyingBridge() external {
        TestToken underlying = new TestToken("U", "U");
        address market = address(0xCAFE);

        underlying.mint(address(harness), 2e18);
        harness.fallbackToUnderlying(market, address(underlying), address(underlying));

        assertEq(underlying.balanceOf(market), 2e18);
    }

    function test_fallbackToUnderlying_returnsWhenNoOftBalance() external {
        TestToken underlying = new TestToken("U", "U");
        TestToken oft = new TestToken("OFT", "OFT");
        address market = address(0xCAFE);

        harness.fallbackToUnderlying(market, address(underlying), address(oft));
        assertEq(underlying.balanceOf(market), 0);
    }

    function test_fallbackToUnderlying_depositsAndTransfers() external {
        MockWrapperToken underlying = new MockWrapperToken("U", "U");
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(underlying));
        address market = address(0xCAFE);

        oft.mint(address(harness), 3e18);
        harness.fallbackToUnderlying(market, address(underlying), address(oft));

        assertEq(underlying.balanceOf(market), 3e18);
    }

    function test_verifyMinted_revertWhenInsufficient() external {
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(0));
        vm.expectRevert(BaseOftMessageExecutor.Executor_AmountMismatch.selector);
        harness.verifyMinted(address(oft), 1);
    }

    function test_verifyMinted_ok() external {
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(0));
        oft.mint(address(harness), 1);
        harness.verifyMinted(address(oft), 1);
    }

    function test_sendOFT_callsSend() external {
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(0));
        SendParam memory params = SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(address(0xBEEF)))),
            amountLD: 1,
            minAmountLD: 1,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        harness.sendOFT(address(oft), params, fees, address(0xCAFE));
        assertEq(oft.lastRefund(), address(0xCAFE));
    }

    function test_processUncomposed_transfersUnderlying() external {
        TestToken underlying = new TestToken("U", "U");
        address market = address(0xCAFE);

        underlying.mint(address(harness), 1e18);
        harness.processUncomposed(market, address(underlying), address(underlying));

        assertEq(underlying.balanceOf(market), 1e18);
    }

    function test_executeCompose_transfersUnderlying() external {
        TestToken underlying = new TestToken("U", "U");
        address market = address(0xCAFE);

        underlying.mint(address(harness), 1e18);
        harness.executeCompose(market, address(underlying), address(underlying));

        assertEq(underlying.balanceOf(market), 1e18);
    }
}

contract rsEthOftMessageExecutorTest is Test {
    rsEthOftMessageExecutor internal executor;

    function setUp() public {
        executor = new rsEthOftMessageExecutor();
    }

    function test_executeSend_successWithWrapper() external {
        MockWrapperToken underlying = new MockWrapperToken("U", "U");
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(underlying));
        underlying.setAllowed(address(oft), true);

        address rebalancer = address(0xBEEF);
        underlying.mint(rebalancer, 2e18);
        vm.prank(rebalancer);
        underlying.approve(address(executor), 2e18);

        SendParam memory params = SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(address(0xCAFE)))),
            amountLD: 2e18,
            minAmountLD: 2e18,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        executor.executeSend(address(underlying), address(oft), params, fees, rebalancer, address(0xCAFE));
        assertEq(oft.balanceOf(address(executor)), 2e18);
    }

    function test_executeSend_revertWhenInnerTokenNotAllowed() external {
        MockWrapperToken underlying = new MockWrapperToken("U", "U");
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(underlying));

        address rebalancer = address(0xBEEF);
        underlying.mint(rebalancer, 1e18);
        vm.prank(rebalancer);
        underlying.approve(address(executor), 1e18);

        SendParam memory params = SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(address(0xCAFE)))),
            amountLD: 1e18,
            minAmountLD: 1e18,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        vm.expectRevert(rsEthOftMessageExecutor.Executor_DifferentInnerToken.selector);
        executor.executeSend(address(underlying), address(oft), params, fees, rebalancer, address(0xCAFE));
    }

    function test_executeSend_revertWhenNoOft() external {
        RevertingWrapperToken underlying = new RevertingWrapperToken();
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(underlying));

        address rebalancer = address(0xBEEF);
        underlying.mint(rebalancer, 1e18);
        vm.prank(rebalancer);
        underlying.approve(address(executor), 1e18);

        SendParam memory params = SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(address(0xCAFE)))),
            amountLD: 1e18,
            minAmountLD: 1e18,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        vm.expectRevert(BaseOftMessageExecutor.Executor_NoOft.selector);
        executor.executeSend(address(underlying), address(oft), params, fees, rebalancer, address(0xCAFE));
    }

    function test_executeSend_revertWhenMintedMismatch() external {
        MockWrapperToken underlying = new MockWrapperToken("U", "U");
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(underlying));
        underlying.setAllowed(address(oft), true);
        underlying.setMintOnWithdraw(false);

        address rebalancer = address(0xBEEF);
        underlying.mint(rebalancer, 1e18);
        vm.prank(rebalancer);
        underlying.approve(address(executor), 1e18);

        SendParam memory params = SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(address(0xCAFE)))),
            amountLD: 1e18,
            minAmountLD: 1e18,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        vm.expectRevert(BaseOftMessageExecutor.Executor_AmountMismatch.selector);
        executor.executeSend(address(underlying), address(oft), params, fees, rebalancer, address(0xCAFE));
    }

    function test_executeSend_successWhenBridgeIsUnderlying() external {
        MockOFTToken underlying = new MockOFTToken("OFT", "OFT", address(0));

        address rebalancer = address(0xBEEF);
        underlying.mint(rebalancer, 1e18);
        vm.prank(rebalancer);
        underlying.approve(address(executor), 1e18);

        SendParam memory params = SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(address(0xCAFE)))),
            amountLD: 1e18,
            minAmountLD: 1e18,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        executor.executeSend(address(underlying), address(underlying), params, fees, rebalancer, address(0xCAFE));
    }
}

contract weEthOftMessageExecutorTest is Test {
    weEthOftMessageExecutor internal executor;

    function setUp() public {
        executor = new weEthOftMessageExecutor();
    }

    function test_executeSend_success() external {
        TestToken underlying = new TestToken("U", "U");
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(underlying));

        address rebalancer = address(0xBEEF);
        underlying.mint(rebalancer, 1e18);
        vm.prank(rebalancer);
        underlying.approve(address(executor), 1e18);

        SendParam memory params = SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(address(0xCAFE)))),
            amountLD: 1e18,
            minAmountLD: 1e18,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        executor.executeSend(address(underlying), address(oft), params, fees, rebalancer, address(0xCAFE));
    }

    function test_executeSend_revertWhenInnerTokenMismatch() external {
        TestToken underlying = new TestToken("U", "U");
        TestToken other = new TestToken("X", "X");
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(other));

        address rebalancer = address(0xBEEF);
        underlying.mint(rebalancer, 1e18);
        vm.prank(rebalancer);
        underlying.approve(address(executor), 1e18);

        SendParam memory params = SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(address(0xCAFE)))),
            amountLD: 1e18,
            minAmountLD: 1e18,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        vm.expectRevert(weEthOftMessageExecutor.Executor_DifferentInnerToken.selector);
        executor.executeSend(address(underlying), address(oft), params, fees, rebalancer, address(0xCAFE));
    }

    function test_executeSend_revertWhenNoOft() external {
        TestToken underlying = new TestToken("U", "U");
        RevertingOFTToken bad = new RevertingOFTToken();

        address rebalancer = address(0xBEEF);
        underlying.mint(rebalancer, 1e18);
        vm.prank(rebalancer);
        underlying.approve(address(executor), 1e18);

        SendParam memory params = SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(address(0xCAFE)))),
            amountLD: 1e18,
            minAmountLD: 1e18,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        vm.expectRevert(BaseOftMessageExecutor.Executor_NoOft.selector);
        executor.executeSend(address(underlying), address(bad), params, fees, rebalancer, address(0xCAFE));
    }
}
