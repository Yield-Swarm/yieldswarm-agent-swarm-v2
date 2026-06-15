// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GreatDeltaEmissionRouter} from "GreatDeltaEmissionRouter.sol";

contract GreatDeltaEmissionRouterTest is Test {
    GreatDeltaEmissionRouter router;

    address signer0 = address(0xA11CE);
    address signer1 = address(0xB0B);
    address signer2 = address(0xC0FFEE);

    address coreTreasury = address(0x1001);
    address growthTreasury = address(0x1002);
    address insuranceTreasury = address(0x1003);
    address opsTreasury = address(0x1004);

    function setUp() public {
        address[3] memory signers = [signer0, signer1, signer2];
        address[4] memory treasuries = [
            coreTreasury,
            growthTreasury,
            insuranceTreasury,
            opsTreasury
        ];
        GreatDeltaEmissionRouter.EmissionConfig memory cfg = GreatDeltaEmissionRouter
            .EmissionConfig({
                baseEmissionWei: 1 ether,
                minPowMultiplierBps: 8_000,
                maxPowMultiplierBps: 12_000,
                minCelestialMultiplierBps: 9_000,
                maxCelestialMultiplierBps: 11_000,
                mandelbrotIterations: 32
            });

        router = new GreatDeltaEmissionRouter(signers, treasuries, cfg);
        vm.deal(address(router), 100 ether);
    }

    function testBpsDenominator() public view {
        assertEq(router.BPS_DENOMINATOR(), 10_000);
    }

    function testPreviewSplit50_30_15_5() public view {
        (uint256 toCore, uint256 toGrowth, uint256 toInsurance, uint256 toOps) = router
            .previewSplit(100);

        assertEq(toCore, 50);
        assertEq(toGrowth, 30);
        assertEq(toInsurance, 15);
        assertEq(toOps, 5);
        assertEq(toCore + toGrowth + toInsurance + toOps, 100);
    }

    function testPreviewSplitZeroDust() public view {
        uint256 amount = 1_000_000_007;
        (uint256 toCore, uint256 toGrowth, uint256 toInsurance, uint256 toOps) = router
            .previewSplit(amount);

        assertEq(toCore + toGrowth + toInsurance + toOps, amount);
    }

    function testRouteEmissionDistributesToTreasuries() public {
        uint256 coreBefore = coreTreasury.balance;
        uint256 growthBefore = growthTreasury.balance;
        uint256 insuranceBefore = insuranceTreasury.balance;
        uint256 opsBefore = opsTreasury.balance;

        router.routeEmission(42);

        assertGt(coreTreasury.balance, coreBefore);
        assertGt(growthTreasury.balance, growthBefore);
        assertGt(insuranceTreasury.balance, insuranceBefore);
        assertGt(opsTreasury.balance, opsBefore);
    }
}
