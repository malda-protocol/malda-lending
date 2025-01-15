// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Pauser} from "src/pauser/Pauser.sol";
import {Script} from "forge-std/Script.sol";
import {DeployBase} from "script/deployers/DeployBase.sol";

import {DeployRbac} from "script/deployment/generic/DeployRbac.s.sol";
import {DeployUnit} from "script/deployment/generic/DeployUnit.s.sol";
import {DeployPauser} from "script/deployment/generic/DeployPauser.s.sol";
import {DeployOperator} from "script/deployment/markets/DeployOperator.s.sol";
import {DeployHostMarket} from "script/deployment/markets/host/DeployHostMarket.s.sol";
import {DeployJumpRateModelV4} from "script/deployment/interest/DeployJumpRateModelV4.s.sol";
import {DeployChainlinkOracle} from "script/deployment/oracles/DeployChainlinkOracle.s.sol";
import {DeployRewardDistributor} from "script/deployment/rewards/DeployRewardDistributor.s.sol";

/**
 * forge script DeployEverything  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --sig "run((uint256,string,uint256,uint256,uint256,uint256,address,uint256,string,string,uint8,address))" "(750000000000000000,'ExampleName',2102400,20000000000000000,100000000000000000,500000000000000000,0xD718826bBC28e61dC93aaCaE04711c8e755B4915,,20000000000000000,'Name','Sym',18,0x62def138a240b86dd44048b9e7dcc01b6391e638)"  \
 *     --broadcast
 */
contract DeployEverything is Script, DeployBase {
    DeployRbac deployRbac;
    DeployUnit deployUnit;
    DeployPauser deployPauser;
    DeployHostMarket deployHost;
    DeployOperator deployOperator;
    DeployChainlinkOracle deployOracle;
    DeployJumpRateModelV4 deployInterest;
    DeployRewardDistributor deployRewards;

    struct DeployData {
        // Interest data
        uint256 kink;
        string interestName;
        uint256 blocksPerYear;
        uint256 baseRatePerYear;
        uint256 multiplierPerYear;
        uint256 jumpMultiplierPerYear;
        // Host market data
        address underlyingToken;
        uint256 exchangeRateMantissa;
        string name;
        string symbol;
        uint8 decimals;
        address zkVerifier;
    }

    function setUp() public override {
        deployRbac = new DeployRbac();
        deployUnit = new DeployUnit();
        deployPauser = new DeployPauser();
        deployHost = new DeployHostMarket();
        deployOperator = new DeployOperator();
        deployOracle = new DeployChainlinkOracle();
        deployInterest = new DeployJumpRateModelV4();
        deployRewards = new DeployRewardDistributor();
        super.setUp();
        deployHost.setUp();
        deployRbac.setUp();
        deployUnit.setUp();
        deployOracle.setUp();
        deployPauser.setUp();
        deployRewards.setUp();
        deployInterest.setUp();
        deployOperator.setUp();
    }

    function run(DeployData memory data) public {
        address roles = deployRbac.run();
        address interestModel = deployInterest.run(_dataToInterestData(data));
        address defaultOracle = deployOracle.run();
        address defaultRewards = deployRewards.run();
        address operator = deployOperator.run(defaultOracle, defaultRewards, roles);
        deployPauser.run(roles, operator);
        deployHost.run(_dataToHostMarketData(data, operator, interestModel, roles));
    }

    function _dataToInterestData(DeployData memory data)
        private
        pure
        returns (DeployJumpRateModelV4.InterestData memory)
    {
        return DeployJumpRateModelV4.InterestData({
            kink: data.kink,
            name: data.interestName,
            blocksPerYear: data.blocksPerYear,
            baseRatePerYear: data.baseRatePerYear,
            multiplierPerYear: data.multiplierPerYear,
            jumpMultiplierPerYear: data.jumpMultiplierPerYear
        });
    }

    function _dataToHostMarketData(DeployData memory data, address operator, address interestModel, address roles)
        private
        pure
        returns (DeployHostMarket.MarketData memory)
    {
        return DeployHostMarket.MarketData({
            underlyingToken: data.underlyingToken,
            operator: operator,
            interestModel: interestModel,
            exchangeRateMantissa: data.exchangeRateMantissa,
            name: data.name,
            symbol: data.symbol,
            decimals: data.decimals,
            zkVerifier: data.zkVerifier,
            roles: roles
        });
    }
}
