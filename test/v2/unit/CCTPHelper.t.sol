// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";

import {CCTPHelper} from "src/rebalancer/bridges/cctp/CCTPHelper.sol";

import {IMessageTransmitterV2} from "src/interfaces/external/cctp/IMessageTransmitterV2.sol";
import {ITokenMessangerV2} from "src/interfaces/external/cctp/ITokenMessangerV2.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

// ---------------- MOCKS ----------------
contract MockTokenMessenger is ITokenMessangerV2 {
    address public lastToken;
    uint256 public lastAmount;
    uint32 public lastDst;
    bytes32 public lastReceiver;
    bytes32 public lastDestinationCaller;
    uint256 public lastMaxFee;
    uint32 public lastMinFinalityThreshold;
    bytes public lastPayload;
    address public lastCaller;

    function depositForBurnWithHook(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold,
        bytes calldata hookData
    ) external override {
        lastCaller = msg.sender;
        lastAmount = amount;
        lastDst = destinationDomain;
        lastReceiver = mintRecipient;
        lastToken = burnToken;
        lastDestinationCaller = destinationCaller;
        lastMaxFee = maxFee;
        lastMinFinalityThreshold = minFinalityThreshold;
        lastPayload = hookData;
    }
}

contract MockMessageTransmitter is IMessageTransmitterV2 {
    bool public shouldSucceed = true;

    function setShouldSucceed(bool val) external {
        shouldSucceed = val;
    }

    function receiveMessage(bytes calldata, bytes calldata) external view override returns (bool) {
        return shouldSucceed;
    }
}

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

contract CCTPHelperTest is Test {
    CCTPHelperHarness internal helper;
    ERC20Mock internal token;
    MockTokenMessenger internal messenger;
    MockMessageTransmitter internal transmitter;

    address internal user = address(0x1234);
    uint32 internal constant SRC = 1;
    uint32 internal constant DST = 2;

    function setUp() public {
        token = new ERC20Mock("Test", "Test", 18, address(this), address(0), 0);
        messenger = new MockTokenMessenger();
        transmitter = new MockMessageTransmitter();

        helper = new CCTPHelperHarness(address(messenger), address(transmitter));

        token.mint(user, 1_000_000);

        helper.setAcceptedToken(address(token), true);

        vm.prank(user);
        token.approve(address(helper), type(uint256).max);
    }

    function test_createAndBurn_success() public {
        vm.startPrank(user);

        bytes memory payload = abi.encode(address(0xBEEF));
        bytes32 receiver = bytes32(uint256(uint160(address(0xCAFE))));

        (CCTPHelper.CCTPMessage memory msgData, bytes memory encoded) =
            helper.exposedCreateAndBurn(address(token), 1000, DST, receiver, payload, SRC);

        assertEq(msgData.amount, 1000);
        assertEq(msgData.srcChain, SRC);
        assertEq(msgData.dstChain, DST);
        assertEq(msgData.nonce, 0); // v2: we don't have an on-chain nonce
        assertEq(msgData.from, bytes32(uint256(uint160(user))));
        assertEq(msgData.receiver, receiver);
        assertEq(keccak256(msgData.payload), keccak256(payload));
        assertGt(encoded.length, 147);

        assertEq(messenger.lastCaller(), address(helper));
        assertEq(messenger.lastToken(), address(token));
        assertEq(messenger.lastAmount(), 1000);
        assertEq(messenger.lastDst(), DST);
        assertEq(messenger.lastReceiver(), receiver);
        assertEq(keccak256(messenger.lastPayload()), keccak256(payload));

        vm.stopPrank();
    }

    function test_createAndBurn_revert_zero_amount() public {
        vm.prank(user);
        vm.expectRevert(CCTPHelper.CCTPHelper_AmountZero.selector);

        helper.exposedCreateAndBurn(address(token), 0, DST, bytes32(uint256(uint160(address(1)))), "", SRC);
    }

    function test_createAndBurn_revert_zero_receiver() public {
        vm.prank(user);
        vm.expectRevert(CCTPHelper.CCTPHelper_AddressZero.selector);

        helper.exposedCreateAndBurn(address(token), 100, DST, bytes32(0), "", SRC);
    }

    function test_handleDestinationMsg_success() public {
        bytes memory fakeHook = abi.encodePacked(
            uint8(1),
            bytes32(uint256(uint160(address(token)))),
            uint256(100),
            uint32(SRC),
            uint32(DST),
            uint64(777),
            bytes32(uint256(uint160(user))),
            bytes32(uint256(uint160(address(0xCAFE)))),
            uint16(0)
        );

        bytes memory fakeCCTPMessage = bytes.concat(new bytes(148), new bytes(228), fakeHook);

        CCTPHelper.CCTPMessage memory msgData = helper.exposedHandleDestinationMsg(fakeCCTPMessage, "att");

        assertEq(msgData.amount, 100);
        assertEq(msgData.srcChain, SRC);
        assertEq(msgData.dstChain, DST);
        assertEq(msgData.nonce, 777);
    }

    function test_handleDestinationMsg_revert_receive_fail() public {
        transmitter.setShouldSucceed(false);

        vm.expectRevert(CCTPHelper.CCTPHelper_ReceiveFailed.selector);
        helper.exposedHandleDestinationMsg("msg", "att");
    }

    function test_handleDestinationMsg_revert_short_message() public {
        vm.expectRevert(CCTPHelper.CCTPHelper_MsgTooShort.selector);
        helper.exposedHandleDestinationMsg(new bytes(10), "att");
    }

    function test_decode_revert_bad_payload_type() public {
        bytes memory payload = abi.encode(address(0xBEEF));

        bytes memory badHook = abi.encodePacked(
            uint8(2), // wrong payloadId
            bytes32(uint256(uint160(address(token)))),
            uint256(100),
            uint32(SRC),
            uint32(DST),
            uint64(777),
            bytes32(uint256(uint160(user))),
            bytes32(uint256(uint160(address(0xCAFE)))),
            uint16(payload.length),
            payload
        );

        bytes memory fakeCCTPMessage = bytes.concat(new bytes(148), new bytes(228), badHook);

        vm.expectRevert(CCTPHelper.CCTPHelper_PayloadMismatch.selector);
        helper.exposedHandleDestinationMsg(fakeCCTPMessage, "att");
    }

    function _decode(bytes memory data) internal pure returns (CCTPHelper.CCTPMessage memory) {
        return abi.decode(abi.encodePacked(data), (CCTPHelper.CCTPMessage));
    }
}
