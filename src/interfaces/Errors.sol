// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @dev Standard Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors.
 */
interface Errors {
    error ProjectDoesNotExist();
    error ProjectAlreadyVerified();
    error AllowedLimitExceeded();
    error InsufficentCredits();
    error CreditsAlreadyRetired();
}
