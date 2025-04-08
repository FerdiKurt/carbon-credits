// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./utils/Counters.sol";
import "./interfaces/Errors.sol";

/**
 * @title CarbonCredits
 * @notice Smart contract for tokenizing, issuing, transferring, and retiring carbon credits
 * @dev Implements ERC1155 standard for carbon credit tokenization with role-based access control
 */
contract CarbonCredits is ERC1155, AccessControl, Errors {
    using Counters for Counters.Counter;
    
    // Roles
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    
    Counters.Counter private _projectIdCounter;
    
    // Project data structure
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
    
    // Credit data structure
    struct CreditBatch {
        uint256 projectId;
        uint256 batchId;
        uint256 amount;
        uint256 vintage; // Year the carbon offset occurred
        uint256 serialNumber;
        bool retired;
    }
    
    // Mappings
    mapping(uint256 => Project) public projects;
    mapping(uint256 => mapping(uint256 => CreditBatch)) public creditBatches;
    mapping(uint256 => uint256) private _nextBatchId;
    mapping(uint256 => uint256) public retiredCredits;

    // Events
    event ProjectCreated(uint256 indexed projectId, string name, address indexed owner);
    event ProjectVerified(uint256 indexed projectId, address indexed verifier);
    event CreditsIssued(uint256 indexed projectId, uint256 indexed batchId, uint256 amount, uint256 vintage);
    event CreditsRetired(uint256 indexed projectId, uint256 indexed batchId, address indexed retiredBy, uint256 amount);
    
    /**
     * @notice Initializes the CarbonCredits contract
     * @dev Sets up initial roles and metadata URI base
     */
    constructor() ERC1155("https://carbon-credits-api.com/metadata/{id}") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ISSUER_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
        _projectIdCounter.increment(); // Start with 1
    }

     /**
     * @notice Creates a new carbon credit project
     * @dev Projects must be verified before credits can be issued
     * @param name The name of the project
     * @param description A detailed description of the project
     * @param location The geographical location of the project
     * @param methodology The carbon accounting methodology used
     * @param startDate The start date of the project (timestamp)
     * @param endDate The end date of the project (timestamp)
     * @param totalCredits The total credits that can be issued for this project
     * @return projectId The ID of the newly created project
     */
    function createProject(
        string memory name,
        string memory description,
        string memory location,
        string memory methodology,
        uint256 startDate,
        uint256 endDate,
        uint256 totalCredits
    ) public onlyRole(ISSUER_ROLE)  returns (uint256){
        uint256 projectId = _projectIdCounter.current();
        _projectIdCounter.increment();
        
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
    
    /**
     * @notice Verifies a carbon credit project
     * @dev Only accounts with VERIFIER_ROLE can verify projects
     * @param projectId The ID of the project to verify
     */
    function verifyProject(uint256 projectId) public onlyRole(VERIFIER_ROLE) {
        Project storage project = projects[projectId];

        if(project.id == 0) {
            revert ProjectNotFound(projectId);
        }
        if(project.verified) {
            revert ProjectAlreadyVerified(projectId);
        }
        
        project.verified = true;
        
        emit ProjectVerified(projectId, msg.sender);
    }
    
    /**
     * @notice Issues carbon credits for a verified project
     * @dev Only accounts with ISSUER_ROLE can issue credits
     * @param projectId The ID of the project to issue credits for
     * @param amount The amount of credits to issue
     * @param vintage The vintage year of the credits
     * @param serialNumber The serial number for the credit batch
     * @return batchId The ID of the newly created credit batch
     */
    function issueCredits(
        uint256 projectId,
        uint256 amount,
        uint256 vintage,
        uint256 serialNumber
    ) public onlyRole(ISSUER_ROLE) returns (uint256) {
        Project storage project = projects[projectId];
        
        if(project.id == 0) {
            revert ProjectNotFound(projectId);
        }
        if(!project.verified) {
            revert ProjectNotVerified(projectId);
        }
        
        uint256 remainingCredits = project.totalCredits - project.issuedCredits;
        if (amount > remainingCredits) {
            revert ExceedsTotalCredits(projectId, amount, remainingCredits);
        }
        
        uint256 batchId = _nextBatchId[projectId];
        _nextBatchId[projectId]++;
        
        uint256 tokenId = (projectId * 1000000) + batchId;
        
        // Create credit batch
        CreditBatch storage batch = creditBatches[projectId][batchId];
        batch.projectId = projectId;
        batch.batchId = batchId;
        batch.amount = amount;
        batch.vintage = vintage;
        batch.serialNumber = serialNumber;
        batch.retired = false;
        
        // Update project issued credits
        project.issuedCredits += amount;
        
        // Mint new tokens to project owner
        _mint(project.projectOwner, tokenId, amount, "");
        
        emit CreditsIssued(projectId, batchId, amount, vintage);
        
        return batchId;
    }

    /**
     * @notice Retires carbon credits permanently
     * @dev Retired credits cannot be transferred or used again
     * @param projectId The ID of the project
     * @param batchId The ID of the credit batch
     * @param amount The amount of credits to retire
     */
    function retireCredits(uint256 projectId, uint256 batchId, uint256 amount) public {
        uint256 tokenId = (projectId * 1000000) + batchId;
        uint256 balance = balanceOf(msg.sender, tokenId);


        if(balance < amount) {
            revert InsufficientCredits(tokenId, msg.sender, amount, balance);
        }
        if(creditBatches[projectId][batchId].retired) {
            revert BatchAlreadyRetired(projectId, batchId);
        }
        
        // Burn the tokens
        _burn(msg.sender, tokenId, amount);
        
        // Update retirement tracking
        retiredCredits[tokenId] += amount;
        
        // Mark as retired if all credits in batch are retired
        if (retiredCredits[tokenId] >= creditBatches[projectId][batchId].amount) {
            creditBatches[projectId][batchId].retired = true;
        }
        
        emit CreditsRetired(projectId, batchId, msg.sender, amount);
    }

    /**
     * @notice Gets all details of a carbon project
     * @param projectId The ID of the project
     * @return name The name of the project
     * @return description The description of the project
     * @return location The location of the project
     * @return methodology The methodology used by the project
     * @return startDate The start date of the project
     * @return endDate The end date of the project
     * @return totalCredits The total credits allocated to the project
     * @return issuedCredits The amount of credits already issued
     * @return projectOwner The address of the project owner
     * @return verified Whether the project has been verified
     */
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
    
    /**
     * @notice Gets details of a specific credit batch
     * @param projectId The ID of the project
     * @param batchId The ID of the batch
     * @return amount The amount of credits in the batch
     * @return vintage The vintage year of the credits
     * @return serialNumber The serial number of the batch
     * @return retired Whether the batch has been fully retired
     */
    function getCreditBatch(uint256 projectId, uint256 batchId) public view returns (
        uint256 amount,
        uint256 vintage,
        uint256 serialNumber,
        bool retired
    ) {
        CreditBatch storage batch = creditBatches[projectId][batchId];
        return (
            batch.amount,
            batch.vintage,
            batch.serialNumber,
            batch.retired
        );
    }
    
    /**
     * @notice Returns the metadata URI for a specific token
     * @dev Overrides ERC1155 uri function to include project and batch IDs
     * @param tokenId The ID of the token
     * @return The URI for the token metadata
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        uint256 projectId = tokenId / 1000000;
        uint256 batchId = tokenId % 1000000;
        
        return string(abi.encodePacked(
            super.uri(tokenId),
            "?projectId=", _toString(projectId),
            "&batchId=", _toString(batchId)
        ));
    }

    /**
     * @notice Checks if a contract implements a specific interface
     * @dev Required override for OpenZeppelin contracts
     * @param interfaceId The interface identifier to check
     * @return True if the contract implements the interface, false otherwise
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice Converts a uint256 to its string representation
     * @dev Helper function for URI generation
     * @param value The uint256 to convert
     * @return The string representation of the uint256
     */
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        
        uint256 temp = value;
        uint256 digits;
        
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(digits);
        
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        
        return string(buffer);
    }
}