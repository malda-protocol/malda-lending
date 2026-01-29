// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

import {EverclearBridgeV2} from "src/rebalancer/bridges/EverclearBridgeV2.sol";
import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";
import {IFeeAdapterV2} from "src/interfaces/external/everclear/IFeeAdapterV2.sol";
import {Roles} from "src/Roles.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {EverclearFeeAdapterV2Mock} from "test/mocks/EverclearFeeAdapterMock.sol";

contract EverclearBridgeV2Test is BaseTest {
    event MsgSent(uint256 indexed dstChainId, address indexed market, uint256 amountLD, bytes32 id);
    event RebalancingReturnedToMarket(address indexed market, uint256 toReturn, uint256 extracted);
    event EverclearFeeAdapterUpdated(address indexed oldAdapter, address indexed newAdapter);

    Roles internal roles;
    ERC20Mock internal token;
    EverclearFeeAdapterV2Mock internal feeAdapter;
    EverclearBridgeV2 internal bridge;

    address internal rebalancer;
    address internal guardian;
    address internal market;

    function setUp() public override {
        super.setUp();
        roles = new Roles(address(this));
        feeAdapter = new EverclearFeeAdapterV2Mock();
        bridge = new EverclearBridgeV2(address(roles), address(feeAdapter));
        token = new ERC20Mock("Mock Token", "MOCK", 18, address(this), address(0), type(uint256).max);

        rebalancer = users.alice;
        guardian = users.guardian;
        market = users.bob;

        roles.allowFor(rebalancer, roles.REBALANCER(), true);
        roles.allowFor(guardian, roles.GUARDIAN_BRIDGE(), true);
    }

    ////////////////////////////////////////////////////////////
    //                       Constructor                        //
    ////////////////////////////////////////////////////////////

    function test_unitConstructor_revertsWith_RevertWhenRolesZero() public {
        vm.expectRevert(BaseBridge.BaseBridge_AddressNotValid.selector);
        new EverclearBridgeV2(address(0), address(feeAdapter));
    }

    function test_unitConstructor_revertsWith_RevertWhenFeeAdapterZero() public {
        vm.expectRevert(EverclearBridgeV2.Everclear_AddressNotValid.selector);
        new EverclearBridgeV2(address(roles), address(0));
    }

    ////////////////////////////////////////////////////////////
    //                  SetEverclearFeeAdapter                  //
    ////////////////////////////////////////////////////////////

    function test_unitSetEverclearFeeAdapter_revertsWith_RevertWhenCallerNotGuardian() public {
        vm.expectRevert(BaseBridge.BaseBridge_NotAuthorized.selector);
        bridge.setEverclearFeeAdapter(users.carol);
    }

    function test_unitSetEverclearFeeAdapter_revertsWith_RevertWhenZeroAddress() public {
        vm.prank(guardian);
        vm.expectRevert(EverclearBridgeV2.Everclear_AddressNotValid.selector);
        bridge.setEverclearFeeAdapter(address(0));
    }

    function test_unitSetEverclearFeeAdapter_success_Updates() public {
        EverclearFeeAdapterV2Mock newAdapter = new EverclearFeeAdapterV2Mock();

        vm.prank(guardian);
        vm.expectEmit(true, true, false, true);
        emit EverclearFeeAdapterUpdated(address(feeAdapter), address(newAdapter));
        bridge.setEverclearFeeAdapter(address(newAdapter));

        assertEq(address(bridge.everclearFeeAdapter()), address(newAdapter));
    }

    ////////////////////////////////////////////////////////////
    //                          GetFee                          //
    ////////////////////////////////////////////////////////////

    function test_unitGetFee_revertsWith_Reverts() public {
        vm.expectRevert(EverclearBridgeV2.Everclear_NotImplemented.selector);
        bridge.getFee(0, "", "");
    }

    ////////////////////////////////////////////////////////////
    //                         SendMsg                          //
    ////////////////////////////////////////////////////////////

    function test_unitSendMsg_revertsWith_RevertWhenCallerNotRebalancer() public {
        IntentInput memory input = _defaultInput();
        input.amount = 1;
        input.amountOutMin = 1;
        input.feeParams = IFeeAdapterV2.FeeParams(0, 0, "");

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        vm.expectRevert(BaseBridge.BaseBridge_NotAuthorized.selector);
        bridge.sendMsg(input.amount, market, dstChainId, address(token), message, "");
    }

    function test_unitSendMsg_revertsWith_RevertWhenTokenMismatch() public {
        IntentInput memory input = _defaultInput();
        input.amount = 1;
        input.amountOutMin = 1;
        input.feeParams = IFeeAdapterV2.FeeParams(0, 0, "");

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        vm.prank(rebalancer);
        vm.expectRevert(EverclearBridgeV2.Everclear_TokenMismatch.selector);
        bridge.sendMsg(input.amount, market, dstChainId, users.carol, message, "");
    }

    function test_unitSendMsg_revertsWith_RevertWhenAmountMismatch() public {
        IntentInput memory input = _defaultInput();
        input.amount = 2;
        input.amountOutMin = 2;
        input.feeParams = IFeeAdapterV2.FeeParams(0, 0, "");

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        vm.prank(rebalancer);
        vm.expectRevert(BaseBridge.BaseBridge_AmountMismatch.selector);
        bridge.sendMsg(1, market, dstChainId, address(token), message, "");
    }

    function test_unitSendMsg_revertsWith_RevertWhenAmountIsZero() public {
        IntentInput memory input = _defaultInput();
        input.amount = 0;
        input.amountOutMin = 0;
        input.feeParams = IFeeAdapterV2.FeeParams(0, 0, "");

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        vm.prank(rebalancer);
        vm.expectRevert(BaseBridge.BaseBridge_AmountMismatch.selector);
        bridge.sendMsg(0, market, dstChainId, address(token), message, "");
    }

    function test_unitSendMsg_revertsWith_RevertWhenReceiverMismatch() public {
        IntentInput memory input = _defaultInput();
        input.receiver = users.carol;
        input.amount = 1;
        input.amountOutMin = 1;
        input.feeParams = IFeeAdapterV2.FeeParams(0, 0, "");

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        vm.prank(rebalancer);
        vm.expectRevert(BaseBridge.BaseBridge_AddressNotValid.selector);
        bridge.sendMsg(1, market, dstChainId, address(token), message, "");
    }

    function test_unitSendMsg_revertsWith_RevertWhenDestinationsLengthMismatch() public {
        IntentInput memory input = _defaultInput();
        input.amount = 1;
        input.amountOutMin = 1;
        input.feeParams = IFeeAdapterV2.FeeParams(0, 0, "");

        (bytes memory message, uint32 dstChainId) = _buildMessage(2, input);

        vm.prank(rebalancer);
        vm.expectRevert(EverclearBridgeV2.Everclear_DestinationsLengthMismatch.selector);
        bridge.sendMsg(1, market, dstChainId, address(token), message, "");
    }

    function test_unitSendMsg_revertsWith_RevertWhenDestinationMismatch() public {
        IntentInput memory input = _defaultInput();
        input.amount = 1;
        input.amountOutMin = 1;
        input.feeParams = IFeeAdapterV2.FeeParams(0, 0, "");

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        vm.prank(rebalancer);
        vm.expectRevert(EverclearBridgeV2.Everclear_DestinationNotValid.selector);
        bridge.sendMsg(1, market, dstChainId + 1, address(token), message, "");
    }

    function test_unitSendMsg_revertsWith_RevertWhenMaxSlippageExceeded(uint96 amountRaw, uint256 amountOutMinRaw)
        public
    {
        IntentInput memory input = _defaultInput();
        input.amount = bound(amountRaw, 10, 1e18);
        input.amountOutMin = bound(amountOutMinRaw, 0, input.amount * 9 / 10 - 1);
        input.feeParams = IFeeAdapterV2.FeeParams(0, 0, "");

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        vm.prank(rebalancer);
        vm.expectRevert(EverclearBridgeV2.Everclear_MaxSlippageExceeded.selector);
        bridge.sendMsg(input.amount, market, dstChainId, address(token), message, "");
    }

    function test_unitSendMsg_success_ReturnsExcess_fuzz(
        uint96 amountRaw,
        uint96 feeRaw,
        uint96 extraRaw,
        uint48 ttl,
        bytes memory data,
        bytes memory sig,
        uint256 deadline
    ) public {
        vm.assume(data.length <= 64);
        vm.assume(sig.length <= 64);

        IntentInput memory input = _defaultInput();
        input.amount = bound(amountRaw, 1, 1e18);
        input.amountOutMin = input.amount;
        input.ttl = ttl;
        input.data = data;
        input.feeParams = IFeeAdapterV2.FeeParams(bound(feeRaw, 0, input.amount / 2), deadline, sig);
        uint256 extra = bound(extraRaw, 1, 1e18);

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        uint256 extractedAmount = input.amount + input.feeParams.fee + extra;

        token.mint(rebalancer, extractedAmount);
        vm.startPrank(rebalancer);
        token.approve(address(bridge), extractedAmount);

        vm.expectEmit(true, true, false, true);
        emit RebalancingReturnedToMarket(market, extra, extractedAmount);
        vm.expectEmit(true, true, false, true);
        emit MsgSent(dstChainId, market, input.amount, feeAdapter.nextId());

        bridge.sendMsg(extractedAmount, market, dstChainId, address(token), message, "");
        vm.stopPrank();

        assertEq(token.balanceOf(market), extra);
        assertEq(token.balanceOf(address(bridge)), input.amount + input.feeParams.fee);
        assertEq(token.allowance(address(bridge), address(feeAdapter)), input.amount + input.feeParams.fee);
        assertEq(feeAdapter.callCount(), 1);
        assertEq(feeAdapter.lastDestinations(0), dstChainId);
        assertEq(feeAdapter.lastAmount(), input.amount);
        assertEq(feeAdapter.lastAmountOutMin(), input.amountOutMin);

        (uint256 storedFee, uint256 storedDeadline, bytes memory storedSig) = feeAdapter.lastFeeParams();
        assertEq(storedFee, input.feeParams.fee);
        assertEq(storedDeadline, input.feeParams.deadline);
        assertEq(keccak256(storedSig), keccak256(input.feeParams.sig));
    }

    function test_unitSendMsg_success_NoExcess_fuzz(
        uint96 amountRaw,
        uint96 feeRaw,
        uint48 ttl,
        bytes memory data,
        bytes memory sig,
        uint256 deadline
    ) public {
        vm.assume(data.length <= 64);
        vm.assume(sig.length <= 64);

        IntentInput memory input = _defaultInput();
        input.amount = bound(amountRaw, 1, 1e18);
        input.amountOutMin = input.amount * 9 / 10;
        input.ttl = ttl;
        input.data = data;
        input.feeParams = IFeeAdapterV2.FeeParams(bound(feeRaw, 0, input.amount / 2), deadline, sig);

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        uint256 extractedAmount = input.amount + input.feeParams.fee;

        token.mint(rebalancer, extractedAmount);
        vm.startPrank(rebalancer);
        token.approve(address(bridge), extractedAmount);

        vm.expectEmit(true, true, false, true);
        emit MsgSent(dstChainId, market, input.amount, feeAdapter.nextId());

        bridge.sendMsg(extractedAmount, market, dstChainId, address(token), message, "");
        vm.stopPrank();

        assertEq(token.balanceOf(market), 0);
        assertEq(token.balanceOf(address(bridge)), input.amount + input.feeParams.fee);
        assertEq(token.allowance(address(bridge), address(feeAdapter)), input.amount + input.feeParams.fee);
        assertEq(feeAdapter.callCount(), 1);
        assertEq(feeAdapter.lastDestinations(0), dstChainId);
    }

    struct IntentInput {
        uint32 dstChainId;
        address receiver;
        address inputAsset;
        bytes32 outputAsset;
        uint256 amount;
        uint256 amountOutMin;
        uint48 ttl;
        bytes data;
        IFeeAdapterV2.FeeParams feeParams;
    }

    function _defaultInput() internal view returns (IntentInput memory input) {
        input.dstChainId = 123;
        input.receiver = market;
        input.inputAsset = address(token);
        input.outputAsset = bytes32(uint256(1));
    }

    function _buildMessage(uint32 destinationsLength, IntentInput memory input)
        internal
        pure
        returns (bytes memory message, uint32 dstChainIdOut)
    {
        uint32[] memory destinations = new uint32[](destinationsLength);
        if (destinationsLength > 0) {
            destinations[0] = input.dstChainId;
        }
        if (destinationsLength > 1) {
            destinations[1] = input.dstChainId + 1;
        }

        bytes32 receiverBytes = bytes32(uint256(uint160(input.receiver)));
        message = abi.encodeWithSelector(
            IFeeAdapterV2.newIntent.selector,
            destinations,
            receiverBytes,
            input.inputAsset,
            input.outputAsset,
            input.amount,
            input.amountOutMin,
            input.ttl,
            input.data,
            input.feeParams
        );
        dstChainIdOut = destinationsLength > 0 ? destinations[0] : 0;
    }
}
