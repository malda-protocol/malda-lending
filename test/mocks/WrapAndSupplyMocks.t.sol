// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
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
