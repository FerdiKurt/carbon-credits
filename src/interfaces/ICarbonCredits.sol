// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;


/**
* @title ICarbonCredits
* @dev Interface for the Carbon Credits ERC1155 token with project management functionality
*/
interface ICarbonCredits {
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
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