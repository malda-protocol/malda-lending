# Bytes32AddressLib
[Git Source](https://github.com/malda-protocol/malda-lending/blob/6ea8fcbab45a04b689cc49c81c736245cab92c98/src\libraries\Bytes32AddressLib.sol)

**Author:**
Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/Bytes32AddressLib.sol)

Library for converting between addresses and bytes32 values.


## Functions
### fromLast20Bytes


```solidity
function fromLast20Bytes(bytes32 bytesValue) internal pure returns (address);
```

### fillLast12Bytes


```solidity
function fillLast12Bytes(address addressValue) internal pure returns (bytes32);
```

