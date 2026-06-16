// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title MultiSplitLeasing
/// @notice Greek layer ($D^1$) — multi-tenant lease revenue splitting without rounding leaks.
/// @dev Remainder wei are allocated to the final payee so sum(shares) == amount exactly.
contract MultiSplitLeasing is Ownable, ReentrancyGuard {
    uint256 public constant BPS_DENOMINATOR = 10_000;

    struct TenantShare {
        address payee;
        uint16 bps;
    }

    struct Lease {
        address creator;
        bool active;
        TenantShare[] tenants;
    }

    mapping(bytes32 => Lease) private _leases;
    mapping(bytes32 => uint256) public leaseBalances;

    error InvalidLeaseId();
    error LeaseInactive(bytes32 leaseId);
    error InvalidTenantSet();
    error InvalidBpsTotal(uint256 total);
    error ZeroAmount();
    error TransferFailed(address to, uint256 amount);
    error InsufficientLeaseBalance(bytes32 leaseId, uint256 available, uint256 required);

    event LeaseCreated(bytes32 indexed leaseId, address indexed creator, uint256 tenantCount);
    event LeaseDeactivated(bytes32 indexed leaseId);
    event RevenueDeposited(bytes32 indexed leaseId, address indexed from, uint256 amount);
    event RevenueDistributed(bytes32 indexed leaseId, uint256 amount, uint256 payeeCount);

    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @notice Register a lease with tenant payees and basis-point shares (must sum to 10_000).
    function createLease(bytes32 leaseId, TenantShare[] calldata tenants) external {
        if (leaseId == bytes32(0)) revert InvalidLeaseId();
        if (tenants.length == 0) revert InvalidTenantSet();

        uint256 totalBps;
        for (uint256 i = 0; i < tenants.length; i++) {
            if (tenants[i].payee == address(0)) revert InvalidTenantSet();
            totalBps += tenants[i].bps;
        }
        if (totalBps != BPS_DENOMINATOR) revert InvalidBpsTotal(totalBps);

        Lease storage lease = _leases[leaseId];
        if (lease.active) revert InvalidLeaseId();

        lease.creator = msg.sender;
        lease.active = true;
        delete lease.tenants;

        for (uint256 i = 0; i < tenants.length; i++) {
            lease.tenants.push(tenants[i]);
        }

        emit LeaseCreated(leaseId, msg.sender, tenants.length);
    }

    function deactivateLease(bytes32 leaseId) external {
        Lease storage lease = _leases[leaseId];
        if (!lease.active) revert LeaseInactive(leaseId);
        if (msg.sender != lease.creator && msg.sender != owner()) revert InvalidLeaseId();
        lease.active = false;
        emit LeaseDeactivated(leaseId);
    }

    /// @notice Deposit ETH revenue against a lease for later distribution.
    function depositRevenue(bytes32 leaseId) external payable nonReentrant {
        if (msg.value == 0) revert ZeroAmount();
        Lease storage lease = _leases[leaseId];
        if (!lease.active) revert LeaseInactive(leaseId);
        leaseBalances[leaseId] += msg.value;
        emit RevenueDeposited(leaseId, msg.sender, msg.value);
    }

    /// @notice Distribute the lease balance across tenants with zero dust remainder.
    function distribute(bytes32 leaseId) external nonReentrant returns (uint256 distributed) {
        Lease storage lease = _leases[leaseId];
        if (!lease.active) revert LeaseInactive(leaseId);

        uint256 amount = leaseBalances[leaseId];
        if (amount == 0) revert ZeroAmount();

        leaseBalances[leaseId] = 0;
        distributed = amount;

        uint256 tenantCount = lease.tenants.length;
        uint256 allocated;

        for (uint256 i = 0; i < tenantCount; i++) {
            uint256 share;
            if (i == tenantCount - 1) {
                share = amount - allocated;
            } else {
                share = (amount * lease.tenants[i].bps) / BPS_DENOMINATOR;
                allocated += share;
            }
            _safeTransfer(lease.tenants[i].payee, share);
        }

        emit RevenueDistributed(leaseId, amount, tenantCount);
    }

    /// @notice Preview exact per-tenant allocations for a hypothetical amount.
    function previewSplit(bytes32 leaseId, uint256 amount)
        external
        view
        returns (address[] memory payees, uint256[] memory shares)
    {
        Lease storage lease = _leases[leaseId];
        if (!lease.active) revert LeaseInactive(leaseId);

        uint256 tenantCount = lease.tenants.length;
        payees = new address[](tenantCount);
        shares = new uint256[](tenantCount);

        uint256 allocated;
        for (uint256 i = 0; i < tenantCount; i++) {
            payees[i] = lease.tenants[i].payee;
            if (i == tenantCount - 1) {
                shares[i] = amount - allocated;
            } else {
                shares[i] = (amount * lease.tenants[i].bps) / BPS_DENOMINATOR;
                allocated += shares[i];
            }
        }
    }

    function getTenantCount(bytes32 leaseId) external view returns (uint256) {
        return _leases[leaseId].tenants.length;
    }

    function _safeTransfer(address to, uint256 amount) private {
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert TransferFailed(to, amount);
    }
}
