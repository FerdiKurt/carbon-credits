// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CarbonCreditMarketplace.sol";
import "../src/interfaces/Errors.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

// Mock ICarbonCredits for testing
 contract MockCarbonCredits {
    mapping(address => mapping(uint256 => uint256)) private _balances;
    
    function balanceOf(address account, uint256 id) public view returns (uint256) {
        return _balances[account][id];
    }
    
    function mint(address to, uint256 id, uint256 amount) public {
        _balances[to][id] += amount;
    }
    
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public {
        require(_balances[from][id] >= amount, "Insufficient balance");
        _balances[from][id] -= amount;
        _balances[to][id] += amount;
    }
}

contract CarbonCreditMarketplace is Test, Errors {
    CarbonCreditMarketplaceERC20 marketplace;
    MockCarbonCredits carbonCredits;
    MockERC20 usdc;
    MockERC20 usdt;
    MockERC20 unsupportedToken;
    
    address admin = address(0x1);
    address feeCollector = address(0x2);
    address seller = address(0x3);
    address buyer = address(0x4);
    
    uint256 tokenId = 123;
    uint256 amount = 10;
    uint256 pricePerCredit = 100e6; // 100 USDC per credit
    
    // Events to test
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
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy mock contracts
        carbonCredits = new MockCarbonCredits();
        usdc = new MockERC20("USD Coin", "USDC");
        usdt = new MockERC20("Tether", "USDT");
        unsupportedToken = new MockERC20("Other Token", "OTHER");
        
        // Deploy marketplace
        marketplace = new CarbonCreditMarketplace(
            address(carbonCredits),
            address(usdc),
            address(usdt),
            feeCollector
        );
        
        vm.stopPrank();
        
        // Setup test data
        vm.startPrank(admin);
        carbonCredits.mint(seller, tokenId, 100); // Mint 100 carbon credits to seller
        usdc.mint(buyer, 10000e6); // Mint 10,000 USDC to buyer
        usdt.mint(buyer, 10000e6); // Mint 10,000 USDT to buyer
        vm.stopPrank();
    }

    function testInitialState() public view {
        assertEq(address(marketplace.carbonCredits()), address(carbonCredits));
        assertEq(address(marketplace.usdc()), address(usdc));
        assertEq(address(marketplace.usdt()), address(usdt));
        assertEq(marketplace.feeCollector(), feeCollector);
        assertEq(marketplace.platformFeePercentage(), 250); // 2.5%
    }
    
    function testCreateListing() public {
        vm.startPrank(seller);
        
        vm.expectEmit(true, true, true, true);
        emit ListingCreated(1, tokenId, seller, amount, pricePerCredit, address(usdc));
        
        uint256 listingId = marketplace.createListing(tokenId, amount, pricePerCredit, address(usdc));
        
        assertEq(listingId, 1, "Listing ID should be 1");
        
        (
            address lSeller,
            uint256 lTokenId,
            uint256 lAmount,
            uint256 lPricePerCredit,
            address lPaymentToken,
            bool lActive
        ) = marketplace.getListing(listingId);
        
        assertEq(lSeller, seller, "Seller mismatch");
        assertEq(lTokenId, tokenId, "Token ID mismatch");
        assertEq(lAmount, amount, "Amount mismatch");
        assertEq(lPricePerCredit, pricePerCredit, "Price per credit mismatch");
        assertEq(lPaymentToken, address(usdc), "Payment token mismatch");
        assertTrue(lActive, "Listing should be active");
        
        vm.stopPrank();
    }
    
    function testCreateListingWithUsdt() public {
        vm.startPrank(seller);
        
        vm.expectEmit(true, true, true, true);
        emit ListingCreated(1, tokenId, seller, amount, pricePerCredit, address(usdt));
        
        uint256 listingId = marketplace.createListing(tokenId, amount, pricePerCredit, address(usdt));
        
        assertEq(listingId, 1, "Listing ID should be 1");
        
        (
            address lSeller,
            uint256 lTokenId,
            uint256 lAmount,
            uint256 lPricePerCredit,
            address lPaymentToken,
            bool lActive
        ) = marketplace.getListing(listingId);
        
        assertEq(lSeller, seller, "Seller mismatch");
        assertEq(lTokenId, tokenId, "Token ID mismatch");
        assertEq(lAmount, amount, "Amount mismatch");
        assertEq(lPricePerCredit, pricePerCredit, "Price per credit mismatch");
        assertEq(lPaymentToken, address(usdt), "Payment token mismatch");
        assertTrue(lActive, "Listing should be active");
        
        vm.stopPrank();
    }
    
    function testCannotCreateListingWithInsufficientBalance() public {
        vm.startPrank(seller);
        
        uint256 excessAmount = 101; // Seller only has 100 credits
        
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InsufficientCredits.selector,
                tokenId,
                seller,
                excessAmount,
                100
            )
        );
        
        marketplace.createListing(tokenId, excessAmount, pricePerCredit, address(usdc));
        
        vm.stopPrank();
    }
    
    function testCannotCreateListingWithUnsupportedToken() public {
        vm.startPrank(seller);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.UnsupportedPaymentToken.selector,
                address(unsupportedToken)
            )
        );
        
        marketplace.createListing(tokenId, amount, pricePerCredit, address(unsupportedToken));
        
        vm.stopPrank();
    }
    
    function testCancelListing() public {
        // First create a listing
        vm.startPrank(seller);
        uint256 listingId = marketplace.createListing(tokenId, amount, pricePerCredit, address(usdc));
        
        vm.expectEmit(true, false, false, false);
        emit ListingCancelled(listingId);
        
        marketplace.cancelListing(listingId);
        
        (,,,,, bool lActive) = marketplace.getListing(listingId);
        assertFalse(lActive, "Listing should not be active");
        
        vm.stopPrank();
    }
    
    function testCannotCancelNonExistentListing() public {
        vm.startPrank(seller);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.ListingNotActive.selector,
                999
            )
        );
        
        marketplace.cancelListing(999);
        
        vm.stopPrank();
    }
    
    function testCannotCancelInactiveListing() public {
        // First create and cancel a listing
        vm.startPrank(seller);
        uint256 listingId = marketplace.createListing(tokenId, amount, pricePerCredit, address(usdc));
        marketplace.cancelListing(listingId);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.ListingNotActive.selector,
                listingId
            )
        );
        
        marketplace.cancelListing(listingId);
        
        vm.stopPrank();
    }
    
    function testCannotCancelOtherSellerListing() public {
        // First create a listing
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(tokenId, amount, pricePerCredit, address(usdc));
        
        vm.startPrank(buyer);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.NotSeller.selector,
                buyer,
                seller
            )
        );
        
        marketplace.cancelListing(listingId);
        
        vm.stopPrank();
    }
}