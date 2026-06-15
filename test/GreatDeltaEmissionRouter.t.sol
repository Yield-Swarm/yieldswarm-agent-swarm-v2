// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GreatDeltaEmissionRouter} from "../GreatDeltaEmissionRouter.sol";

contract GreatDeltaEmissionRouterTest is Test {
    GreatDeltaEmissionRouter router;

    function setUp() public {
        router = new GreatDeltaEmissionRouter();
    }

    function testBpsDenominator() public view {
        assertEq(router.BPS_DENOMINATOR(), 10_000);
    }
}
