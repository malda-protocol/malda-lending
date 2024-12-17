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

contract InvestmentContract is ERC721, Ownable {
    // ----------- STATE VARIABLES ------------

    /// @notice The USDC token contract
    IERC20 public immutable usdc;

    /// @notice Minimum investment amount (10 USDC = 10 * 10^6)
    uint256 public constant MINIMUM_INVESTMENT = 10 * 1e6;

    /// @notice Investment amount for each token ID
    mapping(uint256 => uint256) public investments;

    uint256 public nextTokenId;

    bool public investmentRoundClosed;

    // ----------- EVENTS ------------

    event InvestmentMade(address indexed investor, uint256 indexed tokenId, uint256 amount);

    // ----------- ERRORS ------------

    error InvestmentContract_MinimumInvestmentNotMet();
    error InvestmentContract_TransferFailed();
    error InvestmentContract_InvestmentRoundClosed();
    /**
     * @notice Initialize the investment contract
     * @param usdc_ The USDC token contract address
     * @param owner_ The owner of the contract
     */

    constructor(address usdc_, address owner_) ERC721("Malda Governance Round Investment", "MGRI") Ownable(owner_) {
        usdc = IERC20(usdc_);
    }

    // ----------- EXTERNAL FUNCTIONS ------------

    /**
     * @notice Create a new investment and mint an NFT
     * @param amount The amount of USDC to invest
     * @return tokenId The ID of the minted NFT
     */
    function invest(uint256 amount) external returns (uint256) {
        require(!investmentRoundClosed, InvestmentContract_InvestmentRoundClosed());
        require(amount >= MINIMUM_INVESTMENT, InvestmentContract_MinimumInvestmentNotMet());

        bool success = usdc.transferFrom(msg.sender, address(this), amount);
        require(success, InvestmentContract_TransferFailed());

        return _createInvestment(amount);
    }

    /**
     * @notice Withdraw collected USDC (only owner)
     * @param amount Amount of USDC to withdraw
     */
    function withdraw(uint256 amount) external onlyOwner {
        bool success = usdc.transfer(owner(), amount);
        require(success, InvestmentContract_TransferFailed());
    }

    /**
     * @notice Close the investment round (only owner)
     */
    function closeInvestmentRound() external onlyOwner {
        investmentRoundClosed = true;
    }

    // ----------- INTERNAL FUNCTIONS ------------

    /**
     * @notice Create investment record and mint NFT
     * @param amount The amount of USDC invested
     * @return tokenId The ID of the minted NFT
     */
    function _createInvestment(uint256 amount) internal returns (uint256) {
        uint256 newTokenId = nextTokenId;
        nextTokenId++;

        investments[newTokenId] = amount;

        _mint(msg.sender, newTokenId);

        emit InvestmentMade(msg.sender, newTokenId, amount);

        return newTokenId;
    }
}
