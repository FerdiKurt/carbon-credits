// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ICarbonCredits.sol";
import "./interfaces/Errors.sol";


/**
* @title CarbonCreditMarketplaceERC20
* @dev Marketplace for trading carbon credits with USDC and USDT payment options
* @notice This contract allows users to list and purchase carbon credits using stablecoins
*/
contract CarbonCreditMarketplaceERC20 is ReentrancyGuard, Errors {
    using SafeERC20 for IERC20;
    
    ICarbonCredits public carbonCredits;
    IERC20 public usdc;
    IERC20 public usdt;
    
    /**
    * @notice Structure representing a carbon credit listing
    * @dev Used to store all information about a carbon credit listing
    */
    struct Listing {
        address seller;
        uint256 tokenId;
        uint256 amount;
        uint256 pricePerCredit;
        address paymentToken; // Address of the payment token (USDC or USDT)
        bool active;
    }
    
    uint256 private _listingIdCounter;
    mapping(uint256 => Listing) public listings;
    
    // Platform fee settings
    uint256 public platformFeePercentage; // Fee percentage (in basis points, 100 = 1%)
    address public feeCollector;
    
    event ListingCreated(
        uint256 indexed listingId, 
        uint256 indexed tokenId, 
        address indexed seller, 
        uint256 amount, 
        uint256 pricePerCredit, 
        address paymentToken
    );
    event ListingCancelled(uint256 indexed listingId);
    event CreditsPurchased(
        uint256 indexed listingId, 
        address indexed buyer, 
        uint256 amount, 
        uint256 totalPrice, 
        address paymentToken
    );
    event PlatformFeeUpdated(uint256 newFeePercentage);
    event FeeCollectorUpdated(address newFeeCollector);
    
    /**
    * @notice Constructor to initialize the marketplace
    * @dev Sets up the marketplace with carbon credits contract and supported stablecoins
    * @param _carbonCreditsAddress Address of the Carbon Credits ERC1155 contract
    * @param _usdcAddress Address of the USDC stablecoin contract
    * @param _usdtAddress Address of the USDT stablecoin contract
    * @param _feeCollector Address that will receive platform fees
    */
    constructor(
        address _carbonCreditsAddress,
        address _usdcAddress,
        address _usdtAddress,
        address _feeCollector
    ) {
        carbonCredits = ICarbonCredits(_carbonCreditsAddress);
        usdc = IERC20(_usdcAddress);
        usdt = IERC20(_usdtAddress);
        feeCollector = _feeCollector;
        platformFeePercentage = 250; // 2.5% fee by default
        _listingIdCounter = 1;
    }

    //TODO: only verified sellers and approved tokens
    /**
    * @notice Create a listing to sell carbon credits with stablecoin as payment
    * @dev Seller must have sufficient balance of carbon credits
    * @param tokenId The ID of the carbon credit token
    * @param amount The amount of credits to sell
    * @param pricePerCredit The price per credit in the smallest unit of the payment token
    * @param paymentToken The address of the payment token (must be USDC or USDT)
    * @return The ID of the newly created listing
    */
    function createListing(
        uint256 tokenId, 
        uint256 amount, 
        uint256 pricePerCredit,
        address paymentToken
    ) public returns (uint256) {
        uint256 balance = carbonCredits.balanceOf(msg.sender, tokenId);
        if (balance < amount) {
            revert InsufficientCredits(tokenId, msg.sender, amount, balance);
        }
        
        if (paymentToken != address(usdc) && paymentToken != address(usdt)) {
            revert UnsupportedPaymentToken(paymentToken);
        }
        
        uint256 listingId = _listingIdCounter++;
        
        Listing storage listing = listings[listingId];
        listing.seller = msg.sender;
        listing.tokenId = tokenId;
        listing.amount = amount;
        listing.pricePerCredit = pricePerCredit;
        listing.paymentToken = paymentToken;
        listing.active = true;
        
        emit ListingCreated(listingId, tokenId, msg.sender, amount, pricePerCredit, paymentToken);
        
        return listingId;
    }
    
    //TODO: only multisig-admins or Seller can cancel listing
    /**
    * @notice Cancel an active listing
    * @dev Only the seller of the listing can cancel it
    * @param listingId The ID of the listing to cancel
    */
    function cancelListing(uint256 listingId) public {
        Listing storage listing = listings[listingId];
        
        if (!listing.active) {
            revert ListingNotActive(listingId);
        }
        
        if (listing.seller != msg.sender) {
            revert NotSeller(msg.sender, listing.seller);
        }
        
        listing.active = false;
        
        emit ListingCancelled(listingId);
    }
}