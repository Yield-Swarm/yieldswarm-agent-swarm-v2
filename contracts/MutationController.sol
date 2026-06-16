// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IMutationController} from "./interfaces/IMutationController.sol";
import {IYieldSwarmNFT} from "./interfaces/IYieldSwarmNFT.sol";

/// @title MutationController
/// @notice Weekly mutation engine with Chainlink Automation compatibility.
/// @dev Greek: auditable gates. Eastern: entropy-driven emergence. PDs: co-evolution loop.
contract MutationController is IMutationController {
    uint256 public constant DEFAULT_INTERVAL = 7 days;
    uint256 public constant MAX_INTERVAL = 30 days;

    IYieldSwarmNFT public immutable nft;
    address public owner;
    address public oracleBridge;
    address public automationForwarder;

    uint256 public mutationInterval = DEFAULT_INTERVAL;
    uint256 public epochCounter;

    mapping(uint256 => uint32) public lastMutationEpoch;
    mapping(uint256 => bytes32) public scheduledEntropy;
    mapping(uint256 => bool) public mutationPending;

    error NotOwner();
    error NotAuthorized();
    error MutationNotReady();
    error MutationNotScheduled();
    error InvalidInterval();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOracleOrAutomation() {
        if (msg.sender != oracleBridge && msg.sender != automationForwarder && msg.sender != owner) {
            revert NotAuthorized();
        }
        _;
    }

    constructor(address nftAddress, address initialOwner) {
        nft = IYieldSwarmNFT(nftAddress);
        owner = initialOwner;
    }

    function setOracleBridge(address bridge) external onlyOwner {
        oracleBridge = bridge;
    }

    function setAutomationForwarder(address forwarder) external onlyOwner {
        automationForwarder = forwarder;
    }

    function setMutationInterval(uint256 interval) external onlyOwner {
        if (interval < 1 days || interval > MAX_INTERVAL) revert InvalidInterval();
        mutationInterval = interval;
    }

    function canMutate(uint256 tokenId) public view returns (bool) {
        IYieldSwarmNFT.AgentGenome memory genome = nft.genomeOf(tokenId);
        return block.timestamp >= uint256(genome.lastMutationAt) + mutationInterval;
    }

    function scheduleMutation(uint256 tokenId, bytes32 entropySeed) external onlyOracleOrAutomation {
        if (!canMutate(tokenId)) {
            emit MutationSkipped(tokenId, "interval_not_elapsed");
            return;
        }
        epochCounter++;
        lastMutationEpoch[tokenId] = uint32(epochCounter);
        scheduledEntropy[tokenId] = entropySeed;
        mutationPending[tokenId] = true;
        emit MutationScheduled(tokenId, uint32(epochCounter), entropySeed);
    }

    function executeMutation(
        uint256 tokenId,
        bytes32 newGenomeHash,
        IYieldSwarmNFT.AgentGenome calldata genome
    ) external onlyOracleOrAutomation {
        if (!mutationPending[tokenId]) revert MutationNotScheduled();

        IYieldSwarmNFT.AgentGenome memory updated = genome;
        updated.mutationEpoch = lastMutationEpoch[tokenId];
        updated.lastMutationAt = uint64(block.timestamp);

        nft.updateGenome(tokenId, updated, newGenomeHash);
        mutationPending[tokenId] = false;
        delete scheduledEntropy[tokenId];

        emit MutationExecuted(tokenId, lastMutationEpoch[tokenId], newGenomeHash);
    }

    /// @notice Chainlink Automation check — returns tokens ready for mutation.
    function checkUpkeep(bytes calldata) external view returns (bool upkeepNeeded, bytes memory performData) {
        uint256 supply = nft.totalSupply();
        uint256[] memory ready = new uint256[](supply);
        uint256 count;

        for (uint256 i = 1; i <= supply && count < 32; i++) {
            try nft.ownerOf(i) returns (address) {
                if (canMutate(i) && !mutationPending[i]) {
                    ready[count++] = i;
                }
            } catch {}
        }

        if (count == 0) return (false, "");
        uint256[] memory batch = new uint256[](count);
        for (uint256 j = 0; j < count; j++) batch[j] = ready[j];
        return (true, abi.encode(batch));
    }

    function performUpkeep(bytes calldata performData) external onlyOracleOrAutomation {
        uint256[] memory tokenIds = abi.decode(performData, (uint256[]));
        for (uint256 i = 0; i < tokenIds.length; i++) {
            bytes32 seed = keccak256(abi.encode(block.prevrandao, tokenIds[i], block.timestamp));
            scheduleMutation(tokenIds[i], seed);
        }
    }
}
