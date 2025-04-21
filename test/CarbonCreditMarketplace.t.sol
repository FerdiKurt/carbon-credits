// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CarbonCreditMarketplace.sol";
import "../src/interfaces/ICarbonCredits.sol";
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
    MockERC20 otherToken;
    
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
        otherToken = new MockERC20("Other Token", "OTHER");
        
        // Deploy marketplace
        marketplace = new CarbonCreditMarketplaceERC20(
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
}