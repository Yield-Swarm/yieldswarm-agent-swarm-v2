// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IGreatDeltaRouter
/// @notice Treasury split interface for lease + trading revenue routing.
interface IGreatDeltaRouter {
    function routeEmission(uint256 powNonce) external payable returns (uint256 routedWei);
    function treasuries(uint256 index) external view returns (address);
}
