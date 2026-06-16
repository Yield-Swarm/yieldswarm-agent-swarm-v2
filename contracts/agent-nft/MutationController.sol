// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IAgentNFTMutator {
    function mutate(uint256 tokenId, uint8 newTier, uint16 newWinRateBps, string calldata newURI) external;
    function triggerWeeklyMutation() external;
}

/// @title MutationController — Chainlink Functions fulfillment + oracle relay
/// @notice Decodes DON responses and applies mutations on AgentNFT.
contract MutationController is Ownable {
    IAgentNFTMutator public agentNFT;
    address public oracleRelayer;

    event MutationRequested(bytes32 indexed requestId, uint256 indexed tokenId);
    event MutationFulfilled(bytes32 indexed requestId, uint256 indexed tokenId, uint8 tier);
    event MutationFailed(bytes32 indexed requestId, bytes err);

    constructor(address _agentNFT) Ownable(msg.sender) {
        agentNFT = IAgentNFTMutator(_agentNFT);
    }

    function setAgentNFT(address _agentNFT) external onlyOwner {
        agentNFT = IAgentNFTMutator(_agentNFT);
    }

    function setOracleRelayer(address _relayer) external onlyOwner {
        oracleRelayer = _relayer;
    }

    /// @notice Relay path for off-chain oracle bridge (Chainlink Functions fulfillment proxy).
    function executeAgentMutation(
        uint256 tokenId,
        bytes32 requestId,
        bytes calldata response,
        bytes calldata err
    ) external {
        require(msg.sender == oracleRelayer || msg.sender == owner(), "Not relayer");
        emit MutationRequested(requestId, tokenId);

        if (err.length > 0) {
            emit MutationFailed(requestId, err);
            return;
        }

        (uint256 decodedId, uint8 tier, uint16 winRateBps, string memory uri) =
            abi.decode(response, (uint256, uint8, uint16, string));
        require(decodedId == tokenId, "tokenId mismatch");

        agentNFT.mutate(tokenId, tier, winRateBps, uri);
        emit MutationFulfilled(requestId, tokenId, tier);
    }

    /// @notice Weekly batch trigger — Automation or sovereign system.
    function triggerWeeklyBatch() external {
        require(msg.sender == oracleRelayer || msg.sender == owner(), "Not relayer");
        agentNFT.triggerWeeklyMutation();
    }
}
