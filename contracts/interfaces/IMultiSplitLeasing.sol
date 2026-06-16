// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IMultiSplitLeasing
/// @notice Lease revenue splits aligned with Great Delta 50/30/15/5.
interface IMultiSplitLeasing {
    struct Lease {
        uint256 leaseId;
        uint256 tokenId;
        address lessee;
        address lessor;
        uint256 startedAt;
        uint256 expiresAt;
        uint256 rateWeiPerDay;
        bool active;
    }

    event LeaseCreated(
        uint256 indexed leaseId,
        uint256 indexed tokenId,
        address indexed lessee,
        uint256 rateWeiPerDay,
        uint256 expiresAt
    );
    event LeaseRevenueDistributed(
        uint256 indexed leaseId,
        uint256 grossWei,
        uint256 lessorShare,
        uint256 protocolShare,
        uint256 growthShare,
        uint256 insuranceShare,
        uint256 opsShare
    );
    event LeaseTerminated(uint256 indexed leaseId, address indexed terminator);

    function createLease(
        uint256 tokenId,
        address lessee,
        uint256 durationSeconds,
        uint256 rateWeiPerDay
    ) external returns (uint256 leaseId);

    function distributeRevenue(uint256 leaseId) external payable;
    function terminateLease(uint256 leaseId) external;
    function leaseOf(uint256 leaseId) external view returns (Lease memory);
}
