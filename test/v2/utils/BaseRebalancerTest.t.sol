// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {BaseUnitTest} from "test/v2/utils/BaseUnitTest.t.sol";

import {BridgeMock} from "test/mocks/BridgeMock.sol";
import {Rebalancer} from "src/rebalancer/Rebalancer.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";

import {Risc0VerifierMock} from "test/mocks/Risc0VerifierMock.sol";

abstract contract BaseRebalancerTest is BaseUnitTest {
    mErc20Host public mWethHost;
    BridgeMock public bridgeMock;
    Rebalancer public rebalancer;
    mTokenGateway public mWethExtension;
    Risc0VerifierMock public verifierMock;
    ZkVerifier public zkVerifier;

    function setUp() public virtual override {
        super.setUp();

        verifierMock = new Risc0VerifierMock();
        vm.label(address(verifierMock), "verifierMock");

        zkVerifier = new ZkVerifier(address(this), "0x123", address(verifierMock));
        vm.label(address(zkVerifier), "ZkVerifier");

        mErc20Host implementation = new mErc20Host();
        bytes memory initData = abi.encodeWithSelector(
            mErc20Host.initialize.selector,
            address(weth),
            address(operator),
            address(interestModel),
            1e18,
            "Market WETH",
            "mWeth",
            18,
            payable(address(this)),
            address(zkVerifier),
            address(roles)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        mWethHost = mErc20Host(address(proxy));
        vm.label(address(mWethHost), "mWethHost");
        mWethHost.setRolesOperator(address(roles));

        mTokenGateway gatewayImpl = new mTokenGateway();
        bytes memory gatewayInitData = abi.encodeWithSelector(
            mTokenGateway.initialize.selector,
            payable(address(this)),
            address(weth),
            address(roles),
            address(blacklister),
            address(zkVerifier)
        );
        ERC1967Proxy gatewayProxy = new ERC1967Proxy(address(gatewayImpl), gatewayInitData);
        mWethExtension = mTokenGateway(address(gatewayProxy));
        vm.label(address(mWethExtension), "mWethExtension");

        rebalancer = new Rebalancer(address(roles), address(this), address(this), "");
        vm.label(address(rebalancer), "Rebalancer");
        roles.allowFor(address(rebalancer), roles.REBALANCER(), true);

        bridgeMock = new BridgeMock(address(roles));
        vm.label(address(bridgeMock), "BridgeMock");
    }

    modifier whenMarketIsListed(address mToken) {
        operator.supportMarket(mToken);
        _;
    }
}
