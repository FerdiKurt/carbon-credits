// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CarbonCreditsRegistry.sol";

// Interface
interface ICarbonCredit {
    function getProject(uint256 projectId) external view returns (
        string memory name,
        string memory description,
        string memory location,
        string memory methodology,
        uint256 startDate,
        uint256 endDate,
        uint256 totalCredits,
        uint256 issuedCredits,
        address projectOwner,
        bool verified
    );
}

// Mock CarbonCredits
contract MockCarbonCredits is ICarbonCredit {
    mapping(uint256 => Project) private projects;
    uint256 private _projectIdCounter = 0;
    
    struct Project {
        uint256 id;
        string name;
        string description;
        string location;
        string methodology;
        uint256 startDate;
        uint256 endDate;
        uint256 totalCredits;
        uint256 issuedCredits;
        address projectOwner;
        bool verified;
    }
    
    // Event declaration
    event ProjectCreated(uint256 indexed projectId, string name, address indexed creator);
    
    function createProject(
        string memory name,
        string memory description,
        string memory location,
        string memory methodology,
        uint256 startDate,
        uint256 endDate,
        uint256 totalCredits
    ) public returns (uint256) {
        uint256 projectId = _projectIdCounter;
        _projectIdCounter += 1;
        
        Project storage project = projects[projectId];
        project.id = projectId;
        project.name = name;
        project.description = description;
        project.location = location;
        project.methodology = methodology;
        project.startDate = startDate;
        project.endDate = endDate;
        project.totalCredits = totalCredits;
        project.issuedCredits = 0;
        project.projectOwner = msg.sender;
        project.verified = false;
        
        emit ProjectCreated(projectId, name, msg.sender);
        
        return projectId;
    }
    
    function getProject(uint256 projectId) public view returns (
        string memory name,
        string memory description,
        string memory location,
        string memory methodology,
        uint256 startDate,
        uint256 endDate,
        uint256 totalCredits,
        uint256 issuedCredits,
        address projectOwner,
        bool verified
    ) {
        Project storage project = projects[projectId];
        return (
            project.name,
            project.description,
            project.location,
            project.methodology,
            project.startDate,
            project.endDate,
            project.totalCredits,
            project.issuedCredits,
            project.projectOwner,
            project.verified
        );
    }
}

