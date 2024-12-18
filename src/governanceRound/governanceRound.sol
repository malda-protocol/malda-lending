// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

// interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract GovernanceRound is ERC721, Ownable {
    using Strings for uint256;

    // ----------- STATE VARIABLES ------------

    /// @notice The USDC token contract
    IERC20 public immutable usdc;

    /// @notice The operator of the round
    address immutable operator;

    /// @notice Minimum investment amount (10 USDC = 10 * 10^6)
    uint256 public constant MINIMUM_DEPOSIT = 10 * 1e6;

    /// @notice Deposit amount for each token ID
    mapping(uint256 => uint256) public deposits;

    uint256 public nextTokenId;

    bool public roundClosed;

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
     * @param owner_ The owner of the contract
     * @param operator_ The operator of the round
     */
    constructor(address usdc_, address owner_, address operator_) ERC721("Malda Governance Round Deposit", "MGRD") Ownable(owner_) {
        usdc = IERC20(usdc_);
        operator = operator_;
    }

    // ----------- EXTERNAL FUNCTIONS ------------

    /**     
     * @notice Deposit USDC and mint an NFT
     * @param amount The amount of USDC to deposit
     * @return tokenId The ID of the minted NFT
     */
    function deposit(uint256 amount) external returns (uint256) {
        require(!roundClosed, GovernanceRound_RoundClosed());
        require(amount >= MINIMUM_DEPOSIT, GovernanceRound_MinimumDepositNotMet());

        bool success = usdc.transferFrom(msg.sender, address(this), amount);
        require(success, GovernanceRound_TransferFailed());

        return _createDeposit(amount);
    }

    /**
     * @notice Withdraw collected USDC (only owner)
     * @param amount Amount of USDC to withdraw
     */
    function withdraw(uint256 amount) external onlyOwner {
        bool success = usdc.transfer(owner(), amount);
        require(success, GovernanceRound_TransferFailed());
    }

    /**
     * @notice Close the round (only operator)
     */
    function closeRound() external {
        require(msg.sender == operator, GovernanceRound_CallerIsNotOperator());
        roundClosed = true;
    }


    /**
     * @notice Get the deposit amount for a token ID
     * @param tokenId The ID of the token
     * @return The deposit amount
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
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
