// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "src/BecReentrancy.sol"; // Substitua pelo caminho do seu contrato

contract RaceConditionTest is Test {
    StandardToken token;
    address user1 = address(0x1);
    address user2 = address(0x2);
    address spender = address(0x3);

    function setUp() public {
        token = new StandardToken();
        // Assumindo que user1 já tem um saldo inicial de 1000 tokens
        deal(address(token), user1, 1000);
    }

    function testRaceCondition() public {
        // Aprova o spender para gastar tokens de user1
        vm.prank(user1);
        token.approve(spender, 500);

        // Cria duas transações concorrentes
        vm.prank(spender);
        token.transferFrom(user1, user2, 300);

        vm.prank(spender);
        token.transferFrom(user1, user2, 300);

        // Verifica o saldo final e a permissão
        uint256 finalBalance = token.balanceOf(user2);
        uint256 remainingAllowance = token.allowance(user1, spender);

        // Asserções para verificar a condição de corrida
        assert(finalBalance <= 500); // O saldo não deve exceder a permissão inicial
        assert(remainingAllowance >= 0); // A permissão não deve ser negativa
    }
}
