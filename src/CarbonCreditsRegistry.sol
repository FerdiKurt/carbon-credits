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
    
    // Enhancement: Track revoked certifiers
    mapping(string => bool) public certifierWasEverAuthorized;
    mapping(string => mapping(address => bool)) public revokedCertifiers;

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

    /**
    * @notice Adds a new certification to a carbon credit project
    * @dev Verifies project existence and certifier authorization before adding
    * @param projectId ID of the project being certified
    * @param certifierName Name of the certifying entity
    * @param certificationStandard Standard used for certification
    * @param certificateId Unique ID of the certificate
    * @param issuanceDate Timestamp when the certification was issued
    * @param expiryDate Timestamp when the certification expires
    * @param metadataURI URI pointing to additional metadata
    */
    function addCertification(
        uint256 projectId,
        string memory certifierName,
        string memory certificationStandard,
        string memory certificateId,
        uint256 issuanceDate,
        uint256 expiryDate,
        string memory metadataURI
    ) public {
        // Check if project exists by verifying its name is not empty
        (string memory name, , , , , , , , , ) = carbonCredits.getProject(projectId);
        if (bytes(name).length == 0) {
            revert ProjectNotFound(projectId);
        }
        
        if (bytes(certifierName).length == 0 || bytes(certificateId).length == 0) {
            revert InvalidCertificationData("Certifier name and certificate ID are required");
        }
        
        if (issuanceDate >= expiryDate) {
            revert InvalidCertificationData("Issuance date must be before expiry date");
        }
        
        // Enhancement: Check if this certifier name was ever authorized
        if (certifierWasEverAuthorized[certifierName]) {
            // If the certifier name is currently authorized, check that the sender is authorized
            if (certifierAuthorized[certifierName]) {
                if (certifierAddress[certifierName] != msg.sender) {
                    revert UnauthorizedAccess(msg.sender, certifierAddress[certifierName]);
                }
            } 
            // If the certifier name is not currently authorized, check if the sender was revoked
            else if (revokedCertifiers[certifierName][msg.sender]) {
                revert RevokedCertifier(msg.sender, certifierName);
            }
        }
        
        Certification memory cert = Certification({
            projectId: projectId,
            certifierName: certifierName,
            certificationStandard: certificationStandard,
            certificateId: certificateId,
            issuanceDate: issuanceDate,
            expiryDate: expiryDate,
            metadataURI: metadataURI,
            certifier: msg.sender
        });
        
        projectCertifications[projectId].push(cert);
        
        emit CertificationAdded(projectId, certifierName, certificateId);
    }
    
    /**
    * @notice Retrieves all certifications for a specific project
    * @param projectId ID of the project to query
    * @return Array of Certification structs for the project
    */
    function getProjectCertifications(uint256 projectId) public view returns (Certification[] memory) {
        return projectCertifications[projectId];
    }

    /**
     * @notice Authorizes a certifier to issue certifications
     * @dev Only callable by the contract owner
     * @param certifierName Name of the certifier to authorize
     * @param certifierAddress_ Address of the certifier to authorize
     */
    function authorizeCertifier(string memory certifierName, address certifierAddress_) public {
        if (msg.sender != owner) {
            revert UnauthorizedAccess(msg.sender, owner);
        }
        
        if (bytes(certifierName).length == 0) {
            revert InvalidCertificationData("Certifier name cannot be empty");
        }
        
        if (certifierAddress_ == address(0)) {
            revert InvalidCertificationData("Certifier address cannot be zero");
        }
        
        certifierAuthorized[certifierName] = true;
        certifierAddress[certifierName] = certifierAddress_;
        
        // Enhancement: Track that this certifier name has been authorized
        certifierWasEverAuthorized[certifierName] = true;
        
        // Enhancement: Remove from revoked list if previously revoked
        if (revokedCertifiers[certifierName][certifierAddress_]) {
            revokedCertifiers[certifierName][certifierAddress_] = false;
        }
        
        emit CertifierAuthorized(certifierName, certifierAddress_);
    }
    
    /**
     * @notice Revokes authorization from a certifier
     * @dev Only callable by the contract owner
     * @param certifierName Name of the certifier to revoke
     */
    function revokeCertifier(string memory certifierName) public {
        if (msg.sender != owner) {
            revert UnauthorizedAccess(msg.sender, owner);
        }
        
        if (!certifierAuthorized[certifierName]) {
            revert InvalidCertificationData("Certifier not authorized");
        }
        
        // Enhancement: Track the revoked certifier address
        address revokedAddress = certifierAddress[certifierName];
        revokedCertifiers[certifierName][revokedAddress] = true;
        
        certifierAuthorized[certifierName] = false;
        certifierAddress[certifierName] = address(0);
        
        emit CertifierRevoked(certifierName);
    }
    
    /**
     * @notice Checks if a certifier is currently authorized
     * @param certifierName Name of the certifier to check
     * @return Boolean indicating authorization status
     */
    function isCertifierAuthorized(string memory certifierName) public view returns (bool) {
        return certifierAuthorized[certifierName];
    }
    
    /**
     * @notice Checks if a certifier was ever authorized for a name
     * @param certifierName Name of the certifier to check
     * @return Boolean indicating if the certifier was ever authorized
     */
    function wasCertifierEverAuthorized(string memory certifierName) public view returns (bool) {
        return certifierWasEverAuthorized[certifierName];
    }
    
    /**
     * @notice Checks if a certifier address was revoked for a certifier name
     * @param certifierName Name of the certifier
     * @param certifierAddr Address to check
     * @return Boolean indicating if the address was revoked for the certifier name
     */
    function isCertifierRevoked(string memory certifierName, address certifierAddr) public view returns (bool) {
        return revokedCertifiers[certifierName][certifierAddr];
    }
    
    /**
     * @notice Transfers ownership of the registry to a new address
     * @dev Only callable by the current owner
     * @param newOwner Address of the new owner
     */
    function transferOwnership(address newOwner) public {
        if (msg.sender != owner) {
            revert UnauthorizedAccess(msg.sender, owner);
        }
        
        if (newOwner == address(0)) {
            revert InvalidCertificationData("New owner cannot be zero address");
        }
        
        owner = newOwner;
    }
}