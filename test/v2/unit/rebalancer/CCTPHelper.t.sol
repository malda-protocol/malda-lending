// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {CCTPHelper} from "src/rebalancer/bridges/cctp/CCTPHelper.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {MockMessageTransmitter, MockTokenMessenger} from "test/v2/mocks/rebalancer/CCTPHelperMocks.t.sol";
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract CCTPHelperHarness is CCTPHelper {
    constructor(address _tokenMessenger, address _messageTransmitter)
        CCTPHelper(_tokenMessenger, _messageTransmitter)
    {}

    function exposedCreateAndBurn(
        address _token,
        uint256 _amount,
        uint32 _dstDomain,
        bytes32 _receiver,
        bytes calldata _payload,
        uint32 _srcDomain
    ) external returns (CCTPMessage memory msgData, bytes memory encoded) {
        return createAndBurn(_token, _amount, _dstDomain, _receiver, _payload, _srcDomain);
    }

    function exposedHandleDestinationMsg(bytes calldata cctpMessage, bytes calldata attestation)
        external
        returns (CCTPMessage memory msgData)
    {
        return handleDestinationMsg(cctpMessage, attestation);
    }

    function setAcceptedToken(address token, bool allowed) external {
        acceptedTokens[token] = allowed;
    }
}

contract CCTPHelperTest is BaseTest {
    uint8 internal constant PAYLOAD_ID_V1 = 1;
    uint8 internal constant WRONG_PAYLOAD_ID = 2;
    uint256 internal constant DEFAULT_TRANSFER_AMOUNT = 100;
    uint64 internal constant DEFAULT_NONCE = 777;
    uint256 internal constant CCTP_HEADER_BYTES = 148;
    uint256 internal constant CCTP_BODY_HEADER_BYTES = 228;
    uint256 internal constant MIN_HOOK_MESSAGE_LENGTH = 147;

    CCTPHelperHarness internal helper;
    ERC20Mock internal token;
    MockTokenMessenger internal messenger;
    MockMessageTransmitter internal transmitter;

    address internal user;
    uint32 internal constant SRC = 1;
    uint32 internal constant DST = 2;

    function setUp() public override {
        super.setUp();

        user = users.alice;
        token = new ERC20Mock("Test", "Test", 18, address(this), address(0), 0);
        messenger = new MockTokenMessenger();
        transmitter = new MockMessageTransmitter();

        helper = new CCTPHelperHarness(address(messenger), address(transmitter));

        token.mint(user, 1_000_000);
        helper.setAcceptedToken(address(token), true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(user);
        token.approve(address(helper), type(uint256).max);
    }

    ////////////////////////////////////////////////////////////
    //                  exposedCreateAndBurn                  //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_CCTPHelper_AddressZero_whenTokenMessengerIsZero() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPHelper.CCTPHelper_AddressZero.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new CCTPHelperHarness(address(0), address(transmitter));
    }

    function test_unit_constructor_revertsWith_CCTPHelper_AddressZero_whenMessageTransmitterIsZero() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPHelper.CCTPHelper_AddressZero.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new CCTPHelperHarness(address(messenger), address(0));
    }

    function test_fuzz_exposedCreateAndBurn_success(uint256 amount, bytes calldata payload) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 payloadLength = bound(payload.length, 0, 64);
        bytes memory boundedPayload = new bytes(payloadLength);
        for (uint256 i; i < payloadLength; ++i) {
            boundedPayload[i] = payload[i];
        }
        amount = bound(amount, 1, token.balanceOf(user));

        bytes32 receiver = bytes32(uint256(uint160(users.carol)));
        bytes32 expectedFrom = bytes32(uint256(uint160(user)));
        bytes32 expectedToken = bytes32(uint256(uint160(address(token))));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit CCTPHelper.BurnInitiated(address(token), amount, DST, receiver, 0, boundedPayload);

        vm.expectEmit(true, true, true, false);
        emit CCTPHelper.MessageCreated(expectedToken, amount, SRC, DST, 0, expectedFrom, receiver, boundedPayload, "");

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(user);
        (CCTPHelper.CCTPMessage memory msgData, bytes memory encoded) =
            helper.exposedCreateAndBurn(address(token), amount, DST, receiver, boundedPayload, SRC);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(msgData.amount, amount, "expected msgData.amount to equal amount");
        assertEq(msgData.srcChain, SRC, "expected msgData.srcChain to equal SRC");
        assertEq(msgData.dstChain, DST, "expected msgData.dstChain to equal DST");
        assertEq(msgData.nonce, 0, "expected msgData.nonce to equal 0");
        assertEq(msgData.from, expectedFrom, "expected msgData.from to equal expectedFrom");
        assertEq(msgData.receiver, receiver, "expected msgData.receiver to equal receiver");
        assertEq(
            keccak256(msgData.payload),
            keccak256(boundedPayload),
            "expected keccak256(msgData.payload) to equal keccak256(boundedPayload)"
        );
        assertGe(
            encoded.length,
            MIN_HOOK_MESSAGE_LENGTH,
            "expected encoded.length to be greater than or equal to MIN_HOOK_MESSAGE_LENGTH"
        );

        assertEq(messenger.lastCaller(), address(helper), "expected messenger.lastCaller() to equal address(helper)");
        assertEq(messenger.lastToken(), address(token), "expected messenger.lastToken() to equal address(token)");
        assertEq(messenger.lastAmount(), amount, "expected messenger.lastAmount() to equal amount");
        assertEq(messenger.lastDst(), DST, "expected messenger.lastDst() to equal DST");
        assertEq(messenger.lastReceiver(), receiver, "expected messenger.lastReceiver() to equal receiver");
        assertEq(
            keccak256(messenger.lastPayload()),
            keccak256(boundedPayload),
            "expected keccak256(messenger.lastPayload()) to equal keccak256(boundedPayload)"
        );
    }

    function test_unit_exposedCreateAndBurn_revertsWith_CCTPHelper_AmountZero() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPHelper.CCTPHelper_AmountZero.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(user);
        helper.exposedCreateAndBurn(address(token), 0, DST, bytes32(uint256(uint160(users.bob))), "", SRC);
    }

    function test_unit_exposedCreateAndBurn_revertsWith_CCTPHelper_AddressZero() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPHelper.CCTPHelper_AddressZero.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(user);
        helper.exposedCreateAndBurn(address(token), 100, DST, bytes32(0), "", SRC);
    }

    function test_unit_exposedCreateAndBurn_revertsWith_CCTPHelper_TokenNotAccepted() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        ERC20Mock otherToken = new ERC20Mock("Other", "O", 18, address(this), address(0), 0);
        otherToken.mint(user, 1000);
        vm.startPrank(user);
        otherToken.approve(address(helper), type(uint256).max);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPHelper.CCTPHelper_TokenNotAccepted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        helper.exposedCreateAndBurn(address(otherToken), 100, DST, bytes32(uint256(uint160(users.bob))), "", SRC);
        vm.stopPrank();
    }

    ////////////////////////////////////////////////////////////
    //                exposedHandleDestinationMsg             //
    ////////////////////////////////////////////////////////////

    function test_unit_exposedHandleDestinationMsg_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint16 payloadLength = 0;
        bytes memory fakeHook = abi.encodePacked(
            PAYLOAD_ID_V1,
            bytes32(uint256(uint160(address(token)))),
            DEFAULT_TRANSFER_AMOUNT,
            uint32(SRC),
            uint32(DST),
            DEFAULT_NONCE,
            bytes32(uint256(uint160(user))),
            bytes32(uint256(uint160(users.carol))),
            payloadLength
        );

        bytes memory fakeCCTPMessage =
            bytes.concat(new bytes(CCTP_HEADER_BYTES), new bytes(CCTP_BODY_HEADER_BYTES), fakeHook);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit CCTPHelper.MessageReceived(
            DEFAULT_NONCE, SRC, DST, DEFAULT_TRANSFER_AMOUNT, bytes32(uint256(uint160(users.carol))), ""
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        CCTPHelper.CCTPMessage memory msgData = helper.exposedHandleDestinationMsg(fakeCCTPMessage, "att");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(msgData.amount, DEFAULT_TRANSFER_AMOUNT, "expected msgData.amount to equal DEFAULT_TRANSFER_AMOUNT");
        assertEq(msgData.srcChain, SRC, "expected msgData.srcChain to equal SRC");
        assertEq(msgData.dstChain, DST, "expected msgData.dstChain to equal DST");
        assertEq(msgData.nonce, DEFAULT_NONCE, "expected msgData.nonce to equal DEFAULT_NONCE");
    }

    function test_unit_exposedHandleDestinationMsg_revertsWith_CCTPHelper_ReceiveFailed() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        transmitter.setShouldSucceed(false);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPHelper.CCTPHelper_ReceiveFailed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        helper.exposedHandleDestinationMsg("msg", "att");
    }

    function test_unit_exposedHandleDestinationMsg_revertsWith_CCTPHelper_MsgTooShort() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPHelper.CCTPHelper_MsgTooShort.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        helper.exposedHandleDestinationMsg(new bytes(10), "att");
    }

    function test_unit_exposedHandleDestinationMsg_revertsWith_CCTPHelper_MsgTooShort_whenBodyHeaderTooShort()
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 shortBodyHeaderLength = CCTP_BODY_HEADER_BYTES - 1;
        bytes memory fakeCCTPMessage = bytes.concat(new bytes(CCTP_HEADER_BYTES), new bytes(shortBodyHeaderLength));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPHelper.CCTPHelper_MsgTooShort.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        helper.exposedHandleDestinationMsg(fakeCCTPMessage, "att");
    }

    function test_unit_exposedHandleDestinationMsg_revertsWith_CCTPHelper_MsgTooShort_whenHookTooShort() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 shortHookLength = MIN_HOOK_MESSAGE_LENGTH - 1;
        bytes memory fakeCCTPMessage =
            bytes.concat(new bytes(CCTP_HEADER_BYTES), new bytes(CCTP_BODY_HEADER_BYTES), new bytes(shortHookLength));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPHelper.CCTPHelper_MsgTooShort.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        helper.exposedHandleDestinationMsg(fakeCCTPMessage, "att");
    }

    function test_unit_exposedHandleDestinationMsg_revertsWith_CCTPHelper_PayloadMismatch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = abi.encode(users.bob);

        bytes memory badHook = abi.encodePacked(
            WRONG_PAYLOAD_ID,
            bytes32(uint256(uint160(address(token)))),
            DEFAULT_TRANSFER_AMOUNT,
            uint32(SRC),
            uint32(DST),
            DEFAULT_NONCE,
            bytes32(uint256(uint160(user))),
            bytes32(uint256(uint160(users.carol))),
            uint16(payload.length),
            payload
        );

        bytes memory fakeCCTPMessage =
            bytes.concat(new bytes(CCTP_HEADER_BYTES), new bytes(CCTP_BODY_HEADER_BYTES), badHook);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPHelper.CCTPHelper_PayloadMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        helper.exposedHandleDestinationMsg(fakeCCTPMessage, "att");
    }

    function test_unit_exposedHandleDestinationMsg_revertsWith_CCTPHelper_LengthMismatch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint64 mismatchedNonce = 1;
        uint16 mismatchedPayloadLen = 1;
        bytes memory badHook = abi.encodePacked(
            PAYLOAD_ID_V1,
            bytes32(uint256(uint160(address(token)))),
            DEFAULT_TRANSFER_AMOUNT,
            uint32(SRC),
            uint32(DST),
            mismatchedNonce,
            bytes32(uint256(uint160(user))),
            bytes32(uint256(uint160(users.carol))),
            mismatchedPayloadLen
        );

        bytes memory fakeCCTPMessage =
            bytes.concat(new bytes(CCTP_HEADER_BYTES), new bytes(CCTP_BODY_HEADER_BYTES), badHook);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPHelper.CCTPHelper_LengthMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        helper.exposedHandleDestinationMsg(fakeCCTPMessage, "att");
    }
}
