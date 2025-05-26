// // SPDX-License-Identifier: UNLICENSED
// pragma solidity =0.8.28;

// import {Script, console} from "forge-std/Script.sol";
// import {BatchSubmitter} from "src/mToken/BatchSubmitter.sol";
// import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
// import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
// import {Roles} from "src/Roles.sol";
// import {Operator} from "src/operator/Operator.sol";
// import {RewardDistributor} from "src/rewards/RewardDistributor.sol";
// import {MixedPriceOracleV3} from "src/oracles/MixedPriceOracleV3.sol";
// import {IDefaultAdapter} from "src/interfaces/IDefaultAdapter.sol";

// contract VerifyDeployment is Script {
//     error VerificationFailed(string reason);

//     // Hardcoded values from deployment-config.json
//     address constant OWNER = 0xCde13fF278bc484a09aDb69ea1eEd3cAf6Ea4E00;
//     bytes32 constant IMAGE_ID = 0x1000000000000000000000000000000000000000000000000000000000000000;
//     uint256 constant STALENESS_PERIOD = 86400;

//     // Linea Sepolia (Host Chain)
//     uint32 constant LINEA_CHAIN_ID = 59141;
//     address constant LINEA_USDC = 0xFEce4462D57bD51A6A552365A011b95f0E16d9B7;
//     address constant LINEA_WETH = 0x06565ed324Ee9fb4DB0FF80B7eDbE4Cb007555a3;
//     address constant LINEA_USDC_FEED = 0xA5c24F2449891483f0923f0D9dC7694BDFe1bC86;
//     address constant LINEA_WETH_FEED = 0x2D6261dce927D5c46f7f393a897887F19F3fDf2A;
//     address constant LINEA_VERIFIER = 0x27983ee173aD10E171D17C9c5C14d5baFE997609;

//     // OP Sepolia
//     uint32 constant OP_CHAIN_ID = 11155420;
//     address constant OP_USDC = 0x5fd84259d66Cd46123540766Be93DFE6D43130D7;
//     address constant OP_WETH = 0x4200000000000000000000000000000000000006;
//     address constant OP_VERIFIER = 0xB369b4dd27FBfb59921d3A4a3D23AC2fc32FB908;

//     // Sepolia
//     uint32 constant SEPOLIA_CHAIN_ID = 11155111;
//     address constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
//     address constant SEPOLIA_WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
//     address constant SEPOLIA_VERIFIER = 0x925d8331ddc0a1F0d96E68CF073DFE1d92b69187;

//     // Market Parameters for Linea (Host)
//     uint256 constant USDC_BORROW_CAP = 1000000000000;
//     uint256 constant USDC_SUPPLY_CAP = 1000000000000;
//     uint256 constant USDC_COLLATERAL_FACTOR = 800000000000000000;
//     uint256 constant USDC_BORROW_RATE_MAX = 500000000000000000;

//     uint256 constant WETH_BORROW_CAP = 1000000000000000000000;
//     uint256 constant WETH_SUPPLY_CAP = 1000000000000000000000;
//     uint256 constant WETH_COLLATERAL_FACTOR = 750000000000000000;
//     uint256 constant WETH_BORROW_RATE_MAX = 500000000000000000;

//     // Interest Model Parameters
//     uint256 constant USDC_BASE_RATE = 20000000000000000;
//     uint256 constant USDC_MULTIPLIER = 100000000000000000;
//     uint256 constant USDC_JUMP_MULTIPLIER = 500000000000000000;
//     uint256 constant USDC_KINK = 800000000000000000;

//     uint256 constant WETH_BASE_RATE = 10000000000000000;
//     uint256 constant WETH_MULTIPLIER = 80000000000000000;
//     uint256 constant WETH_JUMP_MULTIPLIER = 400000000000000000;
//     uint256 constant WETH_KINK = 900000000000000000;

//     function run() public {
//         // Verify Linea Sepolia (Host)
//         vm.createSelectFork(vm.rpcUrl("linea_sepolia"));
//         _verifyLineaSepoliaDeployment(operator);

//         // Verify OP Sepolia
//         vm.createSelectFork(vm.rpcUrl("op_sepolia"));
//         _verifyOpSepoliaDeployment();

//         // Verify Sepolia
//         vm.createSelectFork(vm.rpcUrl("sepolia"));
//         _verifySepoliaDeployment();
//     }

