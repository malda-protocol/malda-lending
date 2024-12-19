// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

// interfaces
import {IERC20} from "@openzeppelin/contracts-0.8.19/token/ERC20/IERC20.sol";
import {ERC721} from "@openzeppelin/contracts-0.8.19/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts-0.8.19/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts-0.8.19/utils/Strings.sol";

contract GovernanceRound is ERC721, Ownable {
    using Strings for uint256;

    // ----------- STATE VARIABLES ------------

    /// @notice The USDC token contract
    IERC20 public immutable usdc;

    /// @notice The operator of the round
    address immutable operator;

    /// @notice Minimum investment amount (10 USDC = 10 * 10^6)
    uint256 public constant MINIMUM_DEPOSIT = 10 * 1e4;

    /// @notice Deposit amount for each token ID
    mapping(uint256 => uint256) public deposits;

    uint256 public nextTokenId;

    bool public roundOpen;

    // ----------- EVENTS ------------

    event DepositMade(address indexed depositor, uint256 indexed tokenId, uint256 amount);

    // ----------- ERRORS ------------

    error GovernanceRound_MinimumDepositNotMet();
    error GovernanceRound_TransferFailed();
    error GovernanceRound_RoundClosed();
    error GovernanceRound_CallerIsNotOperator();

    /**
     * @notice Initialize the governance round
     * @param usdc_ The USDC token contract address
     * @param operator_ The operator of the round
     */
    constructor(address usdc_, address owner_, address operator_) ERC721("Malda Governance Round Deposit", "MGRD") Ownable() {
        usdc = IERC20(usdc_);
        operator = operator_;
        transferOwnership(owner_);
    }

    // ----------- EXTERNAL FUNCTIONS ------------

    /**     
     * @notice Deposit USDC and mint an NFT
     * @param amount The amount of USDC to deposit
     * @return tokenId The ID of the minted NFT
     */
    function deposit(uint256 amount) external returns (uint256) {
        if (!roundOpen) revert GovernanceRound_RoundClosed();
        if (amount < MINIMUM_DEPOSIT) revert GovernanceRound_MinimumDepositNotMet();

        bool success = usdc.transferFrom(msg.sender, address(this), amount);
        if (!success) revert GovernanceRound_TransferFailed();

        return _createDeposit(amount);
    }

    /**
     * @notice Withdraw collected USDC (only owner)
     * @param amount Amount of USDC to withdraw
     */
    function withdraw(uint256 amount) external onlyOwner {
        bool success = usdc.transfer(owner(), amount);
        if (!success) revert GovernanceRound_TransferFailed();
    }

    function openRound() external {
        if (msg.sender != operator) revert GovernanceRound_CallerIsNotOperator();
        roundOpen = true;
    }

    /**
     * @notice Close the round (only operator)
     */
    function closeRound() external {
        if (msg.sender != operator) revert GovernanceRound_CallerIsNotOperator();
        roundOpen = false;
    }


    /**
     * @notice Get the deposit amount for a token ID
     * @param tokenId The ID of the token
     * @return The deposit amount
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        ownerOf(tokenId);
        return string.concat("deposit_amount: ", deposits[tokenId].toString());
    }

    // ----------- INTERNAL FUNCTIONS ------------

    /**
     * @notice Create deposit record and mint NFT
     * @param amount The amount of USDC deposited
     * @return tokenId The ID of the minted NFT
     */
    function _createDeposit(uint256 amount) internal returns (uint256) {
        uint256 newTokenId = nextTokenId;
        nextTokenId++;

        deposits[newTokenId] = amount;

        _mint(msg.sender, newTokenId);

        emit DepositMade(msg.sender, newTokenId, amount);

        return newTokenId;
    }

    
}
