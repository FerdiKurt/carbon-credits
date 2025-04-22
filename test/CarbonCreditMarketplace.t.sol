// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CarbonCreditMarketplace.sol";
import "../src/interfaces/Errors.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18); // Mint some initial supply to creator
    }
    
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
    
    // Override to ensure SafeERC20 works properly
    function transfer(address to, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true; // Explicitly return true
    }
    
    // Override to ensure SafeERC20 works properly
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true; // Explicitly return true
    }
    
    // Override to ensure SafeERC20 works properly
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true; // Explicitly return true
    }
}

// CarbonCredits interface
interface ICarbonCredit {
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;
}

// Mock Contract for testing
contract MockCarbonCredits is ICarbonCredit {
    mapping(address => mapping(uint256 => uint256)) private _balances;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    
    function balanceOf(address account, uint256 id) public view override returns (uint256) {
        return _balances[account][id];
    }
    
    function mint(address to, uint256 id, uint256 amount) public {
        _balances[to][id] += amount;
    }
    
    // Needed for ERC1155 approvals
    function setApprovalForAll(address operator, bool approved) public {
        _operatorApprovals[msg.sender][operator] = approved;
    }
    
    function isApprovedForAll(address account, address operator) public view returns (bool) {
        return _operatorApprovals[account][operator];
    }
    
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory /* data */
    ) public override {
        require(_balances[from][id] >= amount, "MockCarbonCredits: insufficient balance");
        
        // Check if msg.sender is approved to transfer tokens from 'from'
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "MockCarbonCredits: caller is not owner nor approved"
        );
        
        _balances[from][id] -= amount;
        _balances[to][id] += amount;
    }
}

