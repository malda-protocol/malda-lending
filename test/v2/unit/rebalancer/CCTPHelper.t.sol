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

        vm.prank(user);
        token.approve(address(helper), type(uint256).max);
    }

    ////////////////////////////////////////////////////////////
    //                  exposedCreateAndBurn                  //
    ////////////////////////////////////////////////////////////

    function test_fuzz_exposedCreateAndBurn_success_emitsAndReturns(uint256 amount, bytes calldata payload) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(payload.length <= 64);
        amount = bound(amount, 1, token.balanceOf(user));

        bytes32 receiver = bytes32(uint256(uint160(users.carol)));
        bytes32 expectedFrom = bytes32(uint256(uint160(user)));
        bytes32 expectedToken = bytes32(uint256(uint160(address(token))));

        vm.startPrank(user);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit CCTPHelper.BurnInitiated(address(token), amount, DST, receiver, 0, payload);

        vm.expectEmit(true, true, true, false);
        emit CCTPHelper.MessageCreated(expectedToken, amount, SRC, DST, 0, expectedFrom, receiver, payload, "");

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        (CCTPHelper.CCTPMessage memory msgData, bytes memory encoded) =
            helper.exposedCreateAndBurn(address(token), amount, DST, receiver, payload, SRC);

        vm.stopPrank();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(msgData.amount, amount);
        assertEq(msgData.srcChain, SRC);
        assertEq(msgData.dstChain, DST);
        assertEq(msgData.nonce, 0);
        assertEq(msgData.from, expectedFrom);
        assertEq(msgData.receiver, receiver);
        assertEq(keccak256(msgData.payload), keccak256(payload));
        assertGe(encoded.length, 147);

        assertEq(messenger.lastCaller(), address(helper));
        assertEq(messenger.lastToken(), address(token));
        assertEq(messenger.lastAmount(), amount);
        assertEq(messenger.lastDst(), DST);
        assertEq(messenger.lastReceiver(), receiver);
        assertEq(keccak256(messenger.lastPayload()), keccak256(payload));
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

    function test_unit_exposedHandleDestinationMsg_success_emitsAndReturns() external {
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
        assertEq(msgData.amount, 100);
        assertEq(msgData.srcChain, SRC);
        assertEq(msgData.dstChain, DST);
        assertEq(msgData.nonce, 777);
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
