# Malda Lending Protocol – Technical Overview

Malda is a modern lending protocol enhanced with cross-chain capabilities using zk-coprocessor proofs (Risc0) and extension gateways for remote execution. It retains core economic primitives of a secure lending protocol, while introducing **mTokenHost / mTokenGateway** pairs for **cross-chain liquidity and borrowing**.


----------

## 🔧 Core Components

### Operator

####  Purpose

The **Operator** contract is the central authority that governs markets, collateral factors, account liquidity, liquidation thresholds, and policy enforcement (who can mint, redeem, borrow, repay etc).

The **Operator** serves as the protocol’s risk management layer, enforcing collateral requirements and determining liquidation conditions. It evaluates each user’s position to decide the necessary collateral and the extent of possible liquidation. Every time a user interacts with an **mToken**, the **Operator** assesses and approves or rejects the transaction.

It interacts with **mTokens**, **IPriceOracle**, and **IInterestRateModel** to ensure the stability and security of the platform.


####  Responsibilities

-   Market listing and pausing
-   Setting risk parameters (collateral factor, liquidation incentive, caps)
-   Computing account liquidity and shortfall
-   Authorizing mints, redeems, borrows, repayments, liquidations
-   Disable/Enable whitelist
-   Define outflow volume time and value limits (outflow volume defines the maximum amount of tokens that can go through sequencer between a specified time window)
-   Compute each user's account liquidity or shortfall (determine how much a user can borrow based on their supplied assets and collateral factors)
    
The following **Operator** methods act as notification/trigger for various mToken lending operations
```solidity
function beforeMTokenTransfer(address mToken, address src, address dst, uint256 transferTokens) external;    

function beforeMTokenMint(address mToken, address minter) external;    

function afterMTokenMint(address mToken) external view;    

function beforeMTokenRedeem(address mToken, address redeemer, uint256 redeemTokens) external;    

function beforeMTokenBorrow(address mToken, address borrower, uint256 borrowAmount) external;    

function beforeMTokenRepay(address mToken, address borrower) external;    

function beforeMTokenLiquidate(
    address mTokenBorrowed,        
    address mTokenCollateral,        
    address borrower,        
    uint256 repayAmount
) external view;    

function beforeMTokenSeize(address mTokenCollateral, address mTokenBorrowed, address liquidator, address borrower) external;
```
As mentioned, **Operator** acts  as a guardian for the `mToken` contract. Below is a list of methods created for this purpose:

```solidity
  function rolesOperator() external view returns (IRoles);    
  
  function oracleOperator() external view returns (address);    
  
  function closeFactorMantissa() external view returns (uint256);    
  
  function liquidationIncentiveMantissa() external view returns (uint256);    
  
  function getAssetsIn(address _user) external view returns (address[] memory mTokens);    
  
  function getAllMarkets() external view returns (address[] memory mTokens);    
  
  function borrowCaps(address _mToken) external view returns (uint256);    
  
  function supplyCaps(address _mToken) external view returns (uint256);    
  
  function rewardDistributor() external view returns (address);
```

----------

### mErc20Host 

This contract represents a lending market on the **host chain** (Linea).
The **mErc20Host** contract extends **mErc20Upgradeable** and provides cross-chain money market functionalities using zk-proof verification. It interacts with **mTokenProofDecoderLib** for proof decoding and adheres to **ImErc20Host** interface.

####  Purpose

-   Accept deposits
-   Issue mTokens (Malda interest-bearing tokens)
-   Track underlying balance and user shares
-   Uses `IRoles` contract for role-based permissioning.
-   Uses `ZkVerifier` to verify proof data before allowing withdrawals. This is using `Risc0` libraries under the hood (Steel)
-   Admin and specific roles (example: `GUARDIAN_PAUSE`, `REBALANCER`, `PROOF_FORWARDER`) can perform privileged actions.
-   Support mint/redeem/borrow/repay on the **local chain**
	   ```solidity
		function mint(uint256 mintAmount) external; 
		function redeem(uint256 redeemTokens) external; 
		function redeemUnderlying(uint256 redeemAmount) external; 
		function borrow(uint256 borrowAmount) external; 
		function repay(uint256 repayAmount) external; 
		function repayBehalf(address borrower, uint256 repayAmount) external; 
		function liquidate(address borrower, uint256 repayAmount, address mTokenCollateral) external; 
		function addReserves(uint256 addAmount) external;
	```
