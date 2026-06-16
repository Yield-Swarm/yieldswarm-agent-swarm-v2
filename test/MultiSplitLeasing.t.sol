// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MultiSplitLeasing} from "../contracts/MultiSplitLeasing.sol";

contract MultiSplitLeasingTest is Test {
    MultiSplitLeasing internal leasing;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xC0C0);
    bytes32 internal leaseId = keccak256("lease-1");

    function setUp() public {
        leasing = new MultiSplitLeasing(address(this));
        MultiSplitLeasing.TenantShare[] memory tenants = new MultiSplitLeasing.TenantShare[](3);
        tenants[0] = MultiSplitLeasing.TenantShare(alice, 5000);
        tenants[1] = MultiSplitLeasing.TenantShare(bob, 3000);
        tenants[2] = MultiSplitLeasing.TenantShare(carol, 2000);
        leasing.createLease(leaseId, tenants);
    }

    function testDistributeNoRoundingLeak() public {
        vm.deal(address(this), 10 ether);
        leasing.depositRevenue{value: 1 ether}(leaseId);

        uint256 beforeAlice = alice.balance;
        uint256 beforeBob = bob.balance;
        uint256 beforeCarol = carol.balance;

        leasing.distribute(leaseId);

        uint256 total = (alice.balance - beforeAlice) + (bob.balance - beforeBob) + (carol.balance - beforeCarol);
        assertEq(total, 1 ether);
    }
}
