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

        vm.prank(addr2);
        token.approve(addr1, 300);


        uint256 finalAllowanceAddr2 = token.allowance(owner, addr2);
        uint256 finalAllowanceAddr1 = token.allowance(owner, addr1);

        assertEq(finalAllowanceAddr2, 500); 
        assertEq(finalAllowanceAddr1, 300); 
    }


}