-   Validate and execute **zk-coprocessor proofs** for cross-chain operations
	- **Accumulated{}** struct tracks cumulative deposits and withdrawals per user and chain. Both the **mTokenGateway** (described in next section) and **mErc20Host** markets accumulate **amountsIn** and **amountsOut** per user. Whenever there’s a supply operation performed, the **amountsIn** is increased. That means that when the proof is submitted on the destination chain the proof was generated for it checks the difference between received **amountIn** and that chain’s registered **amountIn**. This difference represents the maximum amount the user can use for operations tied to an **amountIn** flow, like **mint**, **repay**, **liquidate**.
	
	-  **Cross-chain ZK operations**: Accepts proof inputs from the zk-coprocessor that attest a valid state transition from another chain. Once verified, calls local internal methods to:
		```solidity
		function  liquidateExternal
		function  mintExternal
		function  repayExternal    
		```
	-   **Remote borrowing/withdrawal**: Via `performExtensionCall`; this contract emits an event or performs outbound call intended to be picked up by the sequencer to the destination chain.


**mToken** amount is computed according to the following formula `(mTokenBalance* exchangeRate / 10^18 / 10^(underlying token decimals)) * underlying_price`. The `underlying_price`  is retrieved from`MixedPriceOracleV3` oracle implementation
  
----------

### mTokenGateway (Extension Market)

This contract mirrors the `mTokenHost`, but lives on an **extension chain**. 
The `mTokenGateway` contract serves as a gateway for handling token operations similar to the `mErc20Host` contract. It’s the extensions (not Linea) chains’ equivalent of a market.

It has support for role-based access control, proof verification, and cross-chain interactions. It manages deposits, withdrawals, and caller permissions while ensuring security through zero-knowledge (ZK) proof validation.

You can think of the `mTokenGateway` as a small version of a market or a market’s gateway as the only important operations this is handling are: supplying tokens or withdrawing tokens.

####  Unique Behavior

-   Doesn’t store full balance logic — that lives in the Host
-   All actual capital sits on the host chain
-   Exposes simplified interface for supply type actions which are only valid once settled on the host chain
-  Uses `IRoles` contract for role-based permissioning.
-  Uses `ZkVerifier` to verify proof data before allowing withdrawals. This is using `risc0` libraries under the hood (Steel)

```solidity
function supplyOnHost(uint256 amount, bytes4 lineaSelector) external override notPaused(OperationType.AmountIn)
function outHere(bytes calldata journalData, bytes calldata seal, uint256 amount, address receiver)

``` 
When funds are supplied `accAmountIn` is increased. This is part of the proof generated with `getProofData`

```solidity
    /**     
    * @inheritdoc ImTokenGateway     
    */    
    function getProofData(address user) external view returns (bytes memory) {
        return mTokenProofDecoderLib.encodeJournal(
            user, address(this), accAmountIn[user], accAmountOut[user], uint32(block.chainid), LINEA_CHAIN_ID
        );    
    }
```

The `mTokenProofDecoderLib` is performing an `abi.encodePacked `operation on the data provided and uses `BytesLib` for the decode operation.
```solidity
return abi.encodePacked(sender, market, accAmountIn, accAmountOut, chainId, dstChainId);
```

----------

## 🔁 Cross-Chain Flow

Malda Protocol solves the fragmentation problem in DeFi by creating a unified lending experience across multiple EVM networks. The protocol enables users to:

-   Access lending markets across different L2s as if they were a single network
    
