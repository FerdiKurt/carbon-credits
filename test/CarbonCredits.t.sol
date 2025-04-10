// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CarbonCredits.sol";

contract CarbonCreditsTest is Test {
    CarbonCredits public carbonCredits;
    
    address public admin = address(1);
    address public issuer = address(2);
    address public verifier = address(3);
    address public user = address(4);
    
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    
    // Project parameters
    string public name = "Reforestation Project";
    string public description = "Reforestation of degraded land in Amazon";
    string public location = "Brazil, Amazon Basin";
    string public methodology = "VM0007";
    uint256 public startDate = block.timestamp;
    uint256 public endDate = block.timestamp + 365 days;
    uint256 public totalCredits = 100000;
    
    // Credit parameters
    uint256 public amount = 1000;
    uint256 public vintage = 2023;
    uint256 public serialNumber = 123456;
    
    function setUp() public {
        vm.startPrank(admin);
        carbonCredits = new CarbonCredits();
        
        // Grant roles
        carbonCredits.grantRole(ISSUER_ROLE, issuer);
        carbonCredits.grantRole(VERIFIER_ROLE, verifier);
        vm.stopPrank();
    }
    
    // function testInitialSetup() public {
    //     assertTrue(carbonCredits.hasRole(DEFAULT_ADMIN_ROLE, admin));
    //     assertTrue(carbonCredits.hasRole(ISSUER_ROLE, admin));
    //     assertTrue(carbonCredits.hasRole(VERIFIER_ROLE, admin));
    //     assertTrue(carbonCredits.hasRole(ISSUER_ROLE, issuer));
    //     assertTrue(carbonCredits.hasRole(VERIFIER_ROLE, verifier));
    // }
    
    // function testCreateProject() public {
    //     vm.startPrank(issuer);
    //     uint256 projectId = carbonCredits.createProject(
    //         name, 
    //         description, 
    //         location, 
    //         methodology, 
    //         startDate, 
    //         endDate, 
    //         totalCredits
    //     );
        
    //     (
    //         string memory _name,
    //         string memory _description,
    //         string memory _location,
    //         string memory _methodology,
    //         uint256 _startDate,
    //         uint256 _endDate,
    //         uint256 _totalCredits,
    //         uint256 _issuedCredits,
    //         address _projectOwner,
    //         bool _verified
    //     ) = carbonCredits.getProject(projectId);
        
    //     assertEq(_name, name);
    //     assertEq(_description, description);
    //     assertEq(_location, location);
    //     assertEq(_methodology, methodology);
    //     assertEq(_startDate, startDate);
    //     assertEq(_endDate, endDate);
    //     assertEq(_totalCredits, totalCredits);
    //     assertEq(_issuedCredits, 0);
    //     assertEq(_projectOwner, issuer);
    //     assertFalse(_verified);
    //     vm.stopPrank();
    // }
    
    // function testVerifyProject() public {
    //     // Create a project first
    //     vm.prank(issuer);
    //     uint256 projectId = carbonCredits.createProject(
    //         name, description, location, methodology, startDate, endDate, totalCredits
    //     );
        
    //     // Verify the project
    //     vm.prank(verifier);
    //     carbonCredits.verifyProject(projectId);
        
    //     (, , , , , , , , , bool verified) = carbonCredits.getProject(projectId);
    //     assertTrue(verified);
    // }
    
    // function testFailVerifyNonExistentProject() public {
    //     vm.prank(verifier);
    //     carbonCredits.verifyProject(999); // This should fail
    // }
    
    // function testFailVerifyProjectTwice() public {
    //     // Create and verify a project
    //     vm.prank(issuer);
    //     uint256 projectId = carbonCredits.createProject(
    //         name, description, location, methodology, startDate, endDate, totalCredits
    //     );
        
    //     vm.prank(verifier);
    //     carbonCredits.verifyProject(projectId);
        
    //     // Try to verify again - should fail
    //     vm.prank(verifier);
    //     carbonCredits.verifyProject(projectId);
    // }
    
    // function testIssueCredits() public {
    //     // Create and verify a project
    //     vm.prank(issuer);
    //     uint256 projectId = carbonCredits.createProject(
    //         name, description, location, methodology, startDate, endDate, totalCredits
    //     );
        
    //     vm.prank(verifier);
    //     carbonCredits.verifyProject(projectId);
        
    //     // Issue credits
    //     vm.prank(issuer);
    //     uint256 batchId = carbonCredits.issueCredits(projectId, amount, vintage, serialNumber);
        
    //     // Check batch details
    //     (
    //         uint256 _amount,
    //         uint256 _vintage,
    //         uint256 _serialNumber,
    //         bool _retired
    //     ) = carbonCredits.getCreditBatch(projectId, batchId);
        
    //     assertEq(_amount, amount);
    //     assertEq(_vintage, vintage);
    //     assertEq(_serialNumber, serialNumber);
    //     assertFalse(_retired);
        
    //     // Check project issued credits
    //     (, , , , , , , uint256 issuedCredits, , ) = carbonCredits.getProject(projectId);
    //     assertEq(issuedCredits, amount);
        
    //     // Check token balance
    //     uint256 tokenId = (projectId * 1000000) + batchId;
    //     assertEq(carbonCredits.balanceOf(issuer, tokenId), amount);
    // }
    
    // function testFailIssueCreditsUnverifiedProject() public {
    //     // Create project without verification
    //     vm.prank(issuer);
    //     uint256 projectId = carbonCredits.createProject(
    //         name, description, location, methodology, startDate, endDate, totalCredits
    //     );
        
    //     // Try to issue credits - should fail
    //     vm.prank(issuer);
    //     carbonCredits.issueCredits(projectId, amount, vintage, serialNumber);
    // }
    
    // function testFailIssueExceedingTotalCredits() public {
    //     // Create and verify a project
    //     vm.prank(issuer);
    //     uint256 projectId = carbonCredits.createProject(
    //         name, description, location, methodology, startDate, endDate, totalCredits
    //     );
        
    //     vm.prank(verifier);
    //     carbonCredits.verifyProject(projectId);
        
    //     // Try to issue more credits than allowed - should fail
    //     vm.prank(issuer);
    //     carbonCredits.issueCredits(projectId, totalCredits + 1, vintage, serialNumber);
    // }
    
    // function testRetireCredits() public {
    //     // Setup: Create project, verify, issue credits
    //     vm.prank(issuer);
    //     uint256 projectId = carbonCredits.createProject(
    //         name, description, location, methodology, startDate, endDate, totalCredits
    //     );
        
    //     vm.prank(verifier);
    //     carbonCredits.verifyProject(projectId);
        
    //     vm.prank(issuer);
    //     uint256 batchId = carbonCredits.issueCredits(projectId, amount, vintage, serialNumber);
        
    //     uint256 tokenId = (projectId * 1000000) + batchId;
    //     uint256 retireAmount = 400;
        
    //     // Transfer some credits to user
    //     vm.prank(issuer);
    //     carbonCredits.safeTransferFrom(issuer, user, tokenId, retireAmount, "");
        
    //     // User retires credits
    //     vm.prank(user);
    //     carbonCredits.retireCredits(projectId, batchId, retireAmount);
        
    //     // Check balances and retirement status
    //     assertEq(carbonCredits.balanceOf(user, tokenId), 0);
    //     assertEq(carbonCredits.retiredCredits(tokenId), retireAmount);
        
    //     // Batch shouldn't be fully retired yet
    //     (, , , bool retired) = carbonCredits.getCreditBatch(projectId, batchId);
    //     assertFalse(retired);
    // }
    
    // function testFullBatchRetirement() public {
    //     // Setup: Create project, verify, issue credits
    //     vm.prank(issuer);
    //     uint256 projectId = carbonCredits.createProject(
    //         name, description, location, methodology, startDate, endDate, totalCredits
    //     );
        
    //     vm.prank(verifier);
    //     carbonCredits.verifyProject(projectId);
        
    //     vm.prank(issuer);
    //     uint256 batchId = carbonCredits.issueCredits(projectId, amount, vintage, serialNumber);
        
    //     uint256 tokenId = (projectId * 1000000) + batchId;
        
    //     // Retire all credits
    //     vm.prank(issuer);
    //     carbonCredits.retireCredits(projectId, batchId, amount);
        
    //     // Check retirement status
    //     assertEq(carbonCredits.retiredCredits(tokenId), amount);
        
    //     // Batch should be fully retired
    //     (, , , bool retired) = carbonCredits.getCreditBatch(projectId, batchId);
    //     assertTrue(retired);
    // }
    
    // function testFailRetireMoreThanOwned() public {
    //     // Setup: Create project, verify, issue credits
    //     vm.prank(issuer);
    //     uint256 projectId = carbonCredits.createProject(
    //         name, description, location, methodology, startDate, endDate, totalCredits
    //     );
        
    //     vm.prank(verifier);
    //     carbonCredits.verifyProject(projectId);
        
    //     vm.prank(issuer);
    //     uint256 batchId = carbonCredits.issueCredits(projectId, amount, vintage, serialNumber);
        
    //     // Transfer half of credits to user
    //     uint256 tokenId = (projectId * 1000000) + batchId;
    //     uint256 transferAmount = amount / 2;
        
    //     vm.prank(issuer);
    //     carbonCredits.safeTransferFrom(issuer, user, tokenId, transferAmount, "");
        
    //     // Try to retire more than owned - should fail
    //     vm.prank(user);
    //     carbonCredits.retireCredits(projectId, batchId, transferAmount + 1);
    // }
    
    // function testFailRetireBatchTwice() public {
    //     // Setup: Create project, verify, issue credits
    //     vm.prank(issuer);
    //     uint256 projectId = carbonCredits.createProject(
    //         name, description, location, methodology, startDate, endDate, totalCredits
    //     );
        
    //     vm.prank(verifier);
    //     carbonCredits.verifyProject(projectId);
        
    //     vm.prank(issuer);
    //     uint256 batchId = carbonCredits.issueCredits(projectId, amount, vintage, serialNumber);
        
    //     // Retire all credits
    //     vm.prank(issuer);
    //     carbonCredits.retireCredits(projectId, batchId, amount);
        
    //     // Try to retire some credits from the same batch - should fail since batch is marked retired
    //     vm.prank(issuer);
    //     carbonCredits.retireCredits(projectId, batchId, 1);
    // }
    
    // function testUriGeneration() public {
    //     // Create project, verify, issue credits
    //     vm.prank(issuer);
    //     uint256 projectId = carbonCredits.createProject(
    //         name, description, location, methodology, startDate, endDate, totalCredits
    //     );
        
    //     vm.prank(verifier);
    //     carbonCredits.verifyProject(projectId);
        
    //     vm.prank(issuer);
    //     uint256 batchId = carbonCredits.issueCredits(projectId, amount, vintage, serialNumber);
        
    //     uint256 tokenId = (projectId * 1000000) + batchId;
        
    //     string memory expectedUri = string(abi.encodePacked(
    //         "https://carbon-credits-api.com/metadata/", 
    //         carbonCredits._toString(tokenId),
    //         "?projectId=", carbonCredits._toString(projectId),
    //         "&batchId=", carbonCredits._toString(batchId)
    //     ));
        
    //     assertEq(carbonCredits.uri(tokenId), expectedUri);
    // }
    
    // function testMultipleProjects() public {
    //     // Create first project
    //     vm.prank(issuer);
    //     uint256 projectId1 = carbonCredits.createProject(
    //         name, description, location, methodology, startDate, endDate, totalCredits
    //     );
        
    //     // Create second project
    //     vm.prank(issuer);
    //     uint256 projectId2 = carbonCredits.createProject(
    //         "Forest Conservation", 
    //         "Conservation of existing forest", 
    //         "Indonesia, Borneo", 
    //         "VM0015", 
    //         startDate, 
    //         endDate, 
    //         50000
    //     );
        
    //     // Verify both projects
    //     vm.startPrank(verifier);
    //     carbonCredits.verifyProject(projectId1);
    //     carbonCredits.verifyProject(projectId2);
    //     vm.stopPrank();
        
    //     // Issue credits for both projects
    //     vm.startPrank(issuer);
    //     uint256 batchId1 = carbonCredits.issueCredits(projectId1, 1000, 2023, 123456);
    //     uint256 batchId2 = carbonCredits.issueCredits(projectId2, 2000, 2024, 789012);
    //     vm.stopPrank();
        
    //     // Check project issued credits
    //     (, , , , , , , uint256 issuedCredits1, , ) = carbonCredits.getProject(projectId1);
    //     (, , , , , , , uint256 issuedCredits2, , ) = carbonCredits.getProject(projectId2);
        
    //     assertEq(issuedCredits1, 1000);
    //     assertEq(issuedCredits2, 2000);
        
    //     // Check token balances
    //     uint256 tokenId1 = (projectId1 * 1000000) + batchId1;
    //     uint256 tokenId2 = (projectId2 * 1000000) + batchId2;
        
    //     assertEq(carbonCredits.balanceOf(issuer, tokenId1), 1000);
    //     assertEq(carbonCredits.balanceOf(issuer, tokenId2), 2000);
    // }
    
    // function testRoleAccess() public {
    //     // User without ISSUER_ROLE tries to create project
    //     vm.expectRevert();
    //     vm.prank(user);
    //     carbonCredits.createProject(
    //         name, description, location, methodology, startDate, endDate, totalCredits
    //     );
        
    //     // Create a project with proper role
    //     vm.prank(issuer);
    //     uint256 projectId = carbonCredits.createProject(
    //         name, description, location, methodology, startDate, endDate, totalCredits
    //     );
        
    //     // User without VERIFIER_ROLE tries to verify
    //     vm.expectRevert();
    //     vm.prank(user);
    //     carbonCredits.verifyProject(projectId);
        
    //     // Verify with proper role
    //     vm.prank(verifier);
    //     carbonCredits.verifyProject(projectId);
        
    //     // User without ISSUER_ROLE tries to issue credits
    //     vm.expectRevert();
    //     vm.prank(user);
    //     carbonCredits.issueCredits(projectId, amount, vintage, serialNumber);
    // }
    
    // function testMultipleBatchesForProject() public {
    //     // Create and verify a project
    //     vm.prank(issuer);
    //     uint256 projectId = carbonCredits.createProject(
    //         name, description, location, methodology, startDate, endDate, totalCredits
    //     );
        
    //     vm.prank(verifier);
    //     carbonCredits.verifyProject(projectId);
        
    //     // Issue first batch
    //     vm.prank(issuer);
    //     uint256 batchId1 = carbonCredits.issueCredits(projectId, 1000, 2023, 111111);
        
    //     // Issue second batch
    //     vm.prank(issuer);
    //     uint256 batchId2 = carbonCredits.issueCredits(projectId, 2000, 2024, 222222);
        
    //     // Check batch details
    //     (uint256 amount1, uint256 vintage1, uint256 serialNumber1, ) = 
    //         carbonCredits.getCreditBatch(projectId, batchId1);
    //     (uint256 amount2, uint256 vintage2, uint256 serialNumber2, ) = 
    //         carbonCredits.getCreditBatch(projectId, batchId2);
        
    //     assertEq(amount1, 1000);
    //     assertEq(vintage1, 2023);
    //     assertEq(serialNumber1, 111111);
        
    //     assertEq(amount2, 2000);
    //     assertEq(vintage2, 2024);
    //     assertEq(serialNumber2, 222222);
        
    //     // Check project issued credits
    //     (, , , , , , , uint256 issuedCredits, , ) = carbonCredits.getProject(projectId);
    //     assertEq(issuedCredits, 3000);
    // }
}