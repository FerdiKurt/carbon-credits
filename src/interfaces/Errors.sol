// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
* @dev Standard Errors
* Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors.
*/
interface Errors {
    // Custom errors
    error ProjectNotFound(uint256 projectId);
    error ProjectAlreadyVerified(uint256 projectId);
    error ProjectNotVerified(uint256 projectId);
    error ExceedsTotalCredits(uint256 projectId, uint256 requested, uint256 remaining);
    error InsufficientCredits(uint256 tokenId, address account, uint256 requested, uint256 available);
    error BatchAlreadyRetired(uint256 projectId, uint256 batchId);
    error CreditsFullyRetired(uint256 projectId, uint256 batchId);
    error UnsupportedPaymentToken(address token);
    error ListingNotActive(uint256 listingId);
    error NotSeller(address caller, address seller);
    error ExceedsAvailableAmount(uint256 available, uint256 requested);
    error FeeTooHigh(uint256 fee);
    error InvalidFeeCollector(address feeCollector);
    error InvalidCertificationData(string reason);
    error UnauthorizedAccess(address caller, address expected);
}