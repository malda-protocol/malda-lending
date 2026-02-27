// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script} from "forge-std/Script.sol";

import {AuthLibrary} from "script/utils/AuthLibrary.sol";
import {ConfigSetup} from "script/utils/ConfigSetup.sol";
import {DeployerUtil} from "script/utils/DeployerUtil.sol";
import {JsonReader} from "script/utils/JsonReader.sol";
import {Logger} from "script/utils/Logger.sol";

import {IOwnable} from "src/interfaces/IOwnable.sol";

interface IAdmin {
    function setPendingAdmin(address newAdmin) external;
}

interface ISafeModule {
    function setMaster(address newAdmin) external;
    function setGuardian(address guardian) external;
    function setGasGuardian(address guardian) external;
}

/// @title DeployReleaseOwnership
/// @notice Executes isolated post-deploy ownership and role transfer flow
contract DeployReleaseOwnership is Script, ConfigSetup {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct OwnershipConfig {
        bool isHostChain;
        address securityMultisig;
        address operatingMultisig;
        address legacyGuardian;
        address safeModule;
    }

    struct ResolvedContracts {
        address rolesContract;
        address pauser;
        address zkVerifier;
        address blacklister;
        address batchSubmitter;
        address deployer;
        address rewardDistributor;
        address operator;
        address gasHelper;
        address[] hostMarkets;
        address[] extensionMarkets;
        address[] interestModels;
    }

    ////////////////////////////////////////////////////////////
    //                       Constants                        //
    ////////////////////////////////////////////////////////////

    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    string internal constant DEFAULT_CONFIG_PATH = "config/deploy/multi/DeployNewChain.config.json";
    string internal constant DEFAULT_OUTPUT_PATH = "config/deploy/multi/DeployNewChain.output.json";

    string internal constant NS_OWNERSHIP_TRANSFER = "ownershipTransfer";

    string internal constant OUTPUT_RELEASE = "deployNewChain";
    string internal constant OUTPUT_DEPLOYED_CONTRACTS = "deployedContracts";

    bytes32 internal constant ROLE_GUARDIAN_PAUSE = keccak256(bytes("GUARDIAN_PAUSE"));
    bytes32 internal constant ROLE_GUARDIAN_BLACKLIST = keccak256(bytes("GUARDIAN_BLACKLIST"));
    bytes32 internal constant ROLE_GUARDIAN_ORACLE = keccak256(bytes("GUARDIAN_ORACLE"));
    bytes32 internal constant ROLE_CHAINS_MANAGER = keccak256(bytes("CHAINS_MANAGER"));
    bytes32 internal constant ROLE_GUARDIAN_BRIDGE = keccak256(bytes("GUARDIAN_BRIDGE"));
    bytes32 internal constant ROLE_GUARDIAN_RESERVE = keccak256(bytes("GUARDIAN_RESERVE"));
    bytes32 internal constant ROLE_GUARDIAN_SUPPLY_CAP = keccak256(bytes("GUARDIAN_SUPPLY_CAP"));
    bytes32 internal constant ROLE_GUARDIAN_BORROW_CAP = keccak256(bytes("GUARDIAN_BORROW_CAP"));
    bytes32 internal constant ROLE_PAUSE_MANAGER = keccak256(bytes("PAUSE_MANAGER"));
    bytes32 internal constant ROLE_REBALANCER_EOA = keccak256(bytes("REBALANCER_EOA"));
    bytes32 internal constant ROLE_PROOF_FORWARDER = keccak256(bytes("PROOF_FORWARDER"));

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    error MissingDeployedContract(string contractKey);
    error InvalidSecurityMultisig();
    error InvalidOperatingMultisig();
    error InvalidRolesContract();

    ////////////////////////////////////////////////////////////
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    /// @notice Sets default config and output paths for ownership handoff
    constructor() ConfigSetup(DEFAULT_CONFIG_PATH, DEFAULT_OUTPUT_PATH) {}

    ////////////////////////////////////////////////////////////
    //              External / Public Functions               //
    ////////////////////////////////////////////////////////////

    /// @notice Executes ownership transfer flow using default config/output paths
    /// @return success Always true when execution completes
    function run() public virtual returns (bool success) {
        return run(DEFAULT_CONFIG_PATH, DEFAULT_OUTPUT_PATH);
    }

    /// @notice Executes ownership transfer flow using custom config/output paths
    /// @param configPath_ Shared config path
    /// @param outputPath_ Shared output path
    /// @return success Always true when execution completes
    function run(string memory configPath_, string memory outputPath_) public virtual returns (bool success) {
        // Interactions: execute isolated ownership transfer flow
        _runOwnershipTransfer(configPath_, outputPath_);
        return true;
    }

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @notice Executes isolated ownership transfer flow
    /// @param configPath_ Shared config path
    /// @param outputPath_ Shared output path
    function _runOwnershipTransfer(string memory configPath_, string memory outputPath_) internal virtual {
        // Effects: select config and output files for this invocation
        setConfigPath(vm, configPath_);
        setOutputPath(vm, outputPath_);

        // Interactions: load ownership config and grouped deploy output
        string memory configJson = vm.readFile(DeployerUtil.buildAbsolutePath(vm, configPath));
        string memory outputJson = vm.readFile(DeployerUtil.buildAbsolutePath(vm, outputPath));

        // Effects: decode ownership config and resolve deployed contract addresses
        OwnershipConfig memory cfg = _loadOwnershipConfig(configJson, NS_OWNERSHIP_TRANSFER);
        ResolvedContracts memory resolved = _resolveContracts(outputJson, cfg);

        // Requirements: multisig targets must be configured
        require(cfg.securityMultisig != address(0), InvalidSecurityMultisig());
        require(cfg.operatingMultisig != address(0), InvalidOperatingMultisig());

        // Interactions: apply ownership and role transfer transactions
        vm.startBroadcast();
        _executeCommonTransfers(cfg, resolved);
        if (cfg.isHostChain) {
            _executeHostTransfers(cfg, resolved);
        } else {
            _executeExtensionTransfers(cfg, resolved);
        }
        _transferOwnershipIfSet(resolved.rolesContract, cfg.securityMultisig);
        vm.stopBroadcast();

        Logger.logOutputPath(vm, outputPath, false);
    }

    /// @notice Resolves deployed contract addresses from grouped output
    /// @param outputJson Shared output JSON blob
    /// @param cfg Parsed ownership config
    /// @return resolved Resolved contract addresses and market arrays
    function _resolveContracts(string memory outputJson, OwnershipConfig memory cfg)
        internal
        returns (ResolvedContracts memory resolved)
    {
        // Effects: resolve common deployed contract addresses
        resolved.rolesContract = _readAggregatedAddress(outputJson, "roles");
        require(resolved.rolesContract != address(0), InvalidRolesContract());

        resolved.pauser = _readAggregatedAddress(outputJson, "pauser");
        resolved.zkVerifier = _readAggregatedAddress(outputJson, "zkVerifier");
        resolved.blacklister = _readAggregatedAddress(outputJson, "blacklister");
        resolved.batchSubmitter = _readAggregatedAddress(outputJson, "batchSubmitter");

        // Effects: retain optional legacy deployer lookup for compatibility
        resolved.deployer = JsonReader.readAddress(
            outputJson, JsonReader.getPropertyPath(DeployerUtil.DEPLOYED_CONTRACTS_KEY, "Deployer")
        );

        // Effects: resolve host-specific optional contracts and grouped market arrays
        if (cfg.isHostChain) {
            resolved.rewardDistributor = _readAggregatedAddress(outputJson, "rewardDistributor");
            resolved.operator = _readAggregatedAddress(outputJson, "operator");
            resolved.gasHelper = _readAggregatedAddress(outputJson, "gasHelper");
            resolved.hostMarkets = _readAggregatedAddressArray(outputJson, "hostMarkets");
            resolved.interestModels = _readAggregatedAddressArray(outputJson, "interestModels");
            return resolved;
        }

        // Effects: resolve extension-specific market arrays
        resolved.extensionMarkets = _readAggregatedAddressArray(outputJson, "extensionMarkets");
    }

    /// @notice Applies common ownership transfer operations in both host and extension modes
    /// @param cfg Parsed ownership config
    /// @param resolved Resolved contract addresses
    function _executeCommonTransfers(OwnershipConfig memory cfg, ResolvedContracts memory resolved) internal {
        // Interactions: set pending admin on optional deployer proxy
        if (resolved.deployer != address(0)) {
            IAdmin(resolved.deployer).setPendingAdmin(cfg.operatingMultisig);
        }

        // Interactions: transfer ownership on shared contracts
        _transferOwnershipIfSet(resolved.pauser, cfg.securityMultisig);
        _transferOwnershipIfSet(resolved.zkVerifier, cfg.securityMultisig);
        _transferOwnershipIfSet(resolved.blacklister, cfg.securityMultisig);
        _transferOwnershipIfSet(resolved.batchSubmitter, cfg.operatingMultisig);
    }

    /// @notice Applies host-chain specific ownership and role transfers
    /// @param cfg Parsed ownership config
    /// @param resolved Resolved contract addresses
    function _executeHostTransfers(OwnershipConfig memory cfg, ResolvedContracts memory resolved) internal {
        // Interactions: transfer ownership on host-only contracts
        _transferOwnershipIfSet(resolved.rewardDistributor, cfg.operatingMultisig);
        _transferOwnershipIfSet(resolved.operator, cfg.securityMultisig);
        _transferOwnershipIfSet(resolved.gasHelper, cfg.operatingMultisig);

        // Interactions: update proxy admin ownership and interest model ownership
        _transferPendingAdminAndProxyAdmin(resolved.hostMarkets, cfg.securityMultisig);
        _transferOwnershipIfSetAll(resolved.interestModels, cfg.operatingMultisig);

        // Interactions: update optional safe module guardians
        if (cfg.safeModule != address(0)) {
            ISafeModule(cfg.safeModule).setGuardian(cfg.securityMultisig);
            ISafeModule(cfg.safeModule).setGasGuardian(cfg.operatingMultisig);
            ISafeModule(cfg.safeModule).setMaster(cfg.securityMultisig);
        }

        // Interactions: rotate host guardian roles
        _configureHostRoles(resolved.rolesContract, cfg.securityMultisig, cfg.operatingMultisig, cfg.legacyGuardian);
    }

    /// @notice Applies extension-chain specific ownership and role transfers
    /// @param cfg Parsed ownership config
    /// @param resolved Resolved contract addresses
    function _executeExtensionTransfers(OwnershipConfig memory cfg, ResolvedContracts memory resolved) internal {
        // Interactions: transfer ownership + proxy admin for extension markets
        _transferOwnershipAndProxyAdmin(resolved.extensionMarkets, cfg.securityMultisig);

        // Interactions: rotate extension guardian roles
        _configureExtensionRoles(resolved.rolesContract, cfg.securityMultisig, cfg.legacyGuardian);
    }

    /// @notice Loads ownership transfer config from shared config JSON
    /// @param configJson Shared config JSON blob
    /// @param section Config section name
    /// @return cfg Parsed ownership config
    function _loadOwnershipConfig(string memory configJson, string memory section)
        internal
        returns (OwnershipConfig memory cfg)
    {
        // Effects: decode ownership transfer parameters
        cfg.isHostChain = JsonReader.readBool(configJson, JsonReader.getPropertyPath(section, "isHostChain"));
        cfg.securityMultisig =
            JsonReader.readAddress(configJson, JsonReader.getPropertyPath(section, "securityMultisig"));
        cfg.operatingMultisig =
            JsonReader.readAddress(configJson, JsonReader.getPropertyPath(section, "operatingMultisig"));
        cfg.legacyGuardian = JsonReader.readAddress(configJson, JsonReader.getPropertyPath(section, "legacyGuardian"));
        cfg.safeModule = JsonReader.readAddress(configJson, JsonReader.getPropertyPath(section, "safeModule"));
    }

    /// @notice Configures host-chain guardian role assignments
    /// @param rolesContract Roles contract address
    /// @param securityMultisig Security multisig target
    /// @param operatingMultisig Operating multisig target
    /// @param legacyGuardian Legacy guardian to revoke
    function _configureHostRoles(
        address rolesContract,
        address securityMultisig,
        address operatingMultisig,
        address legacyGuardian
    ) internal {
        // Interactions: set security multisig roles
        _setRole(rolesContract, securityMultisig, ROLE_GUARDIAN_PAUSE, true);
        _setRole(rolesContract, securityMultisig, ROLE_GUARDIAN_BLACKLIST, true);
        _setRole(rolesContract, securityMultisig, ROLE_GUARDIAN_ORACLE, true);
        _setRole(rolesContract, securityMultisig, ROLE_CHAINS_MANAGER, true);
        _setRole(rolesContract, securityMultisig, ROLE_GUARDIAN_BRIDGE, true);

        // Interactions: set operating multisig roles
        _setRole(rolesContract, operatingMultisig, ROLE_GUARDIAN_BORROW_CAP, true);
        _setRole(rolesContract, operatingMultisig, ROLE_GUARDIAN_SUPPLY_CAP, true);
        _setRole(rolesContract, operatingMultisig, ROLE_GUARDIAN_RESERVE, true);

        // Interactions: revoke legacy guardian roles
        _setRole(rolesContract, legacyGuardian, ROLE_GUARDIAN_PAUSE, false);
        _setRole(rolesContract, legacyGuardian, ROLE_GUARDIAN_BLACKLIST, false);
        _setRole(rolesContract, legacyGuardian, ROLE_GUARDIAN_ORACLE, false);
        _setRole(rolesContract, legacyGuardian, ROLE_CHAINS_MANAGER, false);
        _setRole(rolesContract, legacyGuardian, ROLE_GUARDIAN_BORROW_CAP, false);
        _setRole(rolesContract, legacyGuardian, ROLE_GUARDIAN_SUPPLY_CAP, false);
        _setRole(rolesContract, legacyGuardian, ROLE_GUARDIAN_RESERVE, false);
        _setRole(rolesContract, legacyGuardian, ROLE_GUARDIAN_BRIDGE, false);
        _setRole(rolesContract, legacyGuardian, ROLE_PAUSE_MANAGER, false);
        _setRole(rolesContract, legacyGuardian, ROLE_REBALANCER_EOA, false);
        _setRole(rolesContract, legacyGuardian, ROLE_PROOF_FORWARDER, false);
    }

    /// @notice Configures extension-chain guardian role assignments
    /// @param rolesContract Roles contract address
    /// @param securityMultisig Security multisig target
    /// @param legacyGuardian Legacy guardian to revoke
    function _configureExtensionRoles(address rolesContract, address securityMultisig, address legacyGuardian)
        internal
    {
        // Interactions: set security multisig roles
        _setRole(rolesContract, securityMultisig, ROLE_GUARDIAN_PAUSE, true);
        _setRole(rolesContract, securityMultisig, ROLE_GUARDIAN_BLACKLIST, true);
        _setRole(rolesContract, securityMultisig, ROLE_GUARDIAN_ORACLE, true);
        _setRole(rolesContract, securityMultisig, ROLE_CHAINS_MANAGER, true);

        // Interactions: revoke legacy guardian roles
        _setRole(rolesContract, legacyGuardian, ROLE_GUARDIAN_PAUSE, false);
        _setRole(rolesContract, legacyGuardian, ROLE_GUARDIAN_BLACKLIST, false);
        _setRole(rolesContract, legacyGuardian, ROLE_GUARDIAN_ORACLE, false);
        _setRole(rolesContract, legacyGuardian, ROLE_CHAINS_MANAGER, false);
        _setRole(rolesContract, legacyGuardian, ROLE_GUARDIAN_RESERVE, false);
        _setRole(rolesContract, legacyGuardian, ROLE_GUARDIAN_BRIDGE, false);
        _setRole(rolesContract, legacyGuardian, ROLE_GUARDIAN_SUPPLY_CAP, false);
        _setRole(rolesContract, legacyGuardian, ROLE_GUARDIAN_BORROW_CAP, false);
        _setRole(rolesContract, legacyGuardian, ROLE_PAUSE_MANAGER, false);
        _setRole(rolesContract, legacyGuardian, ROLE_REBALANCER_EOA, false);
        _setRole(rolesContract, legacyGuardian, ROLE_PROOF_FORWARDER, false);
    }

    /// @notice Grants or revokes a role when both target addresses are configured
    /// @param rolesContract Roles contract address
    /// @param account Account to grant/revoke
    /// @param role Role identifier
    /// @param status True to grant, false to revoke
    function _setRole(address rolesContract, address account, bytes32 role, bool status) internal {
        // Requirements: skip no-op role updates when inputs are unset
        if (rolesContract == address(0) || account == address(0)) {
            return;
        }

        // Interactions: execute role update through AuthLibrary helper
        AuthLibrary.grantRole(rolesContract, account, role, status);
    }

    /// @notice Transfers ownership when both target addresses are configured
    /// @param contractAddress Ownable contract address
    /// @param newOwner New owner address
    function _transferOwnershipIfSet(address contractAddress, address newOwner) internal {
        // Requirements: skip no-op ownership updates when inputs are unset
        if (contractAddress == address(0) || newOwner == address(0)) {
            return;
        }

        // Interactions: execute ownership transfer
        IOwnable(contractAddress).transferOwnership(newOwner);
    }

    /// @notice Transfers ownership for each contract in an array
    /// @param contractAddresses List of contracts
    /// @param newOwner New owner address
    function _transferOwnershipIfSetAll(address[] memory contractAddresses, address newOwner) internal {
        // Interactions: execute ownership transfer for every contract address
        for (uint256 i; i < contractAddresses.length; ++i) {
            _transferOwnershipIfSet(contractAddresses[i], newOwner);
        }
    }

    /// @notice Transfers pending admin on proxies and ownership on their proxy admin contracts
    /// @param proxies List of proxy addresses
    /// @param newOwner New owner / pending admin address
    function _transferPendingAdminAndProxyAdmin(address[] memory proxies, address newOwner) internal {
        // Interactions: set pending admin and transfer proxy admin ownership per proxy
        for (uint256 i; i < proxies.length; ++i) {
            if (proxies[i] == address(0)) {
                continue;
            }

            IAdmin(proxies[i]).setPendingAdmin(newOwner);
            _transferOwnershipIfSet(address(uint160(uint256(vm.load(proxies[i], ADMIN_SLOT)))), newOwner);
        }
    }

    /// @notice Transfers ownership on proxies and their proxy admin contracts
    /// @param proxies List of proxy addresses
    /// @param newOwner New owner address
    function _transferOwnershipAndProxyAdmin(address[] memory proxies, address newOwner) internal {
        // Interactions: transfer proxy ownership and proxy admin ownership per proxy
        for (uint256 i; i < proxies.length; ++i) {
            if (proxies[i] == address(0)) {
                continue;
            }

            _transferOwnershipIfSet(proxies[i], newOwner);
            _transferOwnershipIfSet(address(uint160(uint256(vm.load(proxies[i], ADMIN_SLOT)))), newOwner);
        }
    }

    ////////////////////////////////////////////////////////////
    //                    View / Pure Functions               //
    ////////////////////////////////////////////////////////////

    /// @notice Reads one aggregated deployed address by key
    /// @param outputJson Shared output JSON blob
    /// @param contractKey Key under `deployNewChain.deployedContracts`
    /// @return contractAddress Parsed deployed address
    function _readAggregatedAddress(string memory outputJson, string memory contractKey)
        internal
        view
        returns (address contractAddress)
    {
        // Effects: read one aggregated deployment address
        contractAddress = JsonReader.readAddress(
            outputJson, JsonReader.getPropertyPath(OUTPUT_RELEASE, OUTPUT_DEPLOYED_CONTRACTS, contractKey)
        );

        // Requirements: required deployed contract should exist in grouped output
        require(contractAddress != address(0), MissingDeployedContract(contractKey));
    }

    /// @notice Reads one aggregated deployed address array by key
    /// @param outputJson Shared output JSON blob
    /// @param contractKey Key under `deployNewChain.deployedContracts`
    /// @return contractAddresses Parsed deployed addresses
    function _readAggregatedAddressArray(string memory outputJson, string memory contractKey)
        internal
        view
        returns (address[] memory contractAddresses)
    {
        // Effects: read one aggregated deployment address array
        contractAddresses = JsonReader.readAddressArray(
            outputJson, JsonReader.getPropertyPath(OUTPUT_RELEASE, OUTPUT_DEPLOYED_CONTRACTS, contractKey)
        );
    }
}
