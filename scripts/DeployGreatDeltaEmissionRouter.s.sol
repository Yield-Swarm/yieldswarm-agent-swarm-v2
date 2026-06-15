// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/GreatDeltaEmissionRouter.sol";

/// @notice Foundry deployment script for GreatDeltaEmissionRouter.
contract DeployGreatDeltaEmissionRouter is Script {
    function run() external returns (GreatDeltaEmissionRouter router) {
        address[3] memory signers = [
            vm.envAddress("GD_SIGNER_0"),
            vm.envAddress("GD_SIGNER_1"),
            vm.envAddress("GD_SIGNER_2")
        ];

        address[4] memory treasuries = [
            vm.envAddress("GD_TREASURY_CORE"),
            vm.envAddress("GD_TREASURY_GROWTH"),
            vm.envAddress("GD_TREASURY_INSURANCE"),
            vm.envAddress("GD_TREASURY_OPS")
        ];

        GreatDeltaEmissionRouter.EmissionConfig memory cfg = GreatDeltaEmissionRouter
            .EmissionConfig({
                baseEmissionWei: vm.envUint("GD_BASE_EMISSION_WEI"),
                minPowMultiplierBps: uint16(vm.envUint("GD_MIN_POW_BPS")),
                maxPowMultiplierBps: uint16(vm.envUint("GD_MAX_POW_BPS")),
                minCelestialMultiplierBps: uint16(vm.envUint("GD_MIN_CELESTIAL_BPS")),
                maxCelestialMultiplierBps: uint16(vm.envUint("GD_MAX_CELESTIAL_BPS")),
                mandelbrotIterations: uint8(vm.envUint("GD_MANDELBROT_ITERATIONS"))
            });

        uint256 privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        uint256 seedReserve = vm.envOr("GD_SEED_RESERVE_WEI", uint256(0));

        vm.startBroadcast(privateKey);
        router = new GreatDeltaEmissionRouter{value: seedReserve}(signers, treasuries, cfg);
        vm.stopBroadcast();
    }
}
