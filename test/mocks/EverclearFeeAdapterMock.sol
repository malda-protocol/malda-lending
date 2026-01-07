// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {IFeeAdapter} from "src/interfaces/external/everclear/IFeeAdapter.sol";
import {IFeeAdapterV2} from "src/interfaces/external/everclear/IFeeAdapterV2.sol";

contract EverclearFeeAdapterMock is IFeeAdapter {
    bytes32 public nextId = keccak256("everclear.intent");

    uint32[] public lastDestinations;
    bytes32 public lastReceiver;
    address public lastInputAsset;
    bytes32 public lastOutputAsset;
    uint256 public lastAmount;
    uint24 public lastMaxFee;
    uint48 public lastTtl;
    bytes public lastData;
    FeeParams public lastFeeParams;
    uint256 public callCount;

    function setNextId(bytes32 id) external {
        nextId = id;
    }

    function newIntent(
        uint32[] memory _destinations,
        bytes32 _receiver,
        address _inputAsset,
        bytes32 _outputAsset,
        uint256 _amount,
        uint24 _maxFee,
        uint48 _ttl,
        bytes calldata _data,
        FeeParams calldata _feeParams
    ) external payable returns (bytes32 _intentId, Intent memory _intent) {
        callCount++;
        lastDestinations = _destinations;
        lastReceiver = _receiver;
        lastInputAsset = _inputAsset;
        lastOutputAsset = _outputAsset;
        lastAmount = _amount;
        lastMaxFee = _maxFee;
        lastTtl = _ttl;
        lastData = _data;
        lastFeeParams = _feeParams;

        return (nextId, _intent);
    }
}

contract EverclearFeeAdapterV2Mock is IFeeAdapterV2 {
    bytes32 public nextId = keccak256("everclear.v2.intent");

    uint32[] public lastDestinations;
    bytes32 public lastReceiver;
    address public lastInputAsset;
    bytes32 public lastOutputAsset;
    uint256 public lastAmount;
    uint256 public lastAmountOutMin;
    uint48 public lastTtl;
    bytes public lastData;
    FeeParams public lastFeeParams;
    uint256 public callCount;

    function setNextId(bytes32 id) external {
        nextId = id;
    }

    function newIntent(
        uint32[] memory _destinations,
        bytes32 _receiver,
        address _inputAsset,
        bytes32 _outputAsset,
        uint256 _amount,
        uint256 _amountOutMin,
        uint48 _ttl,
        bytes calldata _data,
        FeeParams calldata _feeParams
    ) external payable returns (bytes32 _intentId, Intent memory _intent) {
        callCount++;
        lastDestinations = _destinations;
        lastReceiver = _receiver;
        lastInputAsset = _inputAsset;
        lastOutputAsset = _outputAsset;
        lastAmount = _amount;
        lastAmountOutMin = _amountOutMin;
        lastTtl = _ttl;
        lastData = _data;
        lastFeeParams = _feeParams;

        return (nextId, _intent);
    }
}
