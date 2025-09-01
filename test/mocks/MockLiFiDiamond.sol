// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ILiFi, ILiFiLIFuel} from "src/rebalancer/bridges/LifiBridge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockLiFiDiamond is ILiFiLIFuel {
    ILiFi.BridgeData private _bd;
    uint256 private _called;
    uint256 private _lastMsgValue;
    uint256 private _ts;

    bool private _shouldRevert;
    string private _revertMsg;

    function setShouldRevert(bool v, string memory m) external {
        _shouldRevert = v;
        _revertMsg = m;
    }

    function startBridgeTokensViaLIFuel(ILiFi.BridgeData calldata bd) external payable {
        _capture(bd);
        // emulate Diamond pulling tokens from the caller (bridge)
        if (bd.sendingAssetId != address(0) && bd.minAmount > 0) {
            IERC20(bd.sendingAssetId).transferFrom(msg.sender, address(this), bd.minAmount);
        }
    }

    function swapAndStartBridgeTokensViaLIFuel(ILiFi.BridgeData calldata bd, bytes calldata) external payable {
        _capture(bd);
        // emulate pull
        if (bd.sendingAssetId != address(0) && bd.minAmount > 0) {
            IERC20(bd.sendingAssetId).transferFrom(msg.sender, address(this), bd.minAmount);
        }
    }

    function _capture(ILiFi.BridgeData calldata bd) internal {
        _bd = bd;
        _called += 1;
        _lastMsgValue = msg.value;
        _ts = block.timestamp;
    }



    // --- test helpers
    function lastBridgeData() external view returns (ILiFi.BridgeData memory) { return _bd; }
    function called() external view returns (uint256) { return _called; }
    function lastMsgValue() external view returns (uint256) { return _lastMsgValue; }
    function capturedTimestamp() external view returns (uint256) { return _ts; }
}
