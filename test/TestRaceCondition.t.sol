// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "src/BecReentrancy.sol";

contract RaceConditionTest is Test {
    StandardToken token;
    address user1 = address(0x1);
    address user2 = address(0x2);
    address spender = address(0x3);

    function setUp() public {
        token = new StandardToken();
        deal(address(token), user1, 1000);
    }

    function testRaceCondition() public {

        vm.prank(user1);
        token.approve(spender, 500);


        vm.prank(spender);
        token.transferFrom(user1, user2, 300);

        vm.prank(spender);
        token.transferFrom(user1, user2, 300);


        uint256 finalBalance = token.balanceOf(user2);
        uint256 remainingAllowance = token.allowance(user1, spender);

        assert(finalBalance <= 500);
        assert(remainingAllowance >= 0);
    }
}
