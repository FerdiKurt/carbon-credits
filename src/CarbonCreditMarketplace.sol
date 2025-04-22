// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/ICarbonCredits.sol";
import "./interfaces/Errors.sol";


/**
* @title CarbonCreditMarketplace
* @dev Marketplace for trading carbon credits with USDC and USDT payment options
* @notice This contract allows verified sellers to list and users to purchase carbon credits using stablecoins
*/
contract CarbonCreditMarketplace is ReentrancyGuard, AccessControl, Errors {
    using SafeERC20 for IERC20;
    
    // Role definitions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant VERIFIED_SELLER_ROLE = keccak256("VERIFIED_SELLER_ROLE");
    
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
    
    // events
    event ListingCreated(
        uint256 indexed listingId, 
        uint256 indexed tokenId, 
        address indexed seller, 
        uint256 amount, 
        uint256 pricePerCredit, 
        address paymentToken
    );
    event ListingCancelled(uint256 indexed listingId, address canceller);
    event CreditsPurchased(
        uint256 indexed listingId, 
        address indexed buyer, 
        uint256 amount, 
        uint256 totalPrice, 
        address paymentToken
    );
    event PlatformFeeUpdated(uint256 newFeePercentage);
    event FeeCollectorUpdated(address newFeeCollector);
    event SellerVerified(address seller);
    event SellerVerificationRevoked(address seller);
    
    /**
    * @dev Modifier to restrict function access to admins only
    */
    modifier onlyAdmin() {
        if (!hasRole(ADMIN_ROLE, msg.sender)) {
            revert NotAuthorized(msg.sender, "ADMIN_ROLE");
        }
        _;
    }
    
    /**
    * @notice Constructor to initialize the marketplace
    * @dev Sets up the marketplace with carbon credits contract, supported stablecoins, and grants admin role to deployer
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
        
        // Setup roles - grant admin role to contract deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
    * @notice Add a verified seller
    * @dev Only callable by admins
    * @param seller Address to be granted the verified seller role
    */
    function addVerifiedSeller(address seller) external onlyAdmin {
        grantRole(VERIFIED_SELLER_ROLE, seller);
        emit SellerVerified(seller);
    }
    
    /**
    * @notice Remove a verified seller
    * @dev Only callable by admins
    * @param seller Address to have verified seller role revoked
    */
    function removeVerifiedSeller(address seller) external onlyAdmin {
        revokeRole(VERIFIED_SELLER_ROLE, seller);
        emit SellerVerificationRevoked(seller);
    }

    /**
    * @notice Create a listing to sell carbon credits with stablecoin as payment
    * @dev Only verified sellers can create listings and must have sufficient balance of carbon credits
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
        // Check if sender is a verified seller
        if (!hasRole(VERIFIED_SELLER_ROLE, msg.sender)) {
            revert NotAuthorized(msg.sender, "VERIFIED_SELLER_ROLE");
        }
        
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
    
    /**
    * @notice Cancel an active listing
    * @dev Only admins can cancel listings
    * @param listingId The ID of the listing to cancel
    */
    function cancelListing(uint256 listingId) public onlyAdmin {
        Listing storage listing = listings[listingId];
        
        if (!listing.active) {
            revert ListingNotActive(listingId);
        }
        
        listing.active = false;
        
        emit ListingCancelled(listingId, msg.sender);
    }

    /**
    * @notice Purchase carbon credits from a listing using stablecoins
    * @dev The buyer must have approved this contract to spend their tokens
    * @param listingId The ID of the listing to purchase from
    * @param amount The amount of credits to purchase
    */
    function purchaseCredits(uint256 listingId, uint256 amount) public nonReentrant {
        Listing storage listing = listings[listingId];
        
        if (!listing.active) {
            revert ListingNotActive(listingId);
        }
        
        if (amount > listing.amount) {
            revert ExceedsAvailableAmount(listing.amount, amount);
        }
        
        uint256 totalPrice = amount * listing.pricePerCredit;
        uint256 platformFee = (totalPrice * platformFeePercentage) / 10000;
        uint256 sellerPayment = totalPrice - platformFee;
        
        // Get the correct token contract based on the listing
        IERC20 paymentToken = IERC20(listing.paymentToken);
        
        // Transfer tokens from buyer to seller and fee collector
        paymentToken.safeTransferFrom(msg.sender, listing.seller, sellerPayment);
        
        if (platformFee > 0) {
            paymentToken.safeTransferFrom(msg.sender, feeCollector, platformFee);
        }
        
        // Transfer credits from seller to buyer
        carbonCredits.safeTransferFrom(listing.seller, msg.sender, listing.tokenId, amount, "");
        
        // Update listing
        listing.amount -= amount;
        if (listing.amount == 0) {
            listing.active = false;
        }
        
        emit CreditsPurchased(listingId, msg.sender, amount, totalPrice, listing.paymentToken);
    }
    
    /**
    * @notice Get details about a specific listing
    * @param listingId The ID of the listing to query
    * @return seller Address of the seller
    * @return tokenId ID of the carbon credit token
    * @return amount Amount of credits available
    * @return pricePerCredit Price per credit in payment token's smallest unit
    * @return paymentToken Address of the payment token
    * @return active Whether the listing is active
    */
    function getListing(uint256 listingId) public view returns (
        address seller,
        uint256 tokenId,
        uint256 amount,
        uint256 pricePerCredit,
        address paymentToken,
        bool active
    ) {
        Listing storage listing = listings[listingId];
        return (
            listing.seller,
            listing.tokenId,
            listing.amount,
            listing.pricePerCredit,
            listing.paymentToken,
            listing.active
        );
    }
    
    /**
    * @notice Update the platform fee percentage
    * @dev Only admins can update the platform fee
    * @param newFeePercentage The new fee percentage in basis points (100 = 1%)
    */
    function setPlatformFee(uint256 newFeePercentage) public onlyAdmin {
        if (newFeePercentage > 1000) {
            revert FeeTooHigh(newFeePercentage);
        }
        
        platformFeePercentage = newFeePercentage;
        emit PlatformFeeUpdated(newFeePercentage);
    }
    
    /**
    * @notice Update the fee collector address
    * @dev Only admins can update the fee collector
    * @param newFeeCollector The new address to collect fees
    */
    function setFeeCollector(address newFeeCollector) public onlyAdmin {
        if (newFeeCollector == address(0)) {
            revert InvalidFeeCollector(newFeeCollector);
        }
        
        feeCollector = newFeeCollector;
        emit FeeCollectorUpdated(newFeeCollector);
    }
    
    /**
    * @notice Check if a token is supported for payment
    * @dev Currently only USDC and USDT are supported
    * @param tokenAddress The address of the token to check
    * @return True if the token is supported, false otherwise
    */
    function isTokenSupported(address tokenAddress) public view returns (bool) {
        return tokenAddress == address(usdc) || tokenAddress == address(usdt);
    }
    
    /**
    * @notice Check if an address is a verified seller
    * @param seller The address to check
    * @return True if the address has the verified seller role
    */
    function isVerifiedSeller(address seller) public view returns (bool) {
        return hasRole(VERIFIED_SELLER_ROLE, seller);
    }
}