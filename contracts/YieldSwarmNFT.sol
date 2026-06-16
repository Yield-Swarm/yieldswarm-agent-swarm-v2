// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title YieldSwarmNFT
/// @notice Minimal ERC-721-style NFT with entropy-driven metadata mutation.
contract YieldSwarmNFT {
    string public name;
    string public symbol;

    address public mutationController;
    uint256 private _nextTokenId = 1;

    struct MutationRecord {
        bytes32 seed;
        uint256 commitment;
        uint256 quality;
        uint64 mutatedAt;
    }

    mapping(uint256 => address) private _owners;
    mapping(uint256 => MutationRecord) public mutations;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Mutation(
        uint256 indexed tokenId,
        bytes32 seed,
        uint256 commitment,
        uint256 quality
    );

    error NotOwner();
    error NotMutationController();
    error TokenDoesNotExist(uint256 tokenId);
    error InvalidRecipient();

    modifier onlyController() {
        if (msg.sender != mutationController) revert NotMutationController();
        _;
    }

    error ControllerAlreadySet();

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    function setMutationController(address controller_) external {
        if (mutationController != address(0)) revert ControllerAlreadySet();
        if (controller_ == address(0)) revert InvalidRecipient();
        mutationController = controller_;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert TokenDoesNotExist(tokenId);
        return owner;
    }

    function mint(address to) external returns (uint256 tokenId) {
        if (to == address(0)) revert InvalidRecipient();
        tokenId = _nextTokenId++;
        _owners[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }

    function mutate(
        uint256 tokenId,
        bytes32 seed,
        uint256 commitment,
        uint256 quality
    ) external onlyController {
        if (_owners[tokenId] == address(0)) revert TokenDoesNotExist(tokenId);
        mutations[tokenId] = MutationRecord({
            seed: seed,
            commitment: commitment,
            quality: quality,
            mutatedAt: uint64(block.timestamp)
        });
        emit Mutation(tokenId, seed, commitment, quality);
    }
}