//     function _verifyLineaSepoliaDeployment() internal {
//         console.log("\n=== Verifying Linea Sepolia Deployment ===");

//         // Verify Common Components
//         _verifyRoles();
//         _verifyBatchSubmitter(LINEA_VERIFIER);

//         // Verify Oracle
//         address oracle = _getDeployedAddress("MixedPriceOracleV3");
//         // _verifyOracle(oracle);

//         // Verify Operator
//         address operator = _getDeployedAddress("Operator");
//         _verifyOperator(operator, oracle);

//         // Verify RewardDistributor
//         address rewardDistributor = _getDeployedAddress("RewardDistributor");
//         _verifyRewardDistributor(rewardDistributor, operator);

//         // Verify USDC Market
//         address mUSDC = _getDeployedAddress("mUSDC");
//         _verifyHostMarket(
//             mUSDC, LINEA_USDC, USDC_BORROW_CAP, USDC_SUPPLY_CAP, USDC_COLLATERAL_FACTOR, USDC_BORROW_RATE_MAX, operator
//         );

//         // Verify WETH Market
//         address mWETH = _getDeployedAddress("mWETH");
//         _verifyHostMarket(
//             mWETH, LINEA_WETH, WETH_BORROW_CAP, WETH_SUPPLY_CAP, WETH_COLLATERAL_FACTOR, WETH_BORROW_RATE_MAX, operator
//         );

//         // Verify Allowed Chains
//         _verifyAllowedChains(mUSDC);
//         _verifyAllowedChains(mWETH);
//     }

//     function _verifyOpSepoliaDeployment() internal {
//         console.log("\n=== Verifying OP Sepolia Deployment ===");

//         // Verify Common Components
//         _verifyRoles();
//         _verifyBatchSubmitter(OP_VERIFIER);

//         // Verify USDC Gateway
//         address mUSDC = _getDeployedAddress("mUSDC");
//         _verifyGatewayMarket(mUSDC, OP_USDC);

//         // Verify WETH Gateway
//         address mWETH = _getDeployedAddress("mWETH");
//         _verifyGatewayMarket(mWETH, OP_WETH);
//     }

//     function _verifySepoliaDeployment() internal {
//         console.log("\n=== Verifying Sepolia Deployment ===");

//         // Verify Common Components
//         _verifyRoles();
//         _verifyBatchSubmitter(SEPOLIA_VERIFIER);

//         // Verify USDC Gateway
//         address mUSDC = _getDeployedAddress("mUSDC");
//         _verifyGatewayMarket(mUSDC, SEPOLIA_USDC);

//         // Verify WETH Gateway
//         address mWETH = _getDeployedAddress("mWETH");
//         _verifyGatewayMarket(mWETH, SEPOLIA_WETH);
//     }

//     function _verifyRoles() internal {
//         address rolesAddr = _getDeployedAddress("Roles");
//         Roles roles = Roles(rolesAddr);

//         // Verify CHAINS_MANAGER role
//         bytes32 role = keccak256("CHAINS_MANAGER");
//         if (!roles.isAllowedFor(OWNER, role)) {
//             revert VerificationFailed("CHAINS_MANAGER role not set");
//         }
//     }

//     function _verifyBatchSubmitter(address verifier) internal {
//         address batchSubmitterAddr = _getDeployedAddress("BatchSubmitter");
//         BatchSubmitter batchSubmitter = BatchSubmitter(batchSubmitterAddr);

//         if (batchSubmitter.owner() != OWNER) {
//             revert VerificationFailed("BatchSubmitter owner mismatch");
//         }
//         if (batchSubmitter.imageId() != IMAGE_ID) {
//             revert VerificationFailed("BatchSubmitter imageId mismatch");
//         }
//         if (address(batchSubmitter.verifier()) != verifier) {
//             revert VerificationFailed("BatchSubmitter verifier mismatch");
//         }
//     }

//     // function _verifyOracle(address oracle) internal {
//     //     MixedPriceOracleV3 priceOracle = MixedPriceOracleV3(oracle);

//     //     if (address(priceOracle.roles()) != _getDeployedAddress("Roles")) {
//     //         revert VerificationFailed("Oracle roles mismatch");
//     //     }
//     //     if (priceOracle.STALENESS_PERIOD() != STALENESS_PERIOD) {
//     //         revert VerificationFailed("Oracle staleness period mismatch");
//     //     }

