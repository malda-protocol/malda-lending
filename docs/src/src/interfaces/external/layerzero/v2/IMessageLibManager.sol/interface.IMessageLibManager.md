# IMessageLibManager
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\interfaces\external\layerzero\v2\IMessageLibManager.sol)


## Functions
### registerLibrary


```solidity
function registerLibrary(address _lib) external;
```

### isRegisteredLibrary


```solidity
function isRegisteredLibrary(address _lib) external view returns (bool);
```

### getRegisteredLibraries


```solidity
function getRegisteredLibraries() external view returns (address[] memory);
```

### setDefaultSendLibrary


```solidity
function setDefaultSendLibrary(uint32 _eid, address _newLib) external;
```

### defaultSendLibrary


```solidity
function defaultSendLibrary(uint32 _eid) external view returns (address);
```

### setDefaultReceiveLibrary


```solidity
function setDefaultReceiveLibrary(uint32 _eid, address _newLib, uint256 _gracePeriod) external;
```

### defaultReceiveLibrary


```solidity
function defaultReceiveLibrary(uint32 _eid) external view returns (address);
```

### setDefaultReceiveLibraryTimeout


```solidity
function setDefaultReceiveLibraryTimeout(uint32 _eid, address _lib, uint256 _expiry) external;
```

### defaultReceiveLibraryTimeout


```solidity
function defaultReceiveLibraryTimeout(uint32 _eid) external view returns (address lib, uint256 expiry);
```

### isSupportedEid


```solidity
function isSupportedEid(uint32 _eid) external view returns (bool);
```

### isValidReceiveLibrary


```solidity
function isValidReceiveLibrary(address _receiver, uint32 _eid, address _lib) external view returns (bool);
```

### setSendLibrary

------------------- OApp interfaces -------------------


```solidity
function setSendLibrary(address _oapp, uint32 _eid, address _newLib) external;
```

### getSendLibrary


```solidity
function getSendLibrary(address _sender, uint32 _eid) external view returns (address lib);
```

### isDefaultSendLibrary


```solidity
function isDefaultSendLibrary(address _sender, uint32 _eid) external view returns (bool);
```

### setReceiveLibrary


```solidity
function setReceiveLibrary(address _oapp, uint32 _eid, address _newLib, uint256 _gracePeriod) external;
```

### getReceiveLibrary


```solidity
function getReceiveLibrary(address _receiver, uint32 _eid) external view returns (address lib, bool isDefault);
```

### setReceiveLibraryTimeout


```solidity
function setReceiveLibraryTimeout(address _oapp, uint32 _eid, address _lib, uint256 _expiry) external;
```

### receiveLibraryTimeout


```solidity
function receiveLibraryTimeout(address _receiver, uint32 _eid) external view returns (address lib, uint256 expiry);
```

### setConfig


```solidity
function setConfig(address _oapp, address _lib, SetConfigParam[] calldata _params) external;
```

### getConfig


```solidity
function getConfig(address _oapp, address _lib, uint32 _eid, uint32 _configType)
    external
    view
    returns (bytes memory config);
```

## Events
### LibraryRegistered

```solidity
event LibraryRegistered(address newLib);
```

### DefaultSendLibrarySet

```solidity
event DefaultSendLibrarySet(uint32 eid, address newLib);
```

### DefaultReceiveLibrarySet

```solidity
event DefaultReceiveLibrarySet(uint32 eid, address newLib);
```

### DefaultReceiveLibraryTimeoutSet

```solidity
event DefaultReceiveLibraryTimeoutSet(uint32 eid, address oldLib, uint256 expiry);
```

### SendLibrarySet

```solidity
event SendLibrarySet(address sender, uint32 eid, address newLib);
```

### ReceiveLibrarySet

```solidity
event ReceiveLibrarySet(address receiver, uint32 eid, address newLib);
```

### ReceiveLibraryTimeoutSet

```solidity
event ReceiveLibraryTimeoutSet(address receiver, uint32 eid, address oldLib, uint256 timeout);
```

## Structs
### Timeout

```solidity
struct Timeout {
    address lib;
    uint256 expiry;
}
```