contract CarbonCreditMarketplaceTest is Test, Errors {
    CarbonCreditMarketplace marketplace;
    MockCarbonCredits carbonCredits;
    MockERC20 usdc;
    MockERC20 usdt;
    MockERC20 unsupportedToken;
    
    // Role constants
    bytes32 constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 constant VERIFIED_SELLER_ROLE = keccak256("VERIFIED_SELLER_ROLE");
    
    address admin = address(0x1);
    address feeCollector = address(0x2);
    address seller = address(0x3);
    address buyer = address(0x4);
    address nonAuthorizedUser = address(0x5);
    
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
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy mock contracts
        carbonCredits = new MockCarbonCredits();
        usdc = new MockERC20("USD Coin", "USDC");
        usdt = new MockERC20("Tether", "USDT");
        unsupportedToken = new MockERC20("Unsupported Token", "UNSUPPORTED");
        
        // Deploy marketplace
        marketplace = new CarbonCreditMarketplace(
            address(carbonCredits),
            address(usdc),
            address(usdt),
            feeCollector
        );
        
        // Add verified seller
        marketplace.addVerifiedSeller(seller);
        
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
        assertTrue(marketplace.hasRole(ADMIN_ROLE, admin), "Admin should have ADMIN_ROLE");
        assertTrue(marketplace.hasRole(VERIFIED_SELLER_ROLE, seller), "Seller should have VERIFIED_SELLER_ROLE");
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
    
    function testCannotCreateListingIfNotVerifiedSeller() public {
        vm.startPrank(nonAuthorizedUser);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.NotAuthorized.selector,
                nonAuthorizedUser,
                "VERIFIED_SELLER_ROLE"
            )
        );
        
        marketplace.createListing(tokenId, amount, pricePerCredit, address(usdc));
        
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
    
    function testAdminCanCancelListing() public {
        // First create a listing
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(tokenId, amount, pricePerCredit, address(usdc));
        
        // Cancel as admin
        vm.startPrank(admin);
        
        vm.expectEmit(true, true, false, false);
        emit ListingCancelled(listingId, admin);
        
        marketplace.cancelListing(listingId);
        
        (,,,,, bool lActive) = marketplace.getListing(listingId);
        assertFalse(lActive, "Listing should not be active");
        
        vm.stopPrank();
    }
    
    function testSellerCannotCancelListing() public {
        // First create a listing
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(tokenId, amount, pricePerCredit, address(usdc));
        
        // Try to cancel as seller
        vm.startPrank(seller);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.NotAuthorized.selector,
                seller,
                "ADMIN_ROLE"
            )
        );
        
        marketplace.cancelListing(listingId);
        
        vm.stopPrank();
    }
    
    function testCannotCancelNonExistentListing() public {
        vm.startPrank(admin);
        
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
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(tokenId, amount, pricePerCredit, address(usdc));
        
        vm.startPrank(admin);
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
    
    function testPurchaseCredits() public {
        // First create a listing
        vm.startPrank(seller);
        uint256 listingId = marketplace.createListing(tokenId, amount, pricePerCredit, address(usdc));
        
        // The seller needs to approve the marketplace to transfer their carbon credits
        MockCarbonCredits(address(carbonCredits)).setApprovalForAll(address(marketplace), true);
        vm.stopPrank();
        
        // Approve marketplace to spend buyer's USDC
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), amount * pricePerCredit);
        
        uint256 totalPrice = amount * pricePerCredit;
        uint256 platformFee = (totalPrice * marketplace.platformFeePercentage()) / 10000;
        uint256 sellerPayment = totalPrice - platformFee;
        
        // Capture initial balances for verification
        uint256 initialBuyerUsdcBalance = usdc.balanceOf(buyer);
        uint256 initialSellerUsdcBalance = usdc.balanceOf(seller);
        uint256 initialFeeCollectorBalance = usdc.balanceOf(feeCollector);
        uint256 initialBuyerCreditBalance = carbonCredits.balanceOf(buyer, tokenId);
        uint256 initialSellerCreditBalance = carbonCredits.balanceOf(seller, tokenId);
        
        // Test event emission
        vm.expectEmit();
        emit CreditsPurchased(listingId, buyer, amount, totalPrice, address(usdc));
        
        marketplace.purchaseCredits(listingId, amount);
        
        // Check state changes
        (,,,,, bool lActive) = marketplace.getListing(listingId);
        assertFalse(lActive, "Listing should not be active after full purchase");
        
        // Check token transfers
        assertEq(carbonCredits.balanceOf(buyer, tokenId), initialBuyerCreditBalance + amount, "Buyer should have received credits");
        assertEq(carbonCredits.balanceOf(seller, tokenId), initialSellerCreditBalance - amount, "Seller should have sent credits");
        assertEq(usdc.balanceOf(buyer), initialBuyerUsdcBalance - totalPrice, "Buyer should have spent USDC");
        assertEq(usdc.balanceOf(seller), initialSellerUsdcBalance + sellerPayment, "Seller should have received payment");
        assertEq(usdc.balanceOf(feeCollector), initialFeeCollectorBalance + platformFee, "Fee collector should have received fee");
        
        vm.stopPrank();
    }
    
    function testPartialPurchase() public {
        // Create a listing with more credits
        vm.startPrank(seller);
        uint256 listingId = marketplace.createListing(tokenId, amount * 2, pricePerCredit, address(usdc));
        
        // The seller needs to approve the marketplace
        MockCarbonCredits(address(carbonCredits)).setApprovalForAll(address(marketplace), true);
        vm.stopPrank();
        
        // Approve marketplace to spend buyer's USDC
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), amount * pricePerCredit);
        
        uint256 totalPrice = amount * pricePerCredit;
        uint256 platformFee = (totalPrice * marketplace.platformFeePercentage()) / 10000;
        uint256 sellerPayment = totalPrice - platformFee;
        
        marketplace.purchaseCredits(listingId, amount);
        
        // Check state changes
        (,, uint256 remainingAmount,,, bool lActive) = marketplace.getListing(listingId);
        assertTrue(lActive, "Listing should still be active after partial purchase");
        assertEq(remainingAmount, amount, "Listing should have half the amount left");
        
        // Check token transfers
        assertEq(carbonCredits.balanceOf(buyer, tokenId), amount, "Buyer should have received credits");
        assertEq(usdc.balanceOf(seller), sellerPayment, "Seller should have received payment");
        assertEq(usdc.balanceOf(feeCollector), platformFee, "Fee collector should have received fee");
        
        vm.stopPrank();
    }
    
    function testCannotPurchaseInactiveListing() public {
        // Create and cancel a listing
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(tokenId, amount, pricePerCredit, address(usdc));
        
        vm.prank(admin);
        marketplace.cancelListing(listingId);
        
        // Try to purchase
        vm.startPrank(buyer);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.ListingNotActive.selector,
                listingId
            )
        );
        
        marketplace.purchaseCredits(listingId, amount);
        
        vm.stopPrank();
    }
    
    function testCannotPurchaseMoreThanAvailable() public {
        // Create a listing
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(tokenId, amount, pricePerCredit, address(usdc));
        
        // Try to purchase more than available
        vm.startPrank(buyer);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.ExceedsAvailableAmount.selector,
                amount,
                amount + 1
            )
        );
        
        marketplace.purchaseCredits(listingId, amount + 1);
        
        vm.stopPrank();
    }
    
    function testOnlyAdminCanSetPlatformFee() public {
        vm.startPrank(admin);
        
        uint256 newFee = 300; // 3%
        
        vm.expectEmit(true, false, false, false);
        emit PlatformFeeUpdated(newFee);
        
        marketplace.setPlatformFee(newFee);
        
        assertEq(marketplace.platformFeePercentage(), newFee, "Fee should be updated");
        
        vm.stopPrank();
    }
    
    function testNonAdminCannotSetPlatformFee() public {
        vm.startPrank(nonAuthorizedUser);
        
        uint256 newFee = 300; // 3%
        
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.NotAuthorized.selector,
                nonAuthorizedUser,
                "ADMIN_ROLE"
            )
        );
        
        marketplace.setPlatformFee(newFee);
        
        vm.stopPrank();
    }
    
    function testCannotSetExcessiveFee() public {
        vm.startPrank(admin);
        
        uint256 excessiveFee = 1001; // Over 10%
        
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.FeeTooHigh.selector,
                excessiveFee
            )
        );
        
        marketplace.setPlatformFee(excessiveFee);
        
        vm.stopPrank();
    }
    
    function testOnlyAdminCanSetFeeCollector() public {
        vm.startPrank(admin);
        
        address newCollector = address(0x5);
        
        vm.expectEmit(true, false, false, false);
        emit FeeCollectorUpdated(newCollector);
        
        marketplace.setFeeCollector(newCollector);
        
        assertEq(marketplace.feeCollector(), newCollector, "Fee collector should be updated");
        
        vm.stopPrank();
    }
    
    function testNonAdminCannotSetFeeCollector() public {
        vm.startPrank(nonAuthorizedUser);
        
        address newCollector = address(0x5);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.NotAuthorized.selector,
                nonAuthorizedUser,
                "ADMIN_ROLE"
            )
        );
        
        marketplace.setFeeCollector(newCollector);
        
        vm.stopPrank();
    }
    
    function testCannotSetZeroAddressFeeCollector() public {
        vm.startPrank(admin);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidFeeCollector.selector,
                address(0)
            )
        );
        
        marketplace.setFeeCollector(address(0));
        
        vm.stopPrank();
    }
    
    function testCheckTokenSupported() public view {
        assertTrue(marketplace.isTokenSupported(address(usdc)), "USDC should be supported");
        assertTrue(marketplace.isTokenSupported(address(usdt)), "USDT should be supported");
        assertFalse(marketplace.isTokenSupported(address(unsupportedToken)), "Other token should not be supported");
    }
    
    function testVerifyAndRevokeSellerPermissions() public {
        address newSeller = address(0x6);
        
        // Initially, not a verified seller
        assertFalse(marketplace.isVerifiedSeller(newSeller), "Should not be a verified seller initially");
        
        // Only admin can add a verified seller
        vm.startPrank(admin);
        vm.expectEmit(true, false, false, false);
        emit SellerVerified(newSeller);
        marketplace.addVerifiedSeller(newSeller);
        vm.stopPrank();
        
        // Check the seller is now verified
        assertTrue(marketplace.isVerifiedSeller(newSeller), "Should be a verified seller after adding");
        
        // Now revoke permission
        vm.prank(admin);
        marketplace.removeVerifiedSeller(newSeller);
        
        // Check the seller is no longer verified
        assertFalse(marketplace.isVerifiedSeller(newSeller), "Should not be a verified seller after removal");
    }
    
    function testNonAdminCannotVerifySeller() public {
        address newSeller = address(0x6);
        
        vm.startPrank(nonAuthorizedUser);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.NotAuthorized.selector,
                nonAuthorizedUser,
                "ADMIN_ROLE"
            )
        );
        
        marketplace.addVerifiedSeller(newSeller);
        
        vm.stopPrank();
    }
}