//     //     IDefaultAdapter.PriceConfig memory usdcConfig = priceOracle.configs("mUSDC");
//     //     IDefaultAdapter.PriceConfig memory wethConfig = priceOracle.configs("mWETH");

//     //     if (usdcConfig.defaultFeed != LINEA_USDC_FEED) {
//     //         revert VerificationFailed("Oracle mUSDC feed mismatch");
//     //     }
//     //     if (wethConfig.defaultFeed != LINEA_WETH_FEED) {
//     //         revert VerificationFailed("Oracle mWETH feed mismatch");
//     //     }
//     //     if (usdcConfig.toSymbol != "USD") {
//     //         revert VerificationFailed("Oracle mUSDC toSymbol mismatch");
//     //     }
//     //     if (wethConfig.toSymbol != "USD") {
//     //         revert VerificationFailed("Oracle mWETH toSymbol mismatch");
//     //     }
//     //     if (usdcConfig.underlyingDecimals != 6) {
//     //         revert VerificationFailed("Oracle mUSDC underlyingDecimals mismatch");
//     //     }
//     //     if (wethConfig.underlyingDecimals != 18) {
//     //         revert VerificationFailed("Oracle mWETH underlyingDecimals mismatch");
//     //     }
//     // }

//     function _verifyOperator(address operator, address oracle) internal {
//         Operator op = Operator(operator);

//         if (op.owner() != OWNER) {
//             revert VerificationFailed("Operator owner mismatch");
//         }
//         if (address(op.oracle()) != oracle) {
//             revert VerificationFailed("Operator oracle mismatch");
//         }
//     }

//     function _verifyRewardDistributor(address rewardDistributor, address operator) internal {
//         RewardDistributor distributor = RewardDistributor(rewardDistributor);

//         if (distributor.owner() != OWNER) {
//             revert VerificationFailed("RewardDistributor owner mismatch");
//         }
//         if (distributor.operator() != operator) {
//             revert VerificationFailed("RewardDistributor operator mismatch");
//         }
//     }

//     function _verifyHostMarket(
//         address market,
//         address underlying,
//         uint256 borrowCap,
//         uint256 supplyCap,
//         uint256 collateralFactor,
//         uint256 borrowRateMax,
//         address operator
//     ) internal {
//         mErc20Host mToken = mErc20Host(market);

//         if (mToken.owner() != OWNER) {
//             revert VerificationFailed("Market owner mismatch");
//         }
//         if (mToken.underlying() != underlying) {
//             revert VerificationFailed("Market underlying mismatch");
//         }
//         if (mToken.borrowCap() != borrowCap) {
//             revert VerificationFailed("Market borrow cap mismatch");
//         }
//         if (mToken.supplyCap() != supplyCap) {
//             revert VerificationFailed("Market supply cap mismatch");
//         }
//         if (Operator(operator).getCollateralFactor(market) != collateralFactor) {
//             revert VerificationFailed("Market collateral factor mismatch");
//         }
//         if (mToken.borrowRateMaxMantissa() != borrowRateMax) {
//             revert VerificationFailed("Market borrow rate max mismatch");
//         }
//         if (mToken.imageId() != IMAGE_ID) {
//             revert VerificationFailed("Market imageId mismatch");
//         }
//     }

//     function _verifyGatewayMarket(address market, address underlying) internal {
//         mTokenGateway gateway = mTokenGateway(market);

//         if (gateway.owner() != OWNER) {
//             revert VerificationFailed("Gateway owner mismatch");
//         }
//         if (gateway.underlying() != underlying) {
//             revert VerificationFailed("Gateway underlying mismatch");
//         }
//         if (gateway.imageId() != IMAGE_ID) {
//             revert VerificationFailed("Gateway imageId mismatch");
//         }
//     }

//     function _verifyAllowedChains(address market) internal {
//         mErc20Host mToken = mErc20Host(market);

//         if (!mToken.isChainAllowed(OP_CHAIN_ID)) {
//             revert VerificationFailed("OP chain not allowed");
//         }
//         if (!mToken.isChainAllowed(SEPOLIA_CHAIN_ID)) {
//             revert VerificationFailed("Sepolia chain not allowed");
//         }
//     }

//     function _getDeployedAddress(string memory name) internal view returns (address) {
//         bytes32 salt = keccak256(abi.encodePacked(msg.sender, bytes("FirstTry"), bytes(string.concat(name, "-v1"))));
//         // Note: Replace with actual deployer contract address and logic
//         return address(0); // Placeholder
//     }
// }
