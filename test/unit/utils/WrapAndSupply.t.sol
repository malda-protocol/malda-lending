// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";

import {WrapAndSupply} from "src/utils/WrapAndSupply.sol";
import {ImErc20} from "src/interfaces/ImErc20.sol";
import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";
import {IRoles} from "src/interfaces/IRoles.sol";
import {IBlacklister} from "src/interfaces/IBlacklister.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

contract MockWrappedNative {
    mapping(address account => uint256 balance) public balanceOf;
    mapping(address owner => mapping(address spender => uint256 amount)) public allowance;

    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

contract MockHostMarket is ImErc20 {
    address public underlying;
    uint256 public lastMintAmount;
    address public lastReceiver;
    uint256 public lastMinAmount;

    constructor(address _underlying) {
        underlying = _underlying;
    }

    function mint(uint256 mintAmount, address receiver, uint256 minAmountOut) external {
        lastMintAmount = mintAmount;
        lastReceiver = receiver;
        lastMinAmount = minAmountOut;
    }

    function redeem(uint256) external {}
    function redeemUnderlying(uint256) external {}
    function borrow(uint256) external {}
    function repay(uint256) external returns (uint256) {}
    function repayBehalf(address, uint256) external returns (uint256) {}
    function liquidate(address, uint256, address) external {}
    function addReserves(uint256) external {}
}

contract MockGateway is ImTokenGateway {
    address public override underlying;
    uint256 public gasFeeAmount;
    uint256 public lastAmount;
    address public lastReceiver;
    bytes4 public lastSelector;
    uint256 public lastValue;

    constructor(address _underlying, uint256 _gasFee) {
        underlying = _underlying;
        gasFeeAmount = _gasFee;
    }

    function gasFee() external view returns (uint256 fee) {
        return gasFeeAmount;
    }

    function supplyOnHost(uint256 amount, address receiver, bytes4 lineaSelector) external payable {
        lastAmount = amount;
        lastReceiver = receiver;
        lastSelector = lineaSelector;
        lastValue = msg.value;
    }

    function extractForRebalancing(uint256) external {}
    function setPaused(ImTokenOperationTypes.OperationType, bool) external {}
    function updateAllowedCallerStatus(address, bool) external {}
    function liquidate(address, uint256, address, address) external payable {}
    function outHere(bytes calldata, bytes calldata, uint256[] calldata, address) external {}

    function rolesOperator() external pure returns (IRoles) {
        return IRoles(address(0));
    }

    function blacklistOperator() external pure returns (IBlacklister) {
        return IBlacklister(address(0));
    }

    function isPaused(ImTokenOperationTypes.OperationType) external pure returns (bool) {
        return false;
    }

    function accAmountIn(address) external pure returns (uint256) {
        return 0;
    }

    function accAmountOut(address) external pure returns (uint256) {
        return 0;
    }

    function getProofData(address, uint32) external pure returns (uint256, uint256) {
        return (0, 0);
    }
}

    contract WrapAndSupplyTest is Test {
        MockWrappedNative internal wrapped;

        function setUp() public {
            wrapped = new MockWrappedNative();
        }

        function test_constructor_revertWhenWrappedNativeZero() external {
            vm.expectRevert(WrapAndSupply.WrapAndSupply_AddressNotValid.selector);
            new WrapAndSupply(address(0));
        }

        function test_wrapAndSupplyOnHostMarket_revertWhenReceiverZero() external {
            WrapAndSupply helper = new WrapAndSupply(address(wrapped));
            MockHostMarket market = new MockHostMarket(address(wrapped));

            vm.expectRevert(WrapAndSupply.WrapAndSupply_AddressNotValid.selector);
            helper.wrapAndSupplyOnHostMarket{value: 1 ether}(address(market), address(0), 1);
        }

        function test_wrapAndSupplyOnHostMarket_revertWhenUnderlyingMismatch() external {
            WrapAndSupply helper = new WrapAndSupply(address(wrapped));
            MockHostMarket market = new MockHostMarket(address(0xBEEF));

            vm.expectRevert(WrapAndSupply.WrapAndSupply_AddressNotValid.selector);
            helper.wrapAndSupplyOnHostMarket{value: 1 ether}(address(market), address(this), 1);
        }

        function test_wrapAndSupplyOnHostMarket_revertWhenAmountZero() external {
            WrapAndSupply helper = new WrapAndSupply(address(wrapped));
            MockHostMarket market = new MockHostMarket(address(wrapped));

            vm.expectRevert(WrapAndSupply.WrapAndSupply_AmountNotValid.selector);
            helper.wrapAndSupplyOnHostMarket(address(market), address(this), 1);
        }

        function test_wrapAndSupplyOnHostMarket_success() external {
            WrapAndSupply helper = new WrapAndSupply(address(wrapped));
            MockHostMarket market = new MockHostMarket(address(wrapped));

            helper.wrapAndSupplyOnHostMarket{value: 2 ether}(address(market), address(this), 123);

            assertEq(market.lastMintAmount(), 2 ether);
            assertEq(market.lastReceiver(), address(this));
            assertEq(market.lastMinAmount(), 123);
            assertEq(wrapped.balanceOf(address(helper)), 2 ether);
            assertEq(wrapped.allowance(address(helper), address(market)), 2 ether);
        }

        function test_wrapAndSupplyOnExtensionMarket_revertWhenReceiverZero() external {
            WrapAndSupply helper = new WrapAndSupply(address(wrapped));
            MockGateway gateway = new MockGateway(address(wrapped), 0.1 ether);

            vm.expectRevert(WrapAndSupply.WrapAndSupply_AddressNotValid.selector);
            helper.wrapAndSupplyOnExtensionMarket{value: 1 ether}(address(gateway), address(0), bytes4(0));
        }

        function test_wrapAndSupplyOnExtensionMarket_revertWhenUnderlyingMismatch() external {
            WrapAndSupply helper = new WrapAndSupply(address(wrapped));
            MockGateway gateway = new MockGateway(address(0xBEEF), 0.1 ether);

            vm.expectRevert(WrapAndSupply.WrapAndSupply_AddressNotValid.selector);
            helper.wrapAndSupplyOnExtensionMarket{value: 1 ether}(address(gateway), address(this), bytes4(0));
        }

        function test_wrapAndSupplyOnExtensionMarket_revertWhenAmountZeroAfterFee() external {
            WrapAndSupply helper = new WrapAndSupply(address(wrapped));
            MockGateway gateway = new MockGateway(address(wrapped), 1 ether);

            vm.expectRevert(WrapAndSupply.WrapAndSupply_AmountNotValid.selector);
            helper.wrapAndSupplyOnExtensionMarket{value: 1 ether}(address(gateway), address(this), bytes4(0));
        }

        function test_wrapAndSupplyOnExtensionMarket_success() external {
            WrapAndSupply helper = new WrapAndSupply(address(wrapped));
            MockGateway gateway = new MockGateway(address(wrapped), 0.1 ether);

            bytes4 selector = bytes4(keccak256("supply(uint256)"));
            helper.wrapAndSupplyOnExtensionMarket{value: 1 ether}(address(gateway), address(this), selector);

            assertEq(gateway.lastAmount(), 0.9 ether);
            assertEq(gateway.lastReceiver(), address(this));
            assertEq(gateway.lastSelector(), selector);
            assertEq(gateway.lastValue(), 0.1 ether);
            assertEq(wrapped.balanceOf(address(helper)), 0.9 ether);
            assertEq(wrapped.allowance(address(helper), address(gateway)), 0.9 ether);
        }
    }
