# IZkVerifier
[Git Source](https://github.com/malda-protocol/malda-lending/blob/034fc0e2fca466a96bdb4527b71e15ddea321646/src/verifier/ZkVerifier.sol)

**Author:**
Malda Protocol

Minimal interface to verify a Risc0 proof


## Functions
### verifyInput

Verify the provided Risc0 journal/seal pair


```solidity
function verifyInput(bytes calldata journalEntry, bytes calldata seal) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalEntry`|`bytes`|The Risc0 journal entry|
|`seal`|`bytes`|The proof seal|


