// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/ICarbonCredits.sol";
import "./interfaces/Errors.sol";

    /**
    * @title CarbonCreditRegistry
    * @notice Registry for tracking carbon credit projects and their certifications
    * @dev Implements certification management for carbon credit projects with authorization controls
    */
contract CarbonCreditRegistry is Errors {
    /// @notice Reference to the CarbonCredits contract
    ICarbonCredits public carbonCredits;
    
    /**
    * @notice Certification data structure
    * @dev Stores all information related to a project certification
    */
    struct Certification {
        /// @notice ID of the certified project
        uint256 projectId;
        /// @notice Name of the certifying entity
        string certifierName;
        /// @notice Standard used for certification (e.g., "Verra", "Gold Standard")
        string certificationStandard;
        /// @notice Unique ID of the certificate
        string certificateId;
        /// @notice Timestamp when the certification was issued
        uint256 issuanceDate;
        /// @notice Timestamp when the certification expires
        uint256 expiryDate;
        /// @notice URI pointing to additional metadata (IPFS, HTTP, etc.)
        string metadataURI;
        /// @notice Address that issued the certification
        address certifier;
    }
    
    // mappings
    mapping(uint256 => Certification[]) public projectCertifications;
    mapping(string => bool) public certifierAuthorized;
    mapping(string => address) public certifierAddress;

    address public owner;
    
    // events
    event CertificationAdded(uint256 indexed projectId, string certifierName, string certificateId);
    event CertifierAuthorized(string certifierName, address certifierAddress);
    event CertifierRevoked(string certifierName);
    
    /**
    * @notice Initializes the registry with a reference to the CarbonCredits contract
    * @dev Sets the contract deployer as the owner
    * @param _carbonCreditsAddress Address of the deployed CarbonCredits contract
    */
    constructor(address _carbonCreditsAddress) {
        carbonCredits = ICarbonCredits(_carbonCreditsAddress);
        owner = msg.sender;
    }
}