-   Unified liquidity and interest rates across all chains
    
-   Execute lending operations across chains without bridging or wrapping assets
    
-   Maintain full control of their funds in a self-custodial manner

### Extension to Host (Deposit / Proof Flow)

1.  User deposits tokens into `mTokenGateway` (extension).
    
2.  Extension records this and updates its internal state hash.
    
3.  ZK coprocessor (Risc0) proves this transition off-chain.
    
4.  Proof is sent to `mErc20Host`, which verifies it.
    
5.  Host mints (or any other supply type action allowed by the host contract) tokens for the user and updates supply.
    

### Host to Extension (Withdraw / Borrow Flow)

1.  User initiates `borrow` or `withdraw` on `mErc20Host` using `performExtensionCall` method.
    
2.  Contract emits a cross-chain event / message.
    
3.  The sequencer picks up the message.
    
4.  `mTokenGateway` finalizes the borrow or redeem action.
    


### ZK Coprocessor Proof Validation

The `ZkVerifier` contract is an abstract contract designed to facilitate the verification of zero-knowledge proofs using the Risc0 framework. It manages a verifier contract instance, an image ID, and provides methods for verifying inputs based on cryptographic proofs. Uses Steel to verify a proof

The following code illustrates how a verification performed:

```solidity
  function __verify(bytes calldata journalEntry, bytes calldata seal) private view {
      verifier.verify(seal, imageId, sha256(journalEntry));
  }
```

Proofs are generated using `getProofData()` calls available on `mTokenGateway` and `mErc20Host` contracts. A proof consists of the following fields:

-   the user for which the proof is generated for; `user`
-   the market address the proof is intended to be used for; `market`
-   the accumulated amount in for user on the current chain the proof is generated on; `accAmountIn[user]`
-   the accumulated amount out for user on the current chain the proof is generated on; `accAmountOut[user]`
-   the current chain id in uint32 format; `uint32(block.chainid)`
-   the destination chain id in uint32 format; `LINEA_CHAIN_ID`

The above fields are part of the `mTokenGateway` proof. The difference between `getProofData()` from `mTokenGateway` and `getProofData()` from `mErc20Host` contract is that the host call also needs the destination chain id to generate the proof for. This is skipped on `mTokenGateway` as the destination is always Linea, defined by `LINEA_CHAIN_ID`
```solidity
    uint32 private constant LINEA_CHAIN_ID = 59144;
```
 Security is enforced by requiring **proof verification** before state updates.
 
Users have the ability to self-sequence the transactions for themselves, in case of Sequencer failure or if they wish to do it for themselves.


###  BatchSubmitter

The `BatchSubmitter` contract facilitates batch processing of multiple operations in a single transaction. It uses zk-proof verification by implementing the Steel library and interacts with `mErc20Host` and `mTokenGateway` contracts to execute minting, repaying and withdrawing.

```solidity
    bytes4 internal constant MINT_SELECTOR = ImErc20Host.mintExternal.selector;
    bytes4 internal constant REPAY_SELECTOR = ImErc20Host.repayExternal.selector;
    bytes4 internal constant OUT_HERE_SELECTOR = ImTokenGateway.outHere.selector;
```

----------

### Pauser 

The `Pauser` contract provides emergency pause functionality for market operations within the lending protocol. It allows the owner and authorized roles to pause individual or all market operations in case of an emergency. The contract maintains a registry of pausable markets and their types, enabling controlled break of operations.

The `Pauser` acts as a guardian for pausable contracts. It can be integrated with solutions like `Hypernative` to emergency pause 1 operation of a market, the entire market or even all pausable contracts in 1 tx.

```solidity
// pause a market entirely    
function emergencyPauseMarket(address _market) external;
      
// pause a specific operation for a market    
function emergencyPauseMarketFor(address _market, OperationType _pauseType) external;        
        
// pause everything configured in the Pauser contract    
function emergencyPauseAll() external;
```

----------
### Interest Model

#### Borrow APR

