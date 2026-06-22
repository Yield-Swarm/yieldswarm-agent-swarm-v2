// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IAgentLeaseReader {
    struct Lease {
        address lessee;
        uint256 expiry;
        bool active;
        uint8 revenueSplitLesseeBps;
    }

    function leases(uint256 tokenId) external view returns (Lease memory);
}

/// @title MultiSplitLeasing — distribute lease revenue across owner, lessee, treasury
contract MultiSplitLeasing is Ownable, ReentrancyGuard {
    IAgentLeaseReader public agentNFT;

  address public treasury;
  uint16 public treasurySplitBps = 1000; // 10% platform fee on lease revenue

  event RevenueDistributed(
    uint256 indexed tokenId,
    address indexed owner,
    address indexed lessee,
    uint256 ownerAmount,
    uint256 lesseeAmount,
    uint256 treasuryAmount
  );

  constructor(address _agentNFT, address _treasury) Ownable(msg.sender) {
    agentNFT = IAgentLeaseReader(_agentNFT);
    treasury = _treasury;
  }

  function setTreasury(address _treasury) external onlyOwner {
    treasury = _treasury;
  }

  function setTreasurySplitBps(uint8 bps) external onlyOwner {
    require(bps <= 2000, "Max 20%");
    treasurySplitBps = bps;
  }

  /// @notice Split incoming lease payment by active lease terms.
  function distributeLeaseRevenue(uint256 tokenId, address nftOwner) external payable nonReentrant {
    require(msg.value > 0, "No revenue");
    IAgentLeaseReader.Lease memory lease = agentNFT.leases(tokenId);

    uint256 treasuryAmount = (msg.value * treasurySplitBps) / 10_000;
    uint256 remainder = msg.value - treasuryAmount;

    uint256 lesseeAmount;
    uint256 ownerAmount;

    if (lease.active && block.timestamp <= lease.expiry) {
      lesseeAmount = (remainder * lease.revenueSplitLesseeBps) / 10_000;
      ownerAmount = remainder - lesseeAmount;
      if (lesseeAmount > 0 && lease.lessee != address(0)) {
        (bool okLessee,) = lease.lessee.call{ value: lesseeAmount }("");
        require(okLessee, "Lessee transfer failed");
      }
    } else {
      ownerAmount = remainder;
    }

    if (ownerAmount > 0) {
      (bool okOwner,) = nftOwner.call{ value: ownerAmount }("");
      require(okOwner, "Owner transfer failed");
    }
    if (treasuryAmount > 0 && treasury != address(0)) {
      (bool okTreasury,) = treasury.call{ value: treasuryAmount }("");
      require(okTreasury, "Treasury transfer failed");
    }

    emit RevenueDistributed(
      tokenId,
      nftOwner,
      lease.lessee,
      ownerAmount,
      lease.active ? lesseeAmount : 0,
      treasuryAmount
    );
  }
}
