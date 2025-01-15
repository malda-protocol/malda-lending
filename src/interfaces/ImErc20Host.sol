// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

interface ImErc20Host {
    // ----------- EVENTS -----------
    /**
     * @notice Emitted when a user updates allowed callers
     */
    event AllowedCallerUpdated(address indexed sender, address indexed caller, bool status);

    /**
     * @notice Emitted when a chain id whitelist status is updated
     */
    event mErc20Host_ChainStatusUpdated(uint32 indexed chainId, bool status);

    /**
     * @notice Emitted when a liquidate operation is executed
     */
    event mErc20Host_LiquidateExternal(
        address indexed msgSender,
        address indexed srcSender,
        address userToLiquidate,
        address receiver,
        address indexed collateral,
        uint32 srcChainId,
        uint256 amount
    );

    /**
     * @notice Emitted when a mint operation is executed
     */
    event mErc20Host_MintExternal(
        address indexed msgSender, address indexed srcSender, address indexed receiver, uint32 chainId, uint256 amount
    );

    /**
     * @notice Emitted when a borrow operation is executed
     */
    event mErc20Host_BorrowExternal(
        address indexed msgSender, address indexed srcSender, uint32 indexed chainId, uint256 amount
    );

    /**
     * @notice Emitted when a repay operation is executed
     */
    event mErc20Host_RepayExternal(
        address indexed msgSender, address indexed srcSender, address indexed position, uint32 chainId, uint256 amount
    );

    /**
     * @notice Emitted when a withdrawal is executed
     */
    event mErc20Host_WithdrawExternal(
        address indexed msgSender, address indexed srcSender, uint32 indexed chainId, uint256 amount
    );

    /**
     * @notice Emitted when a borrow operation is triggered for an extension chain
     */
    event mErc20Host_BorrowOnExternsionChain(address indexed sender, uint32 dstChainId, uint256 amount);

    /**
     * @notice Emitted when a withdraw operation is triggered for an extension chain
     */
    event mErc20Host_WithdrawOnExtensionChain(address indexed sender, uint32 dstChainId, uint256 amount);

    // ----------- ERRORS -----------
    /**
     * @notice Thrown when the chain id is not LINEA
     */
    error mErc20Host_ProofGenerationInputNotValid();

    /**
     * @notice Thrown when the dst chain id is not current chain
     */
    error mErc20Host_DstChainNotValid();

    /**
     * @notice Thrown when the chain id is not LINEA
     */
    error mErc20Host_ChainNotValid();

    /**
     * @notice Thrown when the address is not valid
     */
    error mErc20Host_AddressNotValid();

    /**
     * @notice Thrown when the amount provided is bigger than the available amount`
     */
    error mErc20Host_AmountTooBig();

    /**
     * @notice Thrown when the amount specified is invalid (e.g., zero)
     */
    error mErc20Host_AmountNotValid();

    /**
     * @notice Thrown when the journal data provided is invalid or corrupted
     */
    error mErc20Host_JournalNotValid();

    /**
     * @notice Thrown when caller is not allowed
     */
    error mErc20Host_CallerNotAllowed();

    /**
     * @notice Thrown when caller is not rebalancer
     */
    error mErc20Host_NotRebalancer();

    // ----------- VIEW -----------
    /**
     * @notice Returns if a caller is allowed for sender
     */
    function isCallerAllowed(address sender, address caller) external view returns (bool);

    /**
     * @notice Returns the proof data journal
     */
    function getProofData(uint32[] calldata dstChainId, address[] calldata user) external view returns (bytes memory);

    // ----------- PUBLIC -----------
    /**
     * @notice Extract amount to be used for rebalancing operation
     * @param amount The amount to rebalance
     */
    function extractForRebalancing(uint256 amount) external;

    /**
     * @notice Set caller status for `msg.sender`
     * @param caller The caller address
     * @param status The status to set for `caller`
     */
    function updateAllowedCallerStatus(address caller, bool status) external;

    /**
     * @notice Mints tokens after external verification
     * @param journalData The journal data for minting
     * @param seal The Zk proof seal
     * @param userToLiquidate The position to liquidate
     * @param liquidateAmount The amount to liquidate
     * @param collateral The collateral to seize
     */
    function liquidateExternal(
        bytes calldata journalData,
        bytes calldata seal,
        address userToLiquidate,
        uint256 liquidateAmount,
        address collateral
    ) external;

    /**
     * @notice Mints tokens after external verification
     * @param journalData The journal data for minting
     * @param seal The Zk proof seal
     * @param mintAmount The amount to mint
     * @param receiver The tokens receiver
     */
    function mintExternal(bytes calldata journalData, bytes calldata seal, uint256 mintAmount, address receiver)
        external;

    /**
     * @notice Repays tokens after external verification
     * @param journalData The journal data for repayment
     * @param seal The Zk proof seal
     * @param repayAmount The amount to repay
     * @param position The position to repay for
     */
    function repayExternal(bytes calldata journalData, bytes calldata seal, uint256 repayAmount, address position)
        external;

    /**
     * @notice Initiates a withdraw operation
     * @param amount The amount to withdraw
     * @param dstChainId The destination chain to recieve funds
     */
    function withdrawOnExtension(uint256 amount, uint32 dstChainId) external;

    /**
     * @notice Initiates a withdraw operation
     * @param amount The amount to withdraw
     * @param dstChainId The destination chain to recieve funds
     */
    function borrowOnExtension(uint256 amount, uint32 dstChainId) external;
}
