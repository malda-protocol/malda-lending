# IMessageLib
[Git Source](https://github.com/malda-protocol/malda-lending/blob/acd5ab2b6c54b66703c366d922b6691b77a8c9fd/src\interfaces\external\layerzero\v2\IMessageLib.sol)

**Inherits:**
IERC165


## Functions
### setConfig


```solidity
function setConfig(address _oapp, SetConfigParam[] calldata _config) external;
```

### getConfig


```solidity
function getConfig(uint32 _eid, address _oapp, uint32 _configType) external view returns (bytes memory config);
```

### isSupportedEid


```solidity
function isSupportedEid(uint32 _eid) external view returns (bool);
```

### version


```solidity
function version() external view returns (uint64 major, uint8 minor, uint8 endpointVersion);
```

### messageLibType


```solidity
function messageLibType() external view returns (MessageLibType);
```

