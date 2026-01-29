// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";
import {ReferralSigning} from "src/referral/ReferralSigning.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {DummyReferrer} from "test/v2/mocks/ReferralSigningMocks.t.sol";

contract ReferralSigningTest is BaseTest {
    ReferralSigning internal referral;

    address internal referrer;
    address internal referred;
    uint256 internal referrerKey;
    uint256 internal referredKey;

    function setUp() public override {
        super.setUp();
        (referrer, referrerKey) = makeAddrAndKey("referrer");
        (referred, referredKey) = makeAddrAndKey("referred");

        referral = new ReferralSigning();
    }

    function sign(uint256 privKey, address user, address referrerAddr, uint256 nonce)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 messageHash = keccak256(abi.encodePacked(user, referrerAddr, nonce));
        bytes32 ethSigned = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, ethSigned);
        return abi.encodePacked(r, s, v);
    }

    ////////////////////////////////////////////////////////////
    //                      ClaimReferral                       //
    ////////////////////////////////////////////////////////////

    function test_unitClaimReferral_success_Works() public {
        uint256 nonce = referral.nonces(referred);
        bytes memory sig = sign(referredKey, referred, referrer, nonce);

        vm.prank(referred);
        referral.claimReferral(sig, referrer);

        assertEq(referral.referralsForUserRegistry(referred), referrer);
        assertTrue(referral.referredByRegistry(referrer, referred));
        assertTrue(referral.isUserReferred(referred));
        assertEq(referral.totalReferred(referrer), 1);
        assertEq(referral.nonces(referred), nonce + 1);
    }

    function test_unitClaimReferral_success_RejectsSelfReferral() public {
        uint256 nonce = referral.nonces(referrer);
        bytes memory sig = sign(referrerKey, referrer, referrer, nonce);

        vm.prank(referrer);
        vm.expectRevert(abi.encodeWithSelector(ReferralSigning.ReferralSigning_SameUser.selector));
        referral.claimReferral(sig, referrer);
    }

    function test_unitClaimReferral_success_RejectsDoubleClaim() public {
        uint256 nonce = referral.nonces(referred);
        bytes memory sig = sign(referredKey, referred, referrer, nonce);

        vm.prank(referred);
        referral.claimReferral(sig, referrer);

        vm.prank(referred);
        vm.expectRevert(abi.encodeWithSelector(ReferralSigning.ReferralSigning_UserAlreadyReferred.selector));
        referral.claimReferral(sig, referrer);
    }

    function test_unitClaimReferral_success_InvalidSignature() public {
        uint256 nonce = referral.nonces(referred);
        // Signed by referrer instead of referred
        bytes memory sig = sign(referrerKey, referred, referrer, nonce);

        vm.prank(referred);
        vm.expectRevert(abi.encodeWithSelector(ReferralSigning.ReferralSigning_InvalidSignature.selector));
        referral.claimReferral(sig, referrer);
    }

    function test_unitClaimReferral_success_RejectsContractReferrer() public {
        address contractReferrer = address(new DummyReferrer());
        uint256 nonce = referral.nonces(referred);
        bytes memory sig = sign(referredKey, referred, contractReferrer, nonce);

        vm.prank(referred);
        vm.expectRevert(abi.encodeWithSelector(ReferralSigning.ReferralSigning_ContractReferrerNotAllowed.selector));
        referral.claimReferral(sig, contractReferrer);
    }
}
