// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Bec.sol";

contract StandardTokenTest is Test {
    StandardToken token;
    address owner;
    address addr1;
    address addr2;

    function setUp() public {
        token = new StandardToken();
        owner = address(this);
        addr1 = address(0x1);
        addr2 = address(0x2);
    }

    function testRaceCondition() public {

        vm.prank(addr1);
        token.approve(addr2, 1000);


        vm.prank(addr1);
        token.approve(addr2, 500);

        vm.prank(addr1);
        token.approve(addr2, 300);


        uint256 finalAllowance = token.allowance(owner, addr2);
        

        assertEq(finalAllowance, 300);
    }

}