The interest rate model for borrowed assets can be calculated using the following formula:
```solidity
= Base + Multiplier * min(UtilizationRate, Kink) + max(JumpMultiplier * UtilizationRate - Kink, 0)
```

#### Supply APR
The interest rate model for supplying assets can be calculated using the following formula:
= Distribute (Interest Paid by Borrowers Per Block - Reserve) to all suppliers, and convert it into APY

```solidity
`= Distribute [(1 + Borrow APY) ^ (1 / BlocksPerYear) - 1] * Total Borrow * (1 - Reserve Factor)` to all suppliers, and convert it into APY

`= {[(1 + Borrow APY) ^ (1 / BlocksPerYear) - 1] * Total Borrow * (1 - Reserve Factor) / Total Supply}`, and convert it into APY

`= {1 + [(1 + Borrow APY) ^ (1/BlocksPerYear) - 1] * Total Borrow * (1 - Reserve Factor) / Total Supply} ^ BlocksPerYear - 1`
```
Using the same interest model as Mendi: [https://docs.mendi.finance/protocol/interest-rate-model](https://docs.mendi.finance/protocol/interest-rate-model)

----------
###  Rebalancer

The `Rebalancer` contract is responsible for managing liquidity rebalancing across different markets and chains. It ensures that funds can be transferred securely using whitelisted bridge contracts while maintaining a log of all rebalancing messages.

It extracts funds from `mTokenGateway` or `mErc20Host` contracts and sends to another layer, to the same market, using an implemented `IBridge` .

The rebalancing module continuously monitors borrow activity on Malda and other money markets, chains’ inflows and outflows, and additional metrics to forecast future borrow demand per chain to rebalance token balances across chains.

The expected borrow demand for a token on a chain is forecasted based on a linear regression of the borrow demand over the last 7 days. If forecasts are shown to be inaccurate, other formulas will be used to minimize the observed delta.

Additional signals include deviations in general borrow demand on other money markets or outliers of chain inflows/outflows.

```solidity
  // retrieve amounts (make sure to check min and max for that bridge)  IRebalanceMarket(_market).extractForRebalancing(_amount);  ...  IBridge(_bridge).sendMsg{value: msg.value}(_msg.dstChainId, _msg.token, _msg.message, _msg.bridgeData);
```

#### Key aspects:

-   Manages whitelisted bridge contracts
-   Sends messages for rebalancing across chains
-   Ensures only authorized addresses can perform rebalancing operations
-   Logs rebalancing messages to maintain a history
-   Ensures only authorized roles can modify bridge whitelisting and initiate rebalancing.
-   Prevents unauthorized token transfers by checking `_underlying` matches `_msg.token`.
-   Uses `SafeApprove` to mitigate token approval risks.

##### Across bridge (IBridge)

The `AccrossBridge` contract facilitates cross-chain liquidity transfers using the Across protocol. It extends `BaseBridge` and implements `IBridge` . It integrates with the Across Spoke Pool for cross-chain transfers.

##### Everclear bridge (IBridge)

The `EverclearBridge` contract enables cross-chain liquidity transfers using the Everclear protocol. It extends `BaseBridge` and implements `IBridge` . It integrates with `IEverclearSpoke` to send cross-chain liquidity.
Implements `getFee` to estimate transfer costs.

----------

###  Deployer

The `Deployer` contract is responsible for deploying other smart contracts using CREATE3. It allows an admin to create contracts deterministically, retrieve precomputed addresses, and manage contract deployment permissions.

**Key aspects:**

-   Uses `CREATE3` to deploy contracts deterministically
-   Allows the admin to precompute contract addresses
-   Provides mechanisms for transferring ETH stored in the contract
-   Enables admin role management

The `Deployer` contract will be deployed using CREATE2 on multiple chains. The following is similar to the CREATE3Factory contract, except that it’s protected by admin role.

`CREATE3` is implemented by the following library:

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Bytes32AddressLib} from "./Bytes32AddressLib.sol";

