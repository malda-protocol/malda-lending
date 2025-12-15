# StorageSlot
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/3408a5de0b7e9a81798e0551731f955e891c66df/src\utils\StorageSlot.sol)

*Library for reading and writing primitive types to specific storage slots.
Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
This library helps with reading and writing to such slots without the need for inline assembly.
The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
Example usage to set ERC-1967 implementation slot:
```solidity
contract ERC1967 {
// Define the slot. Alternatively, use the SlotDerivation library to derive the slot.
bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
function _getImplementation() internal view returns (address) {
return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
}
function _setImplementation(address newImplementation) internal {
require(newImplementation.code.length > 0);
StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
}
}
```
Since version 5.1, this library also support writing and reading value types to and from transient storage.
Example using transient storage:
```solidity
contract Lock {
// Define the slot. Alternatively, use the SlotDerivation library to derive the slot.
bytes32 internal constant _LOCK_SLOT = 0xf4678858b2b588224636b8522b729e7722d32fc491da849ed75b3fdf3c84f542;
modifier locked() {
require(!_LOCK_SLOT.asBoolean().tload());
_LOCK_SLOT.asBoolean().tstore(true);
_;
_LOCK_SLOT.asBoolean().tstore(false);
}
}
```
TIP: Consider using this library along with {SlotDerivation}.*


## Functions
### getAddressSlot

*Returns an `AddressSlot` with member `value` located at `slot`.*


```solidity
function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r);
```

### getBooleanSlot

*Returns a `BooleanSlot` with member `value` located at `slot`.*


```solidity
function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r);
```

### getBytes32Slot

*Returns a `Bytes32Slot` with member `value` located at `slot`.*


```solidity
function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r);
```

### getUint256Slot

*Returns a `Uint256Slot` with member `value` located at `slot`.*


```solidity
function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r);
```

### getInt256Slot

*Returns a `Int256Slot` with member `value` located at `slot`.*


```solidity
function getInt256Slot(bytes32 slot) internal pure returns (Int256Slot storage r);
```

### getStringSlot

*Returns a `StringSlot` with member `value` located at `slot`.*


```solidity
function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r);
```

### getStringSlot

*Returns an `StringSlot` representation of the string storage pointer `store`.*


```solidity
function getStringSlot(string storage store) internal pure returns (StringSlot storage r);
```

### getBytesSlot

*Returns a `BytesSlot` with member `value` located at `slot`.*


```solidity
function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r);
```

### getBytesSlot

*Returns an `BytesSlot` representation of the bytes storage pointer `store`.*


```solidity
function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r);
```

### asAddress

*Cast an arbitrary slot to a AddressSlotType.*


```solidity
function asAddress(bytes32 slot) internal pure returns (AddressSlotType);
```

### asBoolean

*Cast an arbitrary slot to a BooleanSlotType.*


```solidity
function asBoolean(bytes32 slot) internal pure returns (BooleanSlotType);
```

### asBytes32

*Cast an arbitrary slot to a Bytes32SlotType.*


```solidity
function asBytes32(bytes32 slot) internal pure returns (Bytes32SlotType);
```

### asUint256

*Cast an arbitrary slot to a Uint256SlotType.*


```solidity
function asUint256(bytes32 slot) internal pure returns (Uint256SlotType);
```

### asInt256

*Cast an arbitrary slot to a Int256SlotType.*


```solidity
function asInt256(bytes32 slot) internal pure returns (Int256SlotType);
```

### tload

*Load the value held at location `slot` in transient storage.*


```solidity
function tload(AddressSlotType slot) internal view returns (address value);
```

### tstore

*Store `value` at location `slot` in transient storage.*


```solidity
function tstore(AddressSlotType slot, address value) internal;
```

### tload

*Load the value held at location `slot` in transient storage.*


```solidity
function tload(BooleanSlotType slot) internal view returns (bool value);
```

### tstore

*Store `value` at location `slot` in transient storage.*


```solidity
function tstore(BooleanSlotType slot, bool value) internal;
```

### tload

*Load the value held at location `slot` in transient storage.*


```solidity
function tload(Bytes32SlotType slot) internal view returns (bytes32 value);
```

### tstore

*Store `value` at location `slot` in transient storage.*


```solidity
function tstore(Bytes32SlotType slot, bytes32 value) internal;
```

### tload

*Load the value held at location `slot` in transient storage.*


```solidity
function tload(Uint256SlotType slot) internal view returns (uint256 value);
```

### tstore

*Store `value` at location `slot` in transient storage.*


```solidity
function tstore(Uint256SlotType slot, uint256 value) internal;
```

### tload

*Load the value held at location `slot` in transient storage.*


```solidity
function tload(Int256SlotType slot) internal view returns (int256 value);
```

### tstore

*Store `value` at location `slot` in transient storage.*


```solidity
function tstore(Int256SlotType slot, int256 value) internal;
```

## Structs
### AddressSlot

```solidity
struct AddressSlot {
    address value;
}
```

### BooleanSlot

```solidity
struct BooleanSlot {
    bool value;
}
```

### Bytes32Slot

```solidity
struct Bytes32Slot {
    bytes32 value;
}
```

### Uint256Slot

```solidity
struct Uint256Slot {
    uint256 value;
}
```

### Int256Slot

```solidity
struct Int256Slot {
    int256 value;
}
```

### StringSlot

```solidity
struct StringSlot {
    string value;
}
```

### BytesSlot

```solidity
struct BytesSlot {
    bytes value;
}
```

