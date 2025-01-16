// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {IPauser} from "src/interfaces/IPauser.sol";

import {Pauser} from "src/pauser/Pauser.sol";
import {Base_Unit_Test} from "../../Base_Unit_Test.t.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {Risc0VerifierMock} from "../../mocks/Risc0VerifierMock.sol";
import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";

abstract contract Pauser_Unit_Shared is Base_Unit_Test {
    mErc20Host public mWethHost;
    mTokenGateway public mWethExtension;

    Risc0VerifierMock public verifierMock;

    Pauser public pauser;

    function setUp() public virtual override {
        super.setUp();

        verifierMock = new Risc0VerifierMock();
        vm.label(address(verifierMock), "verifierMock");

        mWethHost = new mErc20Host(
            address(weth),
            address(operator),
            address(interestModel),
            1e18,
            "Market WETH",
            "mWeth",
            18,
            payable(address(this)),
            address(verifierMock),
            address(roles)
        );
        vm.label(address(mWethHost), "mWethHost");

        mWethExtension = new mTokenGateway(payable(address(this)), address(weth), address(roles), address(verifierMock));

        pauser = new Pauser(address(roles), address(operator), address(this));
    }
}
