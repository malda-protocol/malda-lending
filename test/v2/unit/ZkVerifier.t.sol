// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IRiscZeroVerifier} from "risc0/IRiscZeroVerifier.sol";

import {ZkVerifier} from "src/verifier/ZkVerifier.sol";

import {Risc0VerifierMock} from "test/mocks/Risc0VerifierMock.sol";
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract ZkVerifierHarness is ZkVerifier {
    constructor(address owner_, bytes32 imageId_, address verifier_) ZkVerifier(owner_, imageId_, verifier_) {}

    function setVerifierUnsafe(address verifier_) external {
        verifier = IRiscZeroVerifier(verifier_);
    }
}

contract ZkVerifierTest is BaseTest {
    address internal owner;
    bytes32 internal imageId = bytes32(uint256(1));

    Risc0VerifierMock internal verifierMock;
    ZkVerifierHarness internal zkVerifier;

    function setUp() public override {
        super.setUp();
        owner = users.admin;
        verifierMock = new Risc0VerifierMock();
        zkVerifier = new ZkVerifierHarness(owner, imageId, address(verifierMock));
    }

    ////////////////////////////////////////////////////////////
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_ZkVerifier_InputNotValid_whenVerifierZero() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ZkVerifier.ZkVerifier_InputNotValid.selector);
        new ZkVerifier(owner, imageId, address(0));
    }

    function test_unit_constructor_revertsWith_ZkVerifier_InputNotValid_whenImageIdZero() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ZkVerifier.ZkVerifier_InputNotValid.selector);
        new ZkVerifier(owner, bytes32(0), address(verifierMock));
    }

    ////////////////////////////////////////////////////////////
    //                      SetVerifier                       //
    ////////////////////////////////////////////////////////////

    function test_unit_setVerifier_revertsWith_ZkVerifier_InputNotValid() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ZkVerifier.ZkVerifier_InputNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(owner);
        zkVerifier.setVerifier(address(0));
    }

    function test_unit_setVerifier_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        Risc0VerifierMock newVerifier = new Risc0VerifierMock();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit ZkVerifier.VerifierSet(address(verifierMock), address(newVerifier));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(owner);
        zkVerifier.setVerifier(address(newVerifier));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            address(zkVerifier.verifier()),
            address(newVerifier),
            "expected address(zkVerifier.verifier()) to equal address(newVerifier)"
        );
    }

    ////////////////////////////////////////////////////////////
    //                       SetImageId                       //
    ////////////////////////////////////////////////////////////

    function test_unit_setImageId_revertsWith_ZkVerifier_ImageNotValid() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ZkVerifier.ZkVerifier_ImageNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(owner);
        zkVerifier.setImageId(bytes32(0));
    }

    function test_unit_setImageId_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes32 newImageId = bytes32(uint256(2));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit ZkVerifier.ImageSet(newImageId);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(owner);
        zkVerifier.setImageId(newImageId);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(zkVerifier.imageId(), newImageId, "expected zkVerifier.imageId() to equal newImageId");
    }

    ////////////////////////////////////////////////////////////
    //                      VerifyInput                       //
    ////////////////////////////////////////////////////////////

    function test_unit_verifyInput_revertsWith_ZkVerifier_VerifierNotSet(bytes memory journalEntry, bytes memory seal)
        public
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 journalLength = bound(journalEntry.length, 0, 1024);
        uint256 sealLength = bound(seal.length, 0, 1024);

        bytes memory boundedJournal = new bytes(journalLength);
        for (uint256 i; i < journalLength; ++i) {
            boundedJournal[i] = journalEntry[i];
        }

        bytes memory boundedSeal = new bytes(sealLength);
        for (uint256 i; i < sealLength; ++i) {
            boundedSeal[i] = seal[i];
        }

        zkVerifier.setVerifierUnsafe(address(0));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ZkVerifier.ZkVerifier_VerifierNotSet.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        zkVerifier.verifyInput(boundedJournal, boundedSeal);
    }

    function test_unit_verifyInput_success(bytes memory journalEntry, bytes memory seal) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 journalLength = bound(journalEntry.length, 0, 1024);
        uint256 sealLength = bound(seal.length, 0, 1024);

        bytes memory boundedJournal = new bytes(journalLength);
        for (uint256 i; i < journalLength; ++i) {
            boundedJournal[i] = journalEntry[i];
        }

        bytes memory boundedSeal = new bytes(sealLength);
        for (uint256 i; i < sealLength; ++i) {
            boundedSeal[i] = seal[i];
        }

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectCall(
            address(verifierMock),
            abi.encodeWithSelector(IRiscZeroVerifier.verify.selector, boundedSeal, imageId, sha256(boundedJournal))
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        zkVerifier.verifyInput(boundedJournal, boundedSeal);
    }
}
