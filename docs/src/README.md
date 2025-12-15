# About Malda Protocol

Malda Protocol solves the fragmentation problem in DeFi by creating a unified lending experience across multiple EVM networks. The protocol enables users to:
- Access lending markets across different L2s as if they were a single network
- Unified liquidity and interest rates across all chains
- Execute lending operations across chains without bridging or wrapping assets
- Maintain full control of their funds in a self-custodial manner

# About this repository 

This repository contains the source for the onchain Solidity components required to run Malda, the first DeFi protocol built in the Risc Zero zkVM. 
These critical components serve multiple function within the Malda application: 
- Secure protocol ledger onchain
- Execute UserOps leveraging proofs generated mwith the malda-zk-coprocessor component
- Provides an entry point for users from multiple underlying chains leveraging mTokenGateway contract
