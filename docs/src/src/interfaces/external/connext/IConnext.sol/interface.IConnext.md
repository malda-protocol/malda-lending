# IConnext
[Git Source](https://github.com/malda-protocol/malda-lending/blob/157d7bccdcadcb7388d89b00ec47106a82e67e78/src\interfaces\external\connext\IConnext.sol)


## Functions
### xcall


```solidity
function xcall(
    uint32 _destination,
    address _to,
    address _asset,
    address _delegate,
    uint256 _amount,
    uint256 _slippage,
    bytes calldata _callData
) external payable returns (bytes32);
```

### xcall


```solidity
function xcall(
    uint32 _destination,
    address _to,
    address _asset,
    address _delegate,
    uint256 _amount,
    uint256 _slippage,
    bytes calldata _callData,
    uint256 _relayerFee
) external returns (bytes32);
```

### xcallIntoLocal


```solidity
function xcallIntoLocal(
    uint32 _destination,
    address _to,
    address _asset,
    address _delegate,
    uint256 _amount,
    uint256 _slippage,
    bytes calldata _callData
) external payable returns (bytes32);
```

### domain


```solidity
function domain() external view returns (uint256);
```

