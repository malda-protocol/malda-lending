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
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ZkVerifier.ZkVerifier_InputNotValid.selector);
        new ZkVerifier(owner, imageId, address(0));
    }

    function test_unit_constructor_revertsWith_ZkVerifier_InputNotValid_whenImageIdZero() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ZkVerifier.ZkVerifier_InputNotValid.selector);
        new ZkVerifier(owner, bytes32(0), address(verifierMock));
    }

    ////////////////////////////////////////////////////////////
    //                      SetVerifier                       //
    ////////////////////////////////////////////////////////////

    function test_unit_setVerifier_revertsWith_ZkVerifier_InputNotValid() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(owner);
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ZkVerifier.ZkVerifier_InputNotValid.selector);
        zkVerifier.setVerifier(address(0));
    }

    function test_unit_setVerifier_success_updatesAndEmits() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        Risc0VerifierMock newVerifier = new Risc0VerifierMock();

        vm.prank(owner);
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit ZkVerifier.VerifierSet(address(verifierMock), address(newVerifier));
        zkVerifier.setVerifier(address(newVerifier));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(address(zkVerifier.verifier()), address(newVerifier));
    }

    ////////////////////////////////////////////////////////////
    //                       SetImageId                       //
    ////////////////////////////////////////////////////////////

    function test_unit_setImageId_revertsWith_ZkVerifier_ImageNotValid() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(owner);
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ZkVerifier.ZkVerifier_ImageNotValid.selector);
        zkVerifier.setImageId(bytes32(0));
    }

    function test_unit_setImageId_success_updatesAndEmits() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes32 newImageId = bytes32(uint256(2));

        vm.prank(owner);
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit ZkVerifier.ImageSet(newImageId);
        zkVerifier.setImageId(newImageId);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(zkVerifier.imageId(), newImageId);
    }

    ////////////////////////////////////////////////////////////
    //                      VerifyInput                       //
    ////////////////////////////////////////////////////////////

    function test_unit_verifyInput_revertsWith_ZkVerifier_VerifierNotSet(bytes memory journalEntry, bytes memory seal)
        public
    {
        vm.assume(journalEntry.length <= 1024);
        vm.assume(seal.length <= 1024);

        zkVerifier.setVerifierUnsafe(address(0));

        vm.expectRevert(ZkVerifier.ZkVerifier_VerifierNotSet.selector);
        zkVerifier.verifyInput(journalEntry, seal);
    }

    function test_unit_verifyInput_success_passesToVerifier(bytes memory journalEntry, bytes memory seal) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(journalEntry.length <= 1024);
        vm.assume(seal.length <= 1024);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectCall(
            address(verifierMock),
            abi.encodeWithSelector(IRiscZeroVerifier.verify.selector, seal, imageId, sha256(journalEntry))
        );
        zkVerifier.verifyInput(journalEntry, seal);
    }
}