contract CarbonCreditRegistryTest is Test {
    CarbonCreditRegistry public registry;
    MockCarbonCredits public carbonCredits;
    
    address public owner;
    address public certifier1;
    address public certifier2;
    address public unauthorizedUser;
    
    uint256 public projectId;
    
    function setUp() public {
        // Setup accounts
        owner = address(this);
        certifier1 = address(0x1);
        certifier2 = address(0x2);
        unauthorizedUser = address(0x3);
        
        // Deploy contracts
        carbonCredits = new MockCarbonCredits();
        registry = new CarbonCreditRegistry(address(carbonCredits));
        
        // Create a test project
        projectId = carbonCredits.createProject(
            "Test Forest Conservation",
            "A test forest conservation project",
            "Amazon Rainforest",
            "REDD+",
            block.timestamp,
            block.timestamp + 365 days,
            1000
        );
        
        // Authorize certifier1
        registry.authorizeCertifier("Gold Standard", certifier1);
    }
    
    // Test certifier authorization
    function testAuthorizeCertifier() public {
        // Verify that certifier1 is authorized
        assertTrue(registry.isCertifierAuthorized("Gold Standard"));
        assertEq(registry.certifierAddress("Gold Standard"), certifier1);
        
        // Authorize a new certifier
        registry.authorizeCertifier("Verra", certifier2);
        
        // Verify the new certifier is authorized
        assertTrue(registry.isCertifierAuthorized("Verra"));
        assertEq(registry.certifierAddress("Verra"), certifier2);
        assertTrue(registry.wasCertifierEverAuthorized("Verra"));
    }
    
    // Test unauthorized access to authorizeCertifier
    function testUnauthorizedAccessToAuthorizeCertifier() public {
        // Try to authorize a certifier from an unauthorized account
        vm.prank(unauthorizedUser);
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedAccess.selector, unauthorizedUser, owner));
        registry.authorizeCertifier("Invalid", address(0x4));
    }
    
    // Test adding a certification from an authorized certifier
    function testAddCertification() public {
        // Create certification params
        uint256 issuanceDate = block.timestamp;
        uint256 expiryDate = block.timestamp + 365 days;
        
        // Add certification from authorized certifier
        vm.startPrank(certifier1);
        registry.addCertification(
            projectId,
            "Gold Standard",
            "GS VER",
            "GS-1234",
            issuanceDate,
            expiryDate,
            "ipfs://QmTest"
        );
        vm.stopPrank();
        
        // Verify the certification was added
        CarbonCreditRegistry.Certification[] memory certifications = registry.getProjectCertifications(projectId);
        assertEq(certifications.length, 1);
        assertEq(certifications[0].projectId, projectId);
        assertEq(certifications[0].certifierName, "Gold Standard");
        assertEq(certifications[0].certificationStandard, "GS VER");
        assertEq(certifications[0].certificateId, "GS-1234");
        assertEq(certifications[0].issuanceDate, issuanceDate);
        assertEq(certifications[0].expiryDate, expiryDate);
        assertEq(certifications[0].metadataURI, "ipfs://QmTest");
        assertEq(certifications[0].certifier, certifier1);
    }
    
    // Test adding certification from unauthorized user
    function testAddCertificationUnauthorized() public {
        // Try to add certification from unauthorized user
        vm.startPrank(unauthorizedUser);
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedAccess.selector, unauthorizedUser, certifier1));
        registry.addCertification(
            projectId,
            "Gold Standard",
            "GS VER",
            "GS-1234",
            block.timestamp,
            block.timestamp + 365 days,
            "ipfs://QmTest"
        );
        vm.stopPrank();
    }
    
    // Test adding certification with invalid data
    function testAddCertificationInvalidData() public {
        vm.startPrank(certifier1);
        
        // Test empty certifier name
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidCertificationData.selector, "Certifier name and certificate ID are required"));
        registry.addCertification(
            projectId,
            "",
            "GS VER",
            "GS-1234",
            block.timestamp,
            block.timestamp + 365 days,
            "ipfs://QmTest"
        );
        
        // Test empty certificate ID
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidCertificationData.selector, "Certifier name and certificate ID are required"));
        registry.addCertification(
            projectId,
            "Gold Standard",
            "GS VER",
            "",
            block.timestamp,
            block.timestamp + 365 days,
            "ipfs://QmTest"
        );
        
        // Test invalid dates (issuance >= expiry)
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidCertificationData.selector, "Issuance date must be before expiry date"));
        registry.addCertification(
            projectId,
            "Gold Standard",
            "GS VER",
            "GS-1234",
            block.timestamp + 10,
            block.timestamp,
            "ipfs://QmTest"
        );
        
        vm.stopPrank();
    }
    
    // Test adding certification for non-existent project
    function testAddCertificationNonExistentProject() public {
        uint256 nonExistentProjectId = 99999;
        
        vm.startPrank(certifier1);
        vm.expectRevert(abi.encodeWithSelector(Errors.ProjectNotFound.selector, nonExistentProjectId));
        registry.addCertification(
            nonExistentProjectId,
            "Gold Standard",
            "GS VER",
            "GS-1234",
            block.timestamp,
            block.timestamp + 365 days,
            "ipfs://QmTest"
        );
        vm.stopPrank();
    }
    
    // Test revoking a certifier
    function testRevokeCertifier() public {
        // Verify certifier1 is initially authorized
        assertTrue(registry.isCertifierAuthorized("Gold Standard"));
        
        // Revoke certifier1
        registry.revokeCertifier("Gold Standard");
        
        // Verify certifier1 is no longer authorized
        assertFalse(registry.isCertifierAuthorized("Gold Standard"));
        assertTrue(registry.wasCertifierEverAuthorized("Gold Standard"));
        assertTrue(registry.isCertifierRevoked("Gold Standard", certifier1));
        
        // Try to add certification from revoked certifier
        vm.startPrank(certifier1);
        vm.expectRevert(abi.encodeWithSelector(Errors.RevokedCertifier.selector, certifier1, "Gold Standard"));
        registry.addCertification(
            projectId,
            "Gold Standard",
            "GS VER",
            "GS-1234",
            block.timestamp,
            block.timestamp + 365 days,
            "ipfs://QmTest"
        );
        vm.stopPrank();
    }
    
    // Test unauthorized access to revokeCertifier
    function testUnauthorizedAccessToRevokeCertifier() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedAccess.selector, unauthorizedUser, owner));
        registry.revokeCertifier("Gold Standard");
    }
    
    // Test revoking a non-authorized certifier
    function testRevokeNonAuthorizedCertifier() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidCertificationData.selector, "Certifier not authorized"));
        registry.revokeCertifier("Non-Existent Certifier");
    }
    
    // Test re-authorizing a previously revoked certifier
    function testReAuthorizeCertifier() public {
        // Revoke certifier1
        registry.revokeCertifier("Gold Standard");
        assertFalse(registry.isCertifierAuthorized("Gold Standard"));
        assertTrue(registry.isCertifierRevoked("Gold Standard", certifier1));
        
        // Re-authorize certifier1
        registry.authorizeCertifier("Gold Standard", certifier1);
        
        // Verify certifier1 is authorized again
        assertTrue(registry.isCertifierAuthorized("Gold Standard"));
        assertFalse(registry.isCertifierRevoked("Gold Standard", certifier1));
        
        // Verify certifier1 can add certifications again
        vm.startPrank(certifier1);
        registry.addCertification(
            projectId,
            "Gold Standard",
            "GS VER",
            "GS-1234",
            block.timestamp,
            block.timestamp + 365 days,
            "ipfs://QmTest"
        );
        vm.stopPrank();
        
        // Verify the certification was added
        CarbonCreditRegistry.Certification[] memory certifications = registry.getProjectCertifications(projectId);
        assertEq(certifications.length, 1);
    }
    
    // Test transferring ownership
    function testTransferOwnership() public {
        address newOwner = address(0x4);
        
        // Transfer ownership
        registry.transferOwnership(newOwner);
        
        // Verify ownership was transferred
        assertEq(registry.owner(), newOwner);
        
        // Verify old owner can no longer authorize certifiers
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedAccess.selector, owner, newOwner));
        registry.authorizeCertifier("New Certifier", address(0x5));
        
        // Verify new owner can authorize certifiers
        vm.startPrank(newOwner);
        registry.authorizeCertifier("New Certifier", address(0x5));
        vm.stopPrank();
        
        // Verify the certifier was authorized
        assertTrue(registry.isCertifierAuthorized("New Certifier"));
    }
    
    // Test unauthorized access to transferOwnership
    function testUnauthorizedAccessToTransferOwnership() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedAccess.selector, unauthorizedUser, owner));
        registry.transferOwnership(address(0x4));
    }
    
    // Test transferring ownership to zero address
    function testTransferOwnershipToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidCertificationData.selector, "New owner cannot be zero address"));
        registry.transferOwnership(address(0));
    }
    
    // Test multiple certifications for a project
    function testMultipleCertifications() public {
        // Add first certification from certifier1
        vm.startPrank(certifier1);
        registry.addCertification(
            projectId,
            "Gold Standard",
            "GS VER",
            "GS-1234",
            block.timestamp,
            block.timestamp + 365 days,
            "ipfs://QmTest1"
        );
        vm.stopPrank();
        
        // Authorize certifier2
        registry.authorizeCertifier("Verra", certifier2);
        
        // Add second certification from certifier2
        vm.startPrank(certifier2);
        registry.addCertification(
            projectId,
            "Verra",
            "VCS",
            "VCS-5678",
            block.timestamp,
            block.timestamp + 730 days,
            "ipfs://QmTest2"
        );
        vm.stopPrank();
        
        // Verify both certifications were added
        CarbonCreditRegistry.Certification[] memory certifications = registry.getProjectCertifications(projectId);
        assertEq(certifications.length, 2);
        
        // Verify first certification details
        assertEq(certifications[0].certifierName, "Gold Standard");
        assertEq(certifications[0].certificateId, "GS-1234");
        assertEq(certifications[0].certifier, certifier1);
        
        // Verify second certification details
        assertEq(certifications[1].certifierName, "Verra");
        assertEq(certifications[1].certificateId, "VCS-5678");
        assertEq(certifications[1].certifier, certifier2);
    }
}