// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {ReferralSigning} from "src/referral/ReferralSigning.sol";

import {DummyReferrer} from "test/v2/mocks/ReferralSigningMocks.t.sol";
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

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

    ////////////////////////////////////////////////////////////
    //                     claimReferral                      //
    ////////////////////////////////////////////////////////////

    function test_unit_claimReferral_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 nonce = referral.nonces(referred);
        bytes memory sig = _signReferral(referredKey, referred, referrer, nonce);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(referral));
        emit ReferralSigning.ReferralClaimed(referred, referrer);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(referred);
        referral.claimReferral(sig, referrer);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            referral.referralsForUserRegistry(referred),
            referrer,
            "expected referral.referralsForUserRegistry(referred) to equal referrer"
        );
        assertTrue(
            referral.referredByRegistry(referrer, referred),
            "expected condition to be true: referral.referredByRegistry(referrer, referred)"
        );
        assertTrue(
            referral.isUserReferred(referred), "expected condition to be true: referral.isUserReferred(referred)"
        );
        assertEq(referral.totalReferred(referrer), 1, "expected referral.totalReferred(referrer) to equal 1");
        assertEq(referral.nonces(referred), nonce + 1, "expected referral.nonces(referred) to equal nonce + 1");
    }

    function test_unit_claimReferral_revertsWith_ReferralSigning_SameUser() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 nonce = referral.nonces(referrer);
        bytes memory sig = _signReferral(referrerKey, referrer, referrer, nonce);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(referral));
        emit ReferralSigning.ReferralRejected(referrer, referrer, "Self-referral not allowed");
        vm.expectRevert(ReferralSigning.ReferralSigning_SameUser.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(referrer);
        referral.claimReferral(sig, referrer);
    }

    function test_unit_claimReferral_revertsWith_ReferralSigning_UserAlreadyReferred() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 nonce = referral.nonces(referred);
        bytes memory sig = _signReferral(referredKey, referred, referrer, nonce);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(referral));
        emit ReferralSigning.ReferralClaimed(referred, referrer);

        vm.startPrank(referred);
        referral.claimReferral(sig, referrer);
        vm.stopPrank();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(referral));
        emit ReferralSigning.ReferralRejected(referred, referred, "Already referred");
        vm.expectRevert(ReferralSigning.ReferralSigning_UserAlreadyReferred.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(referred);
        referral.claimReferral(sig, referrer);
    }

    function test_unit_claimReferral_revertsWith_ReferralSigning_InvalidSignature() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 nonce = referral.nonces(referred);
        bytes memory sig = _signReferral(referrerKey, referred, referrer, nonce);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(referral));
        emit ReferralSigning.ReferralRejected(referred, referrer, "Invalid signature");
        vm.expectRevert(ReferralSigning.ReferralSigning_InvalidSignature.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(referred);
        referral.claimReferral(sig, referrer);
    }

    function test_unit_claimReferral_revertsWith_ReferralSigning_ContractReferrerNotAllowed() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address contractReferrer = address(new DummyReferrer());
        uint256 nonce = referral.nonces(referred);
        bytes memory sig = _signReferral(referredKey, referred, contractReferrer, nonce);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(referral));
        emit ReferralSigning.ReferralRejected(referred, contractReferrer, "Contract referrers not allowed");
        vm.expectRevert(ReferralSigning.ReferralSigning_ContractReferrerNotAllowed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(referred);
        referral.claimReferral(sig, contractReferrer);
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _signReferral(uint256 privKey, address user, address referrerAddr, uint256 nonce)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 messageHash = keccak256(abi.encodePacked(user, referrerAddr, nonce));
        bytes32 ethSigned = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, ethSigned);
        return abi.encodePacked(r, s, v);
    }
}
