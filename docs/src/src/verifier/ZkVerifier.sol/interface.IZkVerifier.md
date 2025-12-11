# IZkVerifier
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/verifier/ZkVerifier.sol)

**Title:**
Zero-knowledge verifier interface

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


