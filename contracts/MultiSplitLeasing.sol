// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IMultiSplitLeasing} from "./interfaces/IMultiSplitLeasing.sol";
import {IYieldSwarmNFT} from "./interfaces/IYieldSwarmNFT.sol";
import {IGreatDeltaRouter} from "./interfaces/IGreatDeltaRouter.sol";

/// @title MultiSplitLeasing
/// @notice Agent NFT leasing with automatic Great Delta 50/30/15/5 revenue split.
contract MultiSplitLeasing is IMultiSplitLeasing {
    uint256 public constant BPS = 10_000;
    uint256 public constant LESSOR_BPS = 5000; // 50% to lessor
    uint256 public constant GROWTH_BPS = 3000; // 30%
    uint256 public constant INSURANCE_BPS = 1500; // 15%
    uint256 public constant OPS_BPS = 500; // 5%

    IYieldSwarmNFT public immutable nft;
    IGreatDeltaRouter public treasuryRouter;
    address public owner;

    uint256 private _nextLeaseId = 1;
    mapping(uint256 => Lease) private _leases;
    mapping(uint256 => uint256) public activeLeaseByToken;

    error NotOwner();
    error NotLessor();
    error LeaseNotActive();
    error TokenAlreadyLeased();
    error InvalidDuration();
    error TransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address nftAddress, address initialOwner) {
        nft = IYieldSwarmNFT(nftAddress);
        owner = initialOwner;
    }

    function setTreasuryRouter(address router) external onlyOwner {
        treasuryRouter = IGreatDeltaRouter(router);
    }

    function createLease(
        uint256 tokenId,
        address lessee,
        uint256 durationSeconds,
        uint256 rateWeiPerDay
    ) external returns (uint256 leaseId) {
        if (nft.ownerOf(tokenId) != msg.sender) revert NotLessor();
        if (activeLeaseByToken[tokenId] != 0) revert TokenAlreadyLeased();
        if (durationSeconds < 1 days || durationSeconds > 365 days) revert InvalidDuration();

        leaseId = _nextLeaseId++;
        _leases[leaseId] = Lease({
            leaseId: leaseId,
            tokenId: tokenId,
            lessee: lessee,
            lessor: msg.sender,
            startedAt: block.timestamp,
            expiresAt: block.timestamp + durationSeconds,
            rateWeiPerDay: rateWeiPerDay,
            active: true
        });
        activeLeaseByToken[tokenId] = leaseId;

        emit LeaseCreated(leaseId, tokenId, lessee, rateWeiPerDay, block.timestamp + durationSeconds);
    }

    function distributeRevenue(uint256 leaseId) external payable {
        Lease memory lease = _leases[leaseId];
        if (!lease.active) revert LeaseNotActive();

        uint256 gross = msg.value;
        uint256 lessorShare = (gross * LESSOR_BPS) / BPS;
        uint256 protocolShare = gross - lessorShare;
        uint256 growthShare = (protocolShare * GROWTH_BPS) / (GROWTH_BPS + INSURANCE_BPS + OPS_BPS);
        uint256 insuranceShare = (protocolShare * INSURANCE_BPS) / (GROWTH_BPS + INSURANCE_BPS + OPS_BPS);
        uint256 opsShare = protocolShare - growthShare - insuranceShare;

        (bool ok,) = lease.lessor.call{value: lessorShare}("");
        if (!ok) revert TransferFailed();

        if (address(treasuryRouter) != address(0)) {
            treasuryRouter.routeEmission{value: protocolShare}(block.prevrandao);
        } else {
            _splitFallback(growthShare, insuranceShare, opsShare);
        }

        emit LeaseRevenueDistributed(
            leaseId, gross, lessorShare, protocolShare, growthShare, insuranceShare, opsShare
        );
    }

    function terminateLease(uint256 leaseId) external {
        Lease storage lease = _leases[leaseId];
        if (!lease.active) revert LeaseNotActive();
        if (msg.sender != lease.lessor && msg.sender != lease.lessee && msg.sender != owner) {
            revert NotLessor();
        }
        lease.active = false;
        activeLeaseByToken[lease.tokenId] = 0;
        emit LeaseTerminated(leaseId, msg.sender);
    }

    function leaseOf(uint256 leaseId) external view returns (Lease memory) {
        return _leases[leaseId];
    }

    function _splitFallback(uint256 growth, uint256 insurance, uint256 ops) internal {
        // Owner receives protocol share when treasury router not wired (testnet fallback).
        uint256 total = growth + insurance + ops;
        if (total > 0) {
            (bool ok,) = owner.call{value: total}("");
            if (!ok) revert TransferFailed();
        }
    }
}
