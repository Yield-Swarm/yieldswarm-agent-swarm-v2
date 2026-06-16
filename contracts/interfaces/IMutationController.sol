// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IYieldSwarmNFT} from "./IYieldSwarmNFT.sol";

/// @title IMutationController
/// @notice Weekly mutation gate — Paradigm Shift layer co-creation boundary.
interface IMutationController {
    event MutationScheduled(uint256 indexed tokenId, uint32 epoch, bytes32 entropySeed);
    event MutationExecuted(uint256 indexed tokenId, uint32 epoch, bytes32 newGenomeHash);
    event MutationSkipped(uint256 indexed tokenId, string reason);

    function mutationInterval() external view returns (uint256);
    function lastMutationEpoch(uint256 tokenId) external view returns (uint32);

    function canMutate(uint256 tokenId) external view returns (bool);
    function scheduleMutation(uint256 tokenId, bytes32 entropySeed) external;
    function executeMutation(
        uint256 tokenId,
        bytes32 newGenomeHash,
        IYieldSwarmNFT.AgentGenome calldata genome
    ) external;
}