/// @notice Deploy to deterministic addresses without an initcode factor.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/CREATE3.sol)
/// @author Modified from 0xSequence (https://github.com/0xSequence/create3/blob/master/contracts/Create3.sol)
library CREATE3 {
    using Bytes32AddressLib for bytes32;

    //--------------------------------------------------------------------------------//
    // Opcode     | Opcode + Arguments    | Description      | Stack View             //
    //--------------------------------------------------------------------------------//
    // 0x36       |  0x36                 | CALLDATASIZE     | size                   //
    // 0x3d       |  0x3d                 | RETURNDATASIZE   | 0 size                 //
    // 0x3d       |  0x3d                 | RETURNDATASIZE   | 0 0 size               //
    // 0x37       |  0x37                 | CALLDATACOPY     |                        //
    // 0x36       |  0x36                 | CALLDATASIZE     | size                   //
    // 0x3d       |  0x3d                 | RETURNDATASIZE   | 0 size                 //
    // 0x34       |  0x34                 | CALLVALUE        | value 0 size           //
    // 0xf0       |  0xf0                 | CREATE           | newContract            //
    //--------------------------------------------------------------------------------//
    // Opcode     | Opcode + Arguments    | Description      | Stack View             //
    //--------------------------------------------------------------------------------//
    // 0x67       |  0x67XXXXXXXXXXXXXXXX | PUSH8 bytecode   | bytecode               //
    // 0x3d       |  0x3d                 | RETURNDATASIZE   | 0 bytecode             //
    // 0x52       |  0x52                 | MSTORE           |                        //
    // 0x60       |  0x6008               | PUSH1 08         | 8                      //
    // 0x60       |  0x6018               | PUSH1 18         | 24 8                   //
    // 0xf3       |  0xf3                 | RETURN           |                        //
    //--------------------------------------------------------------------------------//
    bytes internal constant PROXY_BYTECODE = hex"67363d3d37363d34f03d5260086018f3";

    bytes32 internal constant PROXY_BYTECODE_HASH = keccak256(PROXY_BYTECODE);

    function deploy(bytes32 salt, bytes memory creationCode, uint256 value) internal returns (address deployed) {
        bytes memory proxyChildBytecode = PROXY_BYTECODE;

        address proxy;
        assembly {
            // Deploy a new contract with our pre-made bytecode via CREATE2.
            // We start 32 bytes into the code to avoid copying the byte length.
            proxy := create2(0, add(proxyChildBytecode, 32), mload(proxyChildBytecode), salt)
        }
        require(proxy != address(0), "DEPLOYMENT_FAILED");

        deployed = getDeployed(salt);
        (bool success,) = proxy.call{value: value}(creationCode);
        require(success && deployed.code.length != 0, "INITIALIZATION_FAILED");
    }

    function getDeployed(bytes32 salt) internal view returns (address) {
        address proxy = keccak256(abi.encodePacked(bytes1(0xFF), address(this), salt, PROXY_BYTECODE_HASH))
            // Prefix:
            // Creator:
            // Salt:
            // Bytecode hash:
            .fromLast20Bytes();

        return keccak256(abi.encodePacked(hex"d694", proxy, hex"01")) // Nonce of the proxy contract (1)
            // 0xd6 = 0xc0 (short RLP prefix) + 0x16 (length of: 0x94 ++ proxy ++ 0x01)
            // 0x94 = 0x80 + 0x14 (0x14 = the length of an address, 20 bytes, in hex)
            .fromLast20Bytes();
    }
}

