// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";
import {IRiscZeroVerifier} from "risc0/IRiscZeroVerifier.sol";

import {Risc0VerifierMock} from "test/mocks/Risc0VerifierMock.sol";

contract ZkVerifierHarness is ZkVerifier {
    constructor(address owner_, bytes32 imageId_, address verifier_) ZkVerifier(owner_, imageId_, verifier_) {}

    function setVerifierUnsafe(address verifier_) external {
        verifier = IRiscZeroVerifier(verifier_);
    }
}

contract ZkVerifierTest is Test {
    address internal owner = address(0xABCD);
    bytes32 internal imageId = bytes32(uint256(1));

    Risc0VerifierMock internal verifierMock;
    ZkVerifierHarness internal zkVerifier;

    function setUp() public {
        verifierMock = new Risc0VerifierMock();
        zkVerifier = new ZkVerifierHarness(owner, imageId, address(verifierMock));
    }

    function test_constructor_RevertWhenVerifierZero() public {
        vm.expectRevert(ZkVerifier.ZkVerifier_InputNotValid.selector);
        new ZkVerifier(owner, imageId, address(0));
    }

    function test_constructor_RevertWhenImageIdZero() public {
        vm.expectRevert(ZkVerifier.ZkVerifier_InputNotValid.selector);
        new ZkVerifier(owner, bytes32(0), address(verifierMock));
    }

    function test_setVerifier_RevertsWhenZero() public {
        vm.prank(owner);
        vm.expectRevert(ZkVerifier.ZkVerifier_InputNotValid.selector);
        zkVerifier.setVerifier(address(0));
    }

    function test_setVerifier_UpdatesAndEmits() public {
        Risc0VerifierMock newVerifier = new Risc0VerifierMock();

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit ZkVerifier.VerifierSet(address(verifierMock), address(newVerifier));
        zkVerifier.setVerifier(address(newVerifier));

        assertEq(address(zkVerifier.verifier()), address(newVerifier));
    }

    function test_setImageId_RevertsWhenZero() public {
        vm.prank(owner);
        vm.expectRevert(ZkVerifier.ZkVerifier_ImageNotValid.selector);
        zkVerifier.setImageId(bytes32(0));
    }

    function test_setImageId_UpdatesAndEmits() public {
        bytes32 newImageId = bytes32(uint256(2));

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit ZkVerifier.ImageSet(newImageId);
        zkVerifier.setImageId(newImageId);

        assertEq(zkVerifier.imageId(), newImageId);
    }

    function test_verifyInput_RevertWhenVerifierNotSet(bytes memory journalEntry, bytes memory seal) public {
        vm.assume(journalEntry.length <= 1024);
        vm.assume(seal.length <= 1024);

        zkVerifier.setVerifierUnsafe(address(0));

        vm.expectRevert(ZkVerifier.ZkVerifier_VerifierNotSet.selector);
        zkVerifier.verifyInput(journalEntry, seal);
    }

    function test_verifyInput_PassesToVerifier(bytes memory journalEntry, bytes memory seal) public {
        vm.assume(journalEntry.length <= 1024);
        vm.assume(seal.length <= 1024);

        vm.expectCall(
            address(verifierMock),
            abi.encodeWithSelector(IRiscZeroVerifier.verify.selector, seal, imageId, sha256(journalEntry))
        );
        zkVerifier.verifyInput(journalEntry, seal);
    }
}
