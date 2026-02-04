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
        assertGe(encoded.length, 147, "expected encoded.length to be greater than or equal to 147");

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
        bytes memory fakeHook = abi.encodePacked(
            uint8(1),
            bytes32(uint256(uint160(address(token)))),
            uint256(100),
            uint32(SRC),
            uint32(DST),
            uint64(777),
            bytes32(uint256(uint160(user))),
            bytes32(uint256(uint160(users.carol))),
            uint16(0)
        );

        bytes memory fakeCCTPMessage = bytes.concat(new bytes(148), new bytes(228), fakeHook);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit CCTPHelper.MessageReceived(777, SRC, DST, 100, bytes32(uint256(uint160(users.carol))), "");

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        CCTPHelper.CCTPMessage memory msgData = helper.exposedHandleDestinationMsg(fakeCCTPMessage, "att");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(msgData.amount, 100, "expected msgData.amount to equal 100");
        assertEq(msgData.srcChain, SRC, "expected msgData.srcChain to equal SRC");
        assertEq(msgData.dstChain, DST, "expected msgData.dstChain to equal DST");
        assertEq(msgData.nonce, 777, "expected msgData.nonce to equal 777");
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

    function test_unit_exposedHandleDestinationMsg_revertsWith_CCTPHelper_PayloadMismatch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = abi.encode(users.bob);

        bytes memory badHook = abi.encodePacked(
            uint8(2),
            bytes32(uint256(uint160(address(token)))),
            uint256(100),
            uint32(SRC),
            uint32(DST),
            uint64(777),
            bytes32(uint256(uint160(user))),
            bytes32(uint256(uint160(users.carol))),
            uint16(payload.length),
            payload
        );

        bytes memory fakeCCTPMessage = bytes.concat(new bytes(148), new bytes(228), badHook);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPHelper.CCTPHelper_PayloadMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        helper.exposedHandleDestinationMsg(fakeCCTPMessage, "att");
    }
}
