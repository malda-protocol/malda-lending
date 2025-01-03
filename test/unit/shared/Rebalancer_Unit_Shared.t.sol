// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {IPauser} from "src/interfaces/IPauser.sol";

import {BridgeMock} from "../../mocks/BridgeMock.sol";
import {Rebalancer} from "src/rebalancer/Rebalancer.sol";
import {Base_Unit_Test} from "../../Base_Unit_Test.t.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {Risc0VerifierMock} from "../../mocks/Risc0VerifierMock.sol";
import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";

abstract contract Rebalancer_Unit_Shared is Base_Unit_Test {
    mErc20Host public mWethHost;
    BridgeMock public bridgeMock;
    Rebalancer public rebalancer;
    mTokenGateway public mWethExtension;
    Risc0VerifierMock public verifierMock;

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
            address(verifierMock)
        );
        vm.label(address(mWethHost), "mWethHost");
        mWethHost.setRolesOperator(address(roles));

        mWethExtension = new mTokenGateway(payable(address(this)), address(weth), address(roles), address(verifierMock));
        vm.label(address(mWethExtension), "mWethExtension");

        rebalancer = new Rebalancer(address(roles));
        vm.label(address(rebalancer), "Rebalancer");
        roles.allowFor(address(rebalancer), roles.REBALANCER(), true);

        bridgeMock = new BridgeMock(address(roles));
        vm.label(address(bridgeMock), "BridgeMock");
    }
}
