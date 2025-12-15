# MaldaNft
[Git Source](https://github.com/malda-protocol/malda-lending/blob/076616677457911e7c8925ff7d5fe2dec2ca1497/src\nft\MaldaNft.sol)

**Inherits:**
ERC721Enumerable, Ownable


## State Variables
### merkleRoot

```solidity
bytes32 public merkleRoot;
```


### hasClaimed

```solidity
mapping(address => mapping(uint256 => bool)) public hasClaimed;
```


### minted

```solidity
mapping(uint256 => bool) public minted;
```


### _nextTokenId

```solidity
uint256 private _nextTokenId;
```


### _baseTokenURI

```solidity
string private _baseTokenURI;
```


## Functions
### constructor


```solidity
constructor(string memory name, string memory symbol, string memory baseURI, address owner)
    ERC721(name, symbol)
    Ownable(owner);
```

### mint


```solidity
function mint(address to, uint256 tokenId) external onlyOwner;
```

### setBaseURI


```solidity
function setBaseURI(string memory baseURI) external onlyOwner;
```

### setMerkleRoot


```solidity
function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner;
```

### canClaim


```solidity
function canClaim(address claimer, uint256 tokenId, bytes32[] calldata merkleProof) external view returns (bool);
```

### claim


```solidity
function claim(uint256 tokenId, bytes32[] calldata merkleProof) external;
```

### transferFrom

*non-transferable*


```solidity
function transferFrom(address, address, uint256) public override(ERC721, IERC721);
```

### safeTransferFrom

*non-transferable*


```solidity
function safeTransferFrom(address, address, uint256, bytes memory) public override(ERC721, IERC721);
```

### _baseURI


```solidity
function _baseURI() internal view override returns (string memory);
```

## Events
### MerkleRootSet

```solidity
event MerkleRootSet(bytes32 merkleRoot);
```

### TokensClaimed

```solidity
event TokensClaimed(address indexed claimer, uint256 indexed tokenIdClaimed);
```

## Errors
### MaldaNft_MerkleRootNotSet

```solidity
error MaldaNft_MerkleRootNotSet();
```

### MaldaNft_InvalidMerkleProof

```solidity
error MaldaNft_InvalidMerkleProof();
```

### MaldaNft_TokenAlreadyMinted

```solidity
error MaldaNft_TokenAlreadyMinted();
```

### MaldaNft_TokenAlreadyClaimed

```solidity
error MaldaNft_TokenAlreadyClaimed();
```

### MaldaNft_TokenNotTransferable

```solidity
error MaldaNft_TokenNotTransferable();
```