```

----------

### 🚀 Dev Onboarding & Recipes

Malda has multiple new use cases and advantages compared to traditional architecture:

-   Ability to use 1 (!) money market as a DeFi bank to manage all investments through the major rollups of the Ethereum ecosystem
    
-   Seamless arbitrage across chains with borrowed funds between DEXs
    
-   Easy and convenient user-experience without needing to disrupt user flow to bridge between chains.
    
-   Quick access to investment opportunity with the ability to borrow or withdraw on supported chains instantaneously.
    
-   Easy migration and access for Ethereum Mainnet liquidity to major rollups
    
-   Scale and Depth - Currently legacy lending models suffer fragmented liquidity and it is dependent on the underlying chain the quality of the service they can provide. Malda removes this limitation and provides the full depth of liquidity to all served markets, increasing capital efficiency and fostering meaningful economic growth in the Ethereum ecosystem.

Besides the more complex scenarios, Malda allows simple ones as:

#### Deploy a new market
- Deploy mErc20Host  and configure (collateral, reserve factors etc)
- Deploy mTokenGateway and configure (collateral, reserve factors etc)
- Register market in Operator
- Configure interest rate model, oracle, and caps
- Assign roles using IRoles

#### Minting mTokens

To deposit funds and receive interest-bearing mTokens:

- Approve the mToken contract to spend your underlying token:
```solidity
IERC20(underlying).approve(mErc20Host, amount);

```
- Mint mTokens by calling
```solidity
mErc20Host.mint(amount, receiver, minAmountOut);
```

#### Borrowing assets
To borrow assets from the protocol (requires sufficient collateral):

-  Ensure you've minted mTokens of another market as collateral.
    
- Call the borrow function:
```solidity
mErc20Host.borrow(borrowAmount);
```

#### Repaying loans

To repay borrowed assets:

-  Repay your own loan
```solidity
IERC20(underlying).approve(mErc20Host, repayAmount);
mErc20Host.repay(repayAmount);
```
-  Repay for another user:
```solidity
IERC20(underlying).approve(mErc20Host, repayAmount);
mErc20Host.repayBehalf(borrowerAddress, repayAmount);
```

#### Redeeming tokens
To withdraw your supplied collateral:

-   Redeem by token amount:
```solidity
mErc20Host.redeem(mTokenAmount);
```
-   Redeem by underlying value:
```solidity
mErc20Host.redeemUnderlying(underlyingAmount);
```

#### Liquidating undercollateralized users

If a user’s borrow exceeds their allowed collateral threshold, you can liquidate their position:

```solidity
mErc20Host.liquidate(borrower, repayAmount, mTokenCollateral);
```
#### Borrow/Withdraw on extension chains

To borrow or redeem on an extension chain, the action initiated on host is:

```solidity
function  performExtensionCall(uint256  actionType, uint256  amount, uint32  dstChainId) external  payable
```

where `actionType` is: 1-borrow, 2-withdraw

#### Supply from extension
By supplying on an extension chains you are able to liquidate, mint or repay on host (this is automatically performed by the Sequencer)
```solidity
function  supplyOnHost(uint256  amount, address  receiver, bytes4  lineaSelector)
```
---

### Deployed contracts

#### Testnet
Deployed on Linea sepolia (host), Sepolia and OP Sepolia

| Name | Address  |
|--|--|
| Deployer| 0x7aFcD811e32a9F221B72502bd645d4bAa56a375a|
| Roles| 0x3dc52279175EE96b6A60f6870ec4DfA417c916E3|
| ZkVerifier| 0xF3CA3C7018eA139E8B3969FF64DafDa8DF946B31|
| BatchSubmitter| 0xC03155E29276841Bc5D27653c57fb85FA6043C65|
| GasHelper | 0x3aE44aC156557D30f58E38a6796336E7eD0A3fC1|
| RewardDistributor| 0x837D67e10C0E91B58568582154222EDF4357D58E|
| MixedPriceOracleV4| 0xAc028838DaF18FAD0F69a1a1e143Eb8a29b04904|
| Operator| 0x389cc3D08305C3DaAf19B2Bf2EC7dD7f66D68dA8|
| Pauser| 0x4EC99a994cC51c03d67531cdD932f231385f9618|
| mUSDCMock| 0x76daf584Cbf152c85EB2c7Fe7a3d50DaF3f5B6e6|
| mUSDCMock Interest| 0xfe2E9AB5c7b759CaeA320578844Deae1b696eb32|
| mwstETHMock| 0xD4286cc562b906589f8232335413f79d9aD42f7E|
| mwstETHMock Interest| 0x10589A75f6D84B932613633831fdE1A4b5945930|

#### Mainnet

| Name | Address  | Chains
|--|--|--|
| Deployer| | |
| Roles| | |
| ZkVerifier| | |
| BatchSubmitter| | |
| GasHelper | | |
| RewardDistributor| | |
| MixedPriceOracleV4| | |
| Operator| | |
| Pauser| | |
| mUSDCMock| | |
| mUSDCMock Interest| | |
| mwstETHMock| | |
| mwstETHMock Interest| | |





---

### Deployment Architecture

#### Chains Involved

-   **Host Chain**: Linea (primary liquidity resides here)
    
-   **Extension Chains**: L2s or sidechains like Base, Arbitrum, etc. 
    

### Deployment Patterns

- Deterministic deployment via `CREATE3`
- ZK proof verification via Risc0 and `Steel` ensures valid cross-chain operations

---

### Roles and permissions

Pause & Security Management  
```solidity
    PAUSE_MANAGER – Manages pausing functionality across contracts via the Pauser contract. Required for calling addPausableMarket
    GUARDIAN_PAUSE – Can pause markets by calling setPaused on mTokenGateway and mErc20Host
