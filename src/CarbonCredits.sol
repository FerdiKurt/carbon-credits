// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./utils/Counters.sol";

/**
 * @title CarbonCredits
 * @dev Smart contract for carbon credits issuance, transfer, and retirement
 */
contract CarbonCredits is ERC1155, AccessControl {
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

}