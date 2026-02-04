// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";
import {EverclearBridgeV2} from "src/rebalancer/bridges/EverclearBridgeV2.sol";
import {IFeeAdapterV2} from "src/interfaces/external/everclear/IFeeAdapterV2.sol";
import {Roles} from "src/Roles.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {EverclearFeeAdapterV2Mock} from "test/mocks/EverclearFeeAdapterMock.sol";
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract EverclearBridgeV2Test is BaseTest {
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
    //                      constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_BaseBridge_AddressNotValid() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new EverclearBridgeV2(address(0), address(feeAdapter));
    }

    function test_unit_constructor_revertsWith_Everclear_AddressNotValid() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(EverclearBridgeV2.Everclear_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new EverclearBridgeV2(address(roles), address(0));
    }

    ////////////////////////////////////////////////////////////
    //                 setEverclearFeeAdapter                 //
    ////////////////////////////////////////////////////////////

    function test_unit_setEverclearFeeAdapter_revertsWith_BaseBridge_NotAuthorized() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.setEverclearFeeAdapter(users.carol);
    }

    function test_unit_setEverclearFeeAdapter_revertsWith_Everclear_AddressNotValid() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(EverclearBridgeV2.Everclear_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(guardian);
        bridge.setEverclearFeeAdapter(address(0));
    }

    function test_unit_setEverclearFeeAdapter_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        EverclearFeeAdapterV2Mock newAdapter = new EverclearFeeAdapterV2Mock();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit EverclearBridgeV2.EverclearFeeAdapterUpdated(address(feeAdapter), address(newAdapter));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(guardian);
        bridge.setEverclearFeeAdapter(address(newAdapter));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            address(bridge.everclearFeeAdapter()),
            address(newAdapter),
            "expected address(bridge.everclearFeeAdapter()) to equal address(newAdapter)"
        );
    }

    ////////////////////////////////////////////////////////////
    //                          getFee                        //
    ////////////////////////////////////////////////////////////

    function test_unit_getFee_revertsWith_Everclear_NotImplemented() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(EverclearBridgeV2.Everclear_NotImplemented.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.getFee(0, "", "");
    }

    ////////////////////////////////////////////////////////////
    //                          sendMsg                       //
    ////////////////////////////////////////////////////////////

    function test_unit_sendMsg_revertsWith_BaseBridge_NotAuthorized() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IntentInput memory input = _defaultInput();
        input.amount = 1;
        input.amountOutMin = 1;
        input.feeParams = IFeeAdapterV2.FeeParams(0, 0, "");

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(input.amount, market, dstChainId, address(token), message, "");
    }

    function test_unit_sendMsg_revertsWith_Everclear_TokenMismatch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IntentInput memory input = _defaultInput();
        input.amount = 1;
        input.amountOutMin = 1;
        input.feeParams = IFeeAdapterV2.FeeParams(0, 0, "");

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(EverclearBridgeV2.Everclear_TokenMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(rebalancer);
        bridge.sendMsg(input.amount, market, dstChainId, users.carol, message, "");
    }

    function test_unit_sendMsg_revertsWith_BaseBridge_AmountMismatch_whenExtractedLessThanAmount() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IntentInput memory input = _defaultInput();
        input.amount = 2;
        input.amountOutMin = 2;
        input.feeParams = IFeeAdapterV2.FeeParams(0, 0, "");

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_AmountMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(rebalancer);
        bridge.sendMsg(1, market, dstChainId, address(token), message, "");
    }

    function test_unit_sendMsg_revertsWith_BaseBridge_AmountMismatch_whenAmountZero() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IntentInput memory input = _defaultInput();
        input.amount = 0;
        input.amountOutMin = 0;
        input.feeParams = IFeeAdapterV2.FeeParams(0, 0, "");

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_AmountMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(rebalancer);
        bridge.sendMsg(0, market, dstChainId, address(token), message, "");
    }

    function test_unit_sendMsg_revertsWith_BaseBridge_AddressNotValid() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IntentInput memory input = _defaultInput();
        input.receiver = users.carol;
        input.amount = 1;
        input.amountOutMin = 1;
        input.feeParams = IFeeAdapterV2.FeeParams(0, 0, "");

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(rebalancer);
        bridge.sendMsg(1, market, dstChainId, address(token), message, "");
    }

    function test_unit_sendMsg_revertsWith_Everclear_DestinationsLengthMismatch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IntentInput memory input = _defaultInput();
        input.amount = 1;
        input.amountOutMin = 1;
        input.feeParams = IFeeAdapterV2.FeeParams(0, 0, "");

        (bytes memory message, uint32 dstChainId) = _buildMessage(2, input);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(EverclearBridgeV2.Everclear_DestinationsLengthMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(rebalancer);
        bridge.sendMsg(1, market, dstChainId, address(token), message, "");
    }

    function test_unit_sendMsg_revertsWith_Everclear_DestinationNotValid() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IntentInput memory input = _defaultInput();
        input.amount = 1;
        input.amountOutMin = 1;
        input.feeParams = IFeeAdapterV2.FeeParams(0, 0, "");

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(EverclearBridgeV2.Everclear_DestinationNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(rebalancer);
        bridge.sendMsg(1, market, dstChainId + 1, address(token), message, "");
    }

    function test_fuzz_sendMsg_revertsWith_Everclear_MaxSlippageExceeded(uint96 amountRaw, uint256 amountOutMinRaw)
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IntentInput memory input = _defaultInput();
        input.amount = bound(amountRaw, 10, 1e18);
        input.amountOutMin = bound(amountOutMinRaw, 0, input.amount * 9 / 10 - 1);
        input.feeParams = IFeeAdapterV2.FeeParams(0, 0, "");

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(EverclearBridgeV2.Everclear_MaxSlippageExceeded.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(rebalancer);
        bridge.sendMsg(input.amount, market, dstChainId, address(token), message, "");
    }

    ////////////////////////////////////////////////////////////
    //                         MsgSent                        //
    ////////////////////////////////////////////////////////////

    function test_fuzz_msgSent_success_returnsExcess(
        uint96 amountRaw,
        uint96 feeRaw,
        uint96 extraRaw,
        uint48 ttl,
        bytes calldata data,
        bytes calldata sig,
        uint256 deadline
    ) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 dataLength = bound(data.length, 0, 64);
        bytes memory boundedData = new bytes(dataLength);
        for (uint256 i; i < dataLength; ++i) {
            boundedData[i] = data[i];
        }

        uint256 sigLength = bound(sig.length, 0, 64);
        bytes memory boundedSig = new bytes(sigLength);
        for (uint256 i; i < sigLength; ++i) {
            boundedSig[i] = sig[i];
        }

        IntentInput memory input = _defaultInput();
        input.amount = bound(amountRaw, 1, 1e18);
        input.amountOutMin = input.amount;
        input.ttl = ttl;
        input.data = boundedData;
        input.feeParams = IFeeAdapterV2.FeeParams(bound(feeRaw, 0, input.amount / 2), deadline, boundedSig);
        uint256 extra = bound(extraRaw, 1, 1e18);

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        uint256 extractedAmount = input.amount + input.feeParams.fee + extra;

        token.mint(rebalancer, extractedAmount);
        vm.startPrank(rebalancer);
        token.approve(address(bridge), extractedAmount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit EverclearBridgeV2.RebalancingReturnedToMarket(market, extra, extractedAmount);
        vm.expectEmit(true, true, false, true);
        emit EverclearBridgeV2.MsgSent(dstChainId, market, input.amount, feeAdapter.nextId());

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(extractedAmount, market, dstChainId, address(token), message, "");
        vm.stopPrank();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(token.balanceOf(market), extra, "expected token.balanceOf(market) to equal extra");
        assertEq(
            token.balanceOf(address(bridge)),
            input.amount + input.feeParams.fee,
            "expected token.balanceOf(address(bridge)) to equal input.amount + input.feeParams.fee"
        );
        assertEq(
            token.allowance(address(bridge), address(feeAdapter)),
            input.amount + input.feeParams.fee,
            "expected token.allowance(address(bridge), address(feeAdapter)) to equal input.amount + input.feeParams.fee"
        );
        assertEq(feeAdapter.callCount(), 1, "expected feeAdapter.callCount() to equal 1");
        assertEq(
            feeAdapter.lastDestinations(0), dstChainId, "expected feeAdapter.lastDestinations(0) to equal dstChainId"
        );
        assertEq(feeAdapter.lastAmount(), input.amount, "expected feeAdapter.lastAmount() to equal input.amount");
        assertEq(
            feeAdapter.lastAmountOutMin(),
            input.amountOutMin,
            "expected feeAdapter.lastAmountOutMin() to equal input.amountOutMin"
        );

        (uint256 storedFee, uint256 storedDeadline, bytes memory storedSig) = feeAdapter.lastFeeParams();
        assertEq(storedFee, input.feeParams.fee, "expected storedFee to equal input.feeParams.fee");
        assertEq(storedDeadline, input.feeParams.deadline, "expected storedDeadline to equal input.feeParams.deadline");
        assertEq(
            keccak256(storedSig),
            keccak256(input.feeParams.sig),
            "expected keccak256(storedSig) to equal keccak256(input.feeParams.sig)"
        );
    }

    function test_fuzz_msgSent_success_noExcess(
        uint96 amountRaw,
        uint96 feeRaw,
        uint48 ttl,
        bytes calldata data,
        bytes calldata sig,
        uint256 deadline
    ) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 dataLength = bound(data.length, 0, 64);
        bytes memory boundedData = new bytes(dataLength);
        for (uint256 i; i < dataLength; ++i) {
            boundedData[i] = data[i];
        }

        uint256 sigLength = bound(sig.length, 0, 64);
        bytes memory boundedSig = new bytes(sigLength);
        for (uint256 i; i < sigLength; ++i) {
            boundedSig[i] = sig[i];
        }

        IntentInput memory input = _defaultInput();
        input.amount = bound(amountRaw, 1, 1e18);
        input.amountOutMin = input.amount * 9 / 10;
        input.ttl = ttl;
        input.data = boundedData;
        input.feeParams = IFeeAdapterV2.FeeParams(bound(feeRaw, 0, input.amount / 2), deadline, boundedSig);

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        uint256 extractedAmount = input.amount + input.feeParams.fee;

        token.mint(rebalancer, extractedAmount);
        vm.startPrank(rebalancer);
        token.approve(address(bridge), extractedAmount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit EverclearBridgeV2.MsgSent(dstChainId, market, input.amount, feeAdapter.nextId());

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(extractedAmount, market, dstChainId, address(token), message, "");
        vm.stopPrank();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(token.balanceOf(market), 0, "expected token.balanceOf(market) to equal 0");
        assertEq(
            token.balanceOf(address(bridge)),
            input.amount + input.feeParams.fee,
            "expected token.balanceOf(address(bridge)) to equal input.amount + input.feeParams.fee"
        );
        assertEq(
            token.allowance(address(bridge), address(feeAdapter)),
            input.amount + input.feeParams.fee,
            "expected token.allowance(address(bridge), address(feeAdapter)) to equal input.amount + input.feeParams.fee"
        );
        assertEq(feeAdapter.callCount(), 1, "expected feeAdapter.callCount() to equal 1");
        assertEq(
            feeAdapter.lastDestinations(0), dstChainId, "expected feeAdapter.lastDestinations(0) to equal dstChainId"
        );
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

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

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
