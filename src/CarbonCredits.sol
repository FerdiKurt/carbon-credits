// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./utils/Counters.sol";
import "./interfaces/Errors.sol";

/**
 * @title CarbonCredits
 * @dev Smart contract for carbon credits issuance, transfer, and retirement
 */
contract CarbonCredits is ERC1155, AccessControl, Errors {
    using Counters for Counters.Counter;
    
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
    
    constructor() ERC1155("https://carbon-credits-api.com/metadata/{id}") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ISSUER_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
        _projectIdCounter.increment(); // Start with 1
    }

     /**
     * @dev Create a new carbon credit project
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
     * @dev Verify a carbon credit project
     */
    function verifyProject(uint256 projectId) public onlyRole(VERIFIER_ROLE) {
        if(projects[projectId].id == 0) {
            revert ProjectDoesNotExist();
        }
        if(projects[projectId].verified) {
            revert ProjectAlreadyVerified();
        }
        
        projects[projectId].verified = true;
        
        emit ProjectVerified(projectId, msg.sender);
    }
    
    /**
     * @dev Issue carbon credits for a verified project
     */
    function issueCredits(
        uint256 projectId,
        uint256 amount,
        uint256 vintage,
        uint256 serialNumber
    ) public onlyRole(ISSUER_ROLE) returns (uint256) {
        Project storage project = projects[projectId];
        
        if(projects[projectId].id == 0) {
            revert ProjectDoesNotExist();
        }
        if(projects[projectId].verified) {
            revert ProjectAlreadyVerified();
        }
        if(project.issuedCredits + amount > project.totalCredits) {
            revert AllowedLimitExceeded();
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
     * @dev Retire carbon credits
     */
    function retireCredits(uint256 projectId, uint256 batchId, uint256 amount) public {
        uint256 tokenId = (projectId * 1000000) + batchId;

        if(balanceOf(msg.sender, tokenId) < amount) {
            revert InsufficentCredits();
        }
        if(creditBatches[projectId][batchId].retired) {
            revert CreditsAlreadyRetired();
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
}