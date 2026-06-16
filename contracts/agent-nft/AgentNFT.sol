// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Chainlink Automation upkeep interface (v2 compatible).
interface IKeeperCompatible {
    function checkUpkeep(bytes calldata checkData) external view returns (bool upkeepNeeded, bytes memory performData);
    function performUpkeep(bytes calldata performData) external;
}

/// @title YieldSwarm Mutating Agent NFT (Sepolia testnet first)
/// @notice Weekly mutation via Sovereign system; fusion + leasing in v2
contract AgentNFT is ERC721, Ownable, IKeeperCompatible {
    uint256 private _nextTokenId;

    struct MutationData {
        uint8 tier;
        uint16 winRateBps;
        uint32 tasksCompleted;
        uint32 lastMutationWeek;
        string metadataURI;
    }

    struct Lease {
        address lessee;
        uint256 expiry;
        bool active;
        uint8 revenueSplitLesseeBps;
    }

    mapping(uint256 => MutationData) public mutations;
    mapping(uint256 => Lease) public leases;
    mapping(address => uint256) public agentToToken;

    address public sovereignSystem;
    address public mutationController;
    uint256 public lastMutationWeek;

    event NFTMutated(uint256 indexed tokenId, uint8 newTier, string newURI);
    event WeeklyMutationTriggered(uint256 week);
    event NFTLeased(uint256 indexed tokenId, address lessee, uint8 revenueSplitBps);

    constructor() ERC721("YieldSwarm Agent", "YSA") Ownable(msg.sender) {}

    function setSovereignSystem(address _sovereign) external onlyOwner {
        sovereignSystem = _sovereign;
    }

    function setMutationController(address _controller) external onlyOwner {
        mutationController = _controller;
    }

    function mintAgentNFT(address to) external returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        mutations[tokenId] = MutationData({
            tier: 1,
            winRateBps: 0,
            tasksCompleted: 0,
            lastMutationWeek: 0,
            metadataURI: ""
        });
        agentToToken[to] = tokenId;
        return tokenId;
    }

    function mutate(uint256 tokenId, uint8 newTier, uint16 newWinRateBps, string calldata newURI) external {
        require(
            msg.sender == sovereignSystem || msg.sender == owner() || msg.sender == mutationController,
            "Not authorized"
        );
        require(_ownerOf(tokenId) != address(0), "No token");
        MutationData storage data = mutations[tokenId];
        data.tier = newTier;
        data.winRateBps = newWinRateBps;
        data.lastMutationWeek = uint32(block.timestamp / 1 weeks);
        data.metadataURI = newURI;
        emit NFTMutated(tokenId, newTier, newURI);
    }

    function triggerWeeklyMutation() external {
        require(
            msg.sender == sovereignSystem || msg.sender == owner() || msg.sender == address(this),
            "Not authorized"
        );
        uint256 week = block.timestamp / 1 weeks;
        require(week > lastMutationWeek, "Already triggered");
        lastMutationWeek = week;
        emit WeeklyMutationTriggered(week);
    }

    /// @inheritdoc IKeeperCompatible
    function checkUpkeep(bytes calldata /* checkData */)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        uint256 currentWeek = block.timestamp / 1 weeks;
        upkeepNeeded = currentWeek > lastMutationWeek;
        performData = abi.encode(currentWeek);
    }

    /// @inheritdoc IKeeperCompatible
    function performUpkeep(bytes calldata performData) external override {
        uint256 currentWeek = abi.decode(performData, (uint256));
        require(currentWeek > lastMutationWeek, "Already mutated this week");
        lastMutationWeek = currentWeek;
        emit WeeklyMutationTriggered(currentWeek);
    }

    function leaseNFT(uint256 tokenId, uint256 durationDays, uint8 revenueSplitLesseeBps) external payable {
        require(_ownerOf(tokenId) != address(0), "No token");
        require(!leases[tokenId].active, "Leased");
        require(revenueSplitLesseeBps <= 9000, "Split too high");
        leases[tokenId] = Lease({
            lessee: msg.sender,
            expiry: block.timestamp + durationDays * 1 days,
            active: true,
            revenueSplitLesseeBps: revenueSplitLesseeBps
        });
        emit NFTLeased(tokenId, msg.sender, revenueSplitLesseeBps);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return mutations[tokenId].metadataURI;
    }

    function getAgentTier(uint256 tokenId) external view returns (uint8) {
        return mutations[tokenId].tier;
    }

    function getAgentMutationTier(uint256 tokenId) external view returns (uint8) {
        return mutations[tokenId].tier;
    }
}
