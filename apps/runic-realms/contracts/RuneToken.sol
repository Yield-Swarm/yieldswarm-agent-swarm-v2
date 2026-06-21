// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title RuneToken — $RUNE earned via proof-of-compute gameplay on Runic Chain
 * @dev MVP stub; deploy to Runic Chain / Apollo Nexus when mainnet ready
 */
contract RuneToken {
    string public name = "Runic Realms Token";
    string public symbol = "RUNE";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event ComputeMined(address indexed player, bytes32 proofHash, uint256 amount);

    function mintFromCompute(address player, bytes32 proofHash, uint256 amount) external {
        balanceOf[player] += amount;
        totalSupply += amount;
        emit ComputeMined(player, proofHash, amount);
        emit Transfer(address(0), player, amount);
    }
}
