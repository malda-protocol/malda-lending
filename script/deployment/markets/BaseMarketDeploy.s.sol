// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {DeployBase} from "script/deployers/DeployBase.sol";

abstract contract BaseMarketDeploy is Script, DeployBase {}