```

Market Configuration  
```solidity
    GUARDIAN_BORROW_CAP – Can set borrow limits on mTokenGateway and mErc20Host. Required for setMarketBorrowCaps
    GUARDIAN_SUPPLY_CAP – Can set supply limits on mTokenGateway and mErc20Host. Required for setMarketSupplyCaps
    GUARDIAN_ORACLE – Can configure the oracle by calling .setConfig. Required for `setConfig
    GUARDIAN_BRIDGE – Can whitelist bridges on Rebalancer.sol and configure IBridge contracts
```
Proofs  
```solidity
    PROOF_BATCH_FORWARDER – Roles used in BatchSubmitter to enable batch submission of proofs, typically assigned to the relayer
```
Reserve & Rebalancing  
```solidity
    GUARDIAN_RESERVE – Can call reduceReserve on mErc20Host
    REBALANCER_EOA – Authorized to call sendMsg on Rebalancer.sol to trigger rebalancing
    REBALANCER – Must be assigned to the Rebalancer.sol contract for operational functionality 
```
Cross-Chain Management  
```solidity
    CHAINS_MANAGER – Can update the list of allowed destination chains on mErc20Host. Required for calling updateAllowedChain
```

---

## Quickstart

### Requirements

- Foundry
- Node.js 18+
- RPC endpoints and explorer API keys in `.env`

### Setup

```bash
cp .env.example .env
forge install
npm install
```

### Verify Build and Tests

```bash
make test
```

## Maintained Scope

- Core lending contracts under `src/`
- Rebalancer integrations under `src/rebalancer/`
- Deployment and operational scripts under `script/`
- Foundry tests under `test/`

## Audit Status

- This repository includes historical security reports in `audit/`.
- Audit coverage is point-in-time and should not be treated as blanket coverage for all current commits.
- Any changes introduced after a report date should be considered unaudited until re-reviewed.

## Disclaimer

- This codebase is provided as-is, without warranty of safety, fitness, or production readiness.
- Integrators are responsible for independent review, threat modeling, and production hardening.
- Deployment and governance configuration choices can materially change risk.

## Known Limitations

- Cross-chain flows rely on external infrastructure and bridge assumptions not fully controlled by this repository.
- Runtime safety depends on correct role assignment and parameterization during deployment.
- Script and config correctness is operationally critical and may require environment-specific adaptation.

## Unresolved Issues

- Open pull requests are intentionally left unchanged in this cleanup pass and require manual triage.
- Security and architecture documentation should be refreshed after any substantial protocol or deployment changes.
