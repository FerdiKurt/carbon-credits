// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../src/CarbonCredits.sol";

contract CarbonCreditsTest is Test, AccessControl {
    CarbonCredits carbonCredits;
    
    address admin = address(0x1);
    address issuer = address(0x2);
    address verifier = address(0x3);
    address user = address(0x4);
    
    // Events to test
    event ProjectCreated(uint256 indexed projectId, string name, address indexed owner);
    event ProjectVerified(uint256 indexed projectId, address indexed verifier);
    event CreditsIssued(uint256 indexed projectId, uint256 indexed batchId, uint256 amount, uint256 vintage);
    event CreditsRetired(uint256 indexed projectId, uint256 indexed batchId, address indexed retiredBy, uint256 amount);
    
    // Sample project data
    string name = "Reforestation Project";
    string description = "A project to reforest degraded land";
    string location = "Amazon Rainforest, Brazil";
    string methodology = "VM0007";
    uint256 startDate = 1672531200; // Jan 1, 2023
    uint256 endDate = 1704067200;   // Jan 1, 2024
    uint256 totalCredits = 1000;
    
    // Sample credit data
    uint256 creditAmount = 500;
    uint256 vintage = 2023;
    uint256 serialNumber = 123456789;
    
    function setUp() public {
        vm.startPrank(admin);
        carbonCredits = new CarbonCredits();
        
        // Set up roles
        carbonCredits.grantRole(carbonCredits.ISSUER_ROLE(), issuer);
        carbonCredits.grantRole(carbonCredits.VERIFIER_ROLE(), verifier);
        vm.stopPrank();
    }
    
    function testInitialState() public view {
        assertTrue(carbonCredits.hasRole(carbonCredits.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(carbonCredits.hasRole(carbonCredits.ISSUER_ROLE(), admin));
        assertTrue(carbonCredits.hasRole(carbonCredits.VERIFIER_ROLE(), admin));
        assertTrue(carbonCredits.hasRole(carbonCredits.ISSUER_ROLE(), issuer));
        assertTrue(carbonCredits.hasRole(carbonCredits.VERIFIER_ROLE(), verifier));
    }
    
    function testCreateProject() public {
        vm.startPrank(issuer);
        
        vm.expectEmit(true, true, false, true);
        emit ProjectCreated(1, name, issuer);
        
        uint256 projectId = carbonCredits.createProject(
            name,
            description,
            location,
            methodology,
            startDate,
            endDate,
            totalCredits
        );
        
        assertEq(projectId, 1, "Project ID should be 1");
        
        (
            string memory pName,
            string memory pDesc,
            string memory pLoc,
            string memory pMethod,
            uint256 pStart,
            uint256 pEnd,
            uint256 pTotal,
            uint256 pIssued,
            address pOwner,
            bool pVerified
        ) = carbonCredits.getProject(projectId);
        
        assertEq(pName, name, "Project name mismatch");
        assertEq(pDesc, description, "Project description mismatch");
        assertEq(pLoc, location, "Project location mismatch");
        assertEq(pMethod, methodology, "Project methodology mismatch");
        assertEq(pStart, startDate, "Project start date mismatch");
        assertEq(pEnd, endDate, "Project end date mismatch");
        assertEq(pTotal, totalCredits, "Project total credits mismatch");
        assertEq(pIssued, 0, "Project issued credits should be 0");
        assertEq(pOwner, issuer, "Project owner should be issuer");
        assertFalse(pVerified, "Project should not be verified");
        
        vm.stopPrank();
    }
    
    function testOnlyIssuerCanCreateProject() public {
        vm.startPrank(user);
        
        vm.expectRevert(
            // abi.encodeWithSelector(
            //     AccessControl.AccessControlUnauthorizedAccount.selector,
            //     user,
            //     carbonCredits.ISSUER_ROLE()
            // )
        );
        
        carbonCredits.createProject(
            name,
            description,
            location,
            methodology,
            startDate,
            endDate,
            totalCredits
        );
        
        vm.stopPrank();
    }
    
    function testVerifyProject() public {
        // First create a project
        vm.prank(issuer);
        uint256 projectId = carbonCredits.createProject(
            name,
            description,
            location,
            methodology,
            startDate,
            endDate,
            totalCredits
        );
        
        // Then verify it
        vm.startPrank(verifier);
        
        vm.expectEmit(true, true, false, true);
        emit ProjectVerified(projectId, verifier);
        
        carbonCredits.verifyProject(projectId);
        
        (,,,,,,,,, bool pVerified) = carbonCredits.getProject(projectId);
        assertTrue(pVerified, "Project should be verified");
        
        vm.stopPrank();
    }
    
    function testOnlyVerifierCanVerifyProject() public {
        // First create a project
        vm.prank(issuer);
        uint256 projectId = carbonCredits.createProject(
            name,
            description,
            location,
            methodology,
            startDate,
            endDate,
            totalCredits
        );
        
        // Try to verify with non-verifier
        vm.startPrank(user);
        
        vm.expectRevert(
            // abi.encodeWithSelector(
            //     AccessControl.AccessControlUnauthorizedAccount.selector,
            //     user,
            //     carbonCredits.VERIFIER_ROLE()
            // )
        );
        
        carbonCredits.verifyProject(projectId);
        
        vm.stopPrank();
    }
    
    function testCannotVerifyNonexistentProject() public {
        vm.startPrank(verifier);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.ProjectNotFound.selector,
                999
            )
        );
        
        carbonCredits.verifyProject(999);
        
        vm.stopPrank();
    }
    
    function testCannotVerifyProjectTwice() public {
        // First create and verify a project
        vm.prank(issuer);
        uint256 projectId = carbonCredits.createProject(
            name,
            description,
            location,
            methodology,
            startDate,
            endDate,
            totalCredits
        );
        
        vm.prank(verifier);
        carbonCredits.verifyProject(projectId);
        
        // Try to verify again
        vm.startPrank(verifier);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.ProjectAlreadyVerified.selector,
                projectId
            )
        );
        
        carbonCredits.verifyProject(projectId);
        
        vm.stopPrank();
    }
    
    function testIssueCredits() public {
        // First create and verify a project
        vm.prank(issuer);
        uint256 projectId = carbonCredits.createProject(
            name,
            description,
            location,
            methodology,
            startDate,
            endDate,
            totalCredits
        );
        
        vm.prank(verifier);
        carbonCredits.verifyProject(projectId);
        
        // Issue credits
        vm.startPrank(issuer);
        
        vm.expectEmit(true, true, false, true);
        emit CreditsIssued(projectId, 0, creditAmount, vintage);
        
        uint256 batchId = carbonCredits.issueCredits(
            projectId,
            creditAmount,
            vintage,
            serialNumber
        );
        
        assertEq(batchId, 0, "Batch ID should be 0");
        
        (
            uint256 bAmount,
            uint256 bVintage,
            uint256 bSerial,
            bool bRetired
        ) = carbonCredits.getCreditBatch(projectId, batchId);
        
        assertEq(bAmount, creditAmount, "Batch amount mismatch");
        assertEq(bVintage, vintage, "Batch vintage mismatch");
        assertEq(bSerial, serialNumber, "Batch serial number mismatch");
        assertFalse(bRetired, "Batch should not be retired");
        
        // Check project updated issued credits
        (,,,,,,, uint256 pIssued,,) = carbonCredits.getProject(projectId);
        assertEq(pIssued, creditAmount, "Project issued credits mismatch");
        
        // Check token balance
        uint256 tokenId = (projectId * 1000000) + batchId;
        assertEq(carbonCredits.balanceOf(issuer, tokenId), creditAmount, "Issuer should have credits");
        
        vm.stopPrank();
    }
    
    function testOnlyIssuerCanIssueCredits() public {
        // First create and verify a project
        vm.prank(issuer);
        uint256 projectId = carbonCredits.createProject(
            name,
            description,
            location,
            methodology,
            startDate,
            endDate,
            totalCredits
        );
        
        vm.prank(verifier);
        carbonCredits.verifyProject(projectId);
        
        // Try to issue with non-issuer
        vm.startPrank(user);
        
        vm.expectRevert(
            // abi.encodeWithSelector(
            //     AccessControl.AccessControlUnauthorizedAccount.selector,
            //     user,
            //     carbonCredits.ISSUER_ROLE()
            // )
        );
        
        carbonCredits.issueCredits(
            projectId,
            creditAmount,
            vintage,
            serialNumber
        );
        
        vm.stopPrank();
    }
    
    function testCannotIssueCreditsForUnverifiedProject() public {
        // Create project but don't verify
        vm.prank(issuer);
        uint256 projectId = carbonCredits.createProject(
            name,
            description,
            location,
            methodology,
            startDate,
            endDate,
            totalCredits
        );
        
        // Try to issue credits
        vm.startPrank(issuer);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.ProjectNotVerified.selector,
                projectId
            )
        );
        
        carbonCredits.issueCredits(
            projectId,
            creditAmount,
            vintage,
            serialNumber
        );
        
        vm.stopPrank();
    }
    
    function testCannotExceedTotalCredits() public {
        // First create and verify a project
        vm.prank(issuer);
        uint256 projectId = carbonCredits.createProject(
            name,
            description,
            location,
            methodology,
            startDate,
            endDate,
            totalCredits
        );
        
        vm.prank(verifier);
        carbonCredits.verifyProject(projectId);
        
        // Try to issue more than total credits
        vm.startPrank(issuer);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.ExceedsTotalCredits.selector,
                projectId,
                totalCredits + 1,
                totalCredits
            )
        );
        
        carbonCredits.issueCredits(
            projectId,
            totalCredits + 1,
            vintage,
            serialNumber
        );
        
        vm.stopPrank();
    }
    
    function testRetireCredits() public {
        // Setup: Create project, verify, and issue credits
        vm.prank(issuer);
        uint256 projectId = carbonCredits.createProject(
            name,
            description,
            location,
            methodology,
            startDate,
            endDate,
            totalCredits
        );
        
        vm.prank(verifier);
        carbonCredits.verifyProject(projectId);
        
        vm.prank(issuer);
        uint256 batchId = carbonCredits.issueCredits(
            projectId,
            creditAmount,
            vintage,
            serialNumber
        );
        
        uint256 tokenId = (projectId * 1000000) + batchId;
        uint256 retireAmount = 100;
        
        // Transfer some credits to user
        vm.prank(issuer);
        carbonCredits.safeTransferFrom(issuer, user, tokenId, retireAmount, "");
        
        // Retire credits
        vm.startPrank(user);
        
        vm.expectEmit(true, true, true, true);
        emit CreditsRetired(projectId, batchId, user, retireAmount);
        
        carbonCredits.retireCredits(projectId, batchId, retireAmount);
        
        // Check balances
        assertEq(carbonCredits.balanceOf(user, tokenId), 0, "User should have no credits left");
        assertEq(carbonCredits.retiredCredits(tokenId), retireAmount, "Retired amount mismatch");
        
        // Batch should not be fully retired yet
        (,,, bool bRetired) = carbonCredits.getCreditBatch(projectId, batchId);
        assertFalse(bRetired, "Batch should not be fully retired yet");
        
        vm.stopPrank();
    }
    
    function testRetireFullBatch() public {
        // Setup: Create project, verify, and issue credits
        vm.prank(issuer);
        uint256 projectId = carbonCredits.createProject(
            name,
            description,
            location,
            methodology,
            startDate,
            endDate,
            totalCredits
        );
        
        vm.prank(verifier);
        carbonCredits.verifyProject(projectId);
        
        vm.prank(issuer);
        uint256 batchId = carbonCredits.issueCredits(
            projectId,
            creditAmount,
            vintage,
            serialNumber
        );
        
        // uint256 tokenId = (projectId * 1000000) + batchId;
        
        // Retire all credits
        vm.startPrank(issuer);
        carbonCredits.retireCredits(projectId, batchId, creditAmount);
        
        // Check batch is fully retired
        (,,, bool bRetired) = carbonCredits.getCreditBatch(projectId, batchId);
        assertTrue(bRetired, "Batch should be fully retired");
        
        vm.stopPrank();
    }
    
    function testCannotRetireMoreThanOwned() public {
        // Setup: Create project, verify, and issue credits
        vm.prank(issuer);
        uint256 projectId = carbonCredits.createProject(
            name,
            description,
            location,
            methodology,
            startDate,
            endDate,
            totalCredits
        );
        
        vm.prank(verifier);
        carbonCredits.verifyProject(projectId);
        
        vm.prank(issuer);
        uint256 batchId = carbonCredits.issueCredits(
            projectId,
            creditAmount,
            vintage,
            serialNumber
        );
        
        uint256 tokenId = (projectId * 1000000) + batchId;
        
        // Transfer some credits to user
        vm.prank(issuer);
        carbonCredits.safeTransferFrom(issuer, user, tokenId, 100, "");
        
        // Try to retire more than owned
        vm.startPrank(user);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InsufficientCredits.selector,
                tokenId,
                user,
                200,
                100
            )
        );
        
        carbonCredits.retireCredits(projectId, batchId, 200);
        
        vm.stopPrank();
    }
    
    function testMultipleBatchesForSameProject() public {
        // Create project and verify
        vm.prank(issuer);
        uint256 projectId = carbonCredits.createProject(
            name,
            description,
            location,
            methodology,
            startDate,
            endDate,
            totalCredits
        );
        
        vm.prank(verifier);
        carbonCredits.verifyProject(projectId);
        
        // Issue first batch
        vm.startPrank(issuer);
        uint256 batchId1 = carbonCredits.issueCredits(
            projectId,
            300,
            vintage,
            serialNumber
        );
        
        // Issue second batch
        uint256 batchId2 = carbonCredits.issueCredits(
            projectId,
            400,
            vintage + 1,
            serialNumber + 1
        );
        
        assertEq(batchId1, 0, "First batch ID should be 0");
        assertEq(batchId2, 1, "Second batch ID should be 1");
        
        // Check project issued credits
        (,,,,,, uint256 pTotal, uint256 pIssued,,) = carbonCredits.getProject(projectId);
        assertEq(pIssued, 700, "Project issued credits mismatch");
        assertEq(pTotal, totalCredits, "Project total credits unchanged");
        
        vm.stopPrank();
    }
    
    function testUriGeneration() public {
        // Create project, verify and issue
        vm.prank(issuer);
        uint256 projectId = carbonCredits.createProject(
            name,
            description,
            location,
            methodology,
            startDate,
            endDate,
            totalCredits
        );
        
        vm.prank(verifier);
        carbonCredits.verifyProject(projectId);
        
        vm.prank(issuer);
        uint256 batchId = carbonCredits.issueCredits(
            projectId,
            creditAmount,
            vintage,
            serialNumber
        );
        
        uint256 tokenId = (projectId * 1000000) + batchId;
        
        // Check URI
        string memory tokenUri = carbonCredits.uri(tokenId);
        string memory expectedUri = string(abi.encodePacked(
            "https://carbon-credits-api.com/metadata/{id}",
            "?projectId=", carbonCredits._toString(projectId),
            "&batchId=", carbonCredits._toString(batchId)
        ));
        
        assertEq(tokenUri, expectedUri, "Token URI mismatch");
    }
    
    function testToStringFunction() public view {
        assertEq(carbonCredits._toString(0), "0", "0 to string mismatch");
        assertEq(carbonCredits._toString(1), "1", "1 to string mismatch");
        assertEq(carbonCredits._toString(123), "123", "123 to string mismatch");
        assertEq(carbonCredits._toString(9876543210), "9876543210", "Large number to string mismatch");
    }
}