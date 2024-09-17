# Verificação Formal do Contrato BeautyChain

**Esse projeto visa auditar o contrato [BeautyChain](https://etherscan.io/token/0xc5d105e63711398af9bbff092d4b6769c82f793d#code) a partir do SMT Checker, model checker do compilador Solidity.**

## Metodologia

**1ª Etapa:** Análise do Contrato

**2ª Etapa:** Identificar as possíveis vulnerabilidades e aplicar o SMT Checker.

**3ª Etapa:** Análise dos resultados obtidos.


## Sobre o BeautyChain

**O arquivo Bec.sol compõe contratos que formam um token ERC20 básico, com algumas funcionalidades adicionais que deveriam garantir a segurança do contrato. Como o SMT Checker não suporta analisar o arquivo completo, os outros arquivos do src são as versões otimizadas para a análise de cada vulnerabilidade. Além disso, foi necessário dar um upgrade no contrato para versão 0.8 para ficar compatível com a ferramenta, mas a lógica permaneceu inalterada.**

# Vulnerabilidades

# 1. Overflow e Underflow

Quando uma operação matemática resulta em um valor máximo ou mínimo ao que o tipo de dado suporta. 

Em uma análise visual do contrato, percebe-se um grande risco de overflow na função seguinte:

    function batchTransfer(address[] calldata _receivers, uint256 _value) public returns (bool) {
        uint256 cnt = _receivers.length;
        uint256 amount = cnt * _value;
        require(cnt > 0 && cnt <= 20, "Invalid receivers count");
        require(_value > 0 && _balances[msg.sender] >= amount, "Insufficient balance");

        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        for (uint i = 0; i < cnt; i++) {
            assert(_receivers[i] != address(0));
            _balances[_receivers[i]] = _balances[_receivers[i]].add(_value);
            emit Transfer(msg.sender, _receivers[i], _value);
        }
        return true;
    }
Na linha `uint256 amount = cnt * _value;` não foi utilizada a função `mul` da SafeMath, que iria prevenir o overflow, sendo assim necessário aplicar o SMT Checker.
Após a análise(colocando o alvo como overflow no foundry.toml), os resultados confirmaram a suspeita:
     
      Warning (4984): CHC: Overflow (resulting value larger than 2**256 - 1) happens here.
      Counterexample:
      _totalSupply = 0
      _receivers = [0x08, 0x08]
      _value = 57896044618658097711785492504343953926634992332820282019728792003956564819968
       = false
      cnt = 2
      amount = 0
      
      Transaction trace:
      PausableToken.constructor()
      State: _totalSupply = 0
      PausableToken.batchTransfer([0x08, 0x08], 57896044618658097711785492504343953926634992332820282019728792003956564819968){ msg.sender: 0x0 }
      Warning: CHC: Overflow (resulting value larger than 2**256 - 1) happens here.
      Counterexample:
      _totalSupply = 0
      _receivers = [0x08, 0x08]
      _value = 57896044618658097711785492504343953926634992332820282019728792003956564819968
       = false
      cnt = 2
      amount = 0
      
      Transaction trace: 
      PausableToken.constructor()
      State: _totalSupply = 0
      PausableToken.batchTransfer([0x08, 0x08], 57896044618658097711785492504343953926634992332820282019728792003956564819968){ msg.sender: 0x0 }
         --> src/BecOverflow.sol:247:26:
          |
      247 |         uint256 amount = cnt * _value;
          |                          ^^^^^^^^^^^^
Outra possível vulnerabilidade seria se algum endereço do array `_receivers` fosse um endereço nulo, mas, ao aplicar o checker, ele garante a confiabilidade.

    Info (9576): CHC: Assertion violation check is safe!
       --> src/BecOverflow.sol:253:13:
        |
    253 |             assert(_receivers[i] != address(0));
        |             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Além disso, outro overflow foi identificado no contrato `BecToken`:

    Warning (4984): CHC: Overflow (resulting value larger than 2**256 - 1) happens here.
    Counterexample:
    name = [0x42, 0x65, 0x61, 0x75, 0x74, 0x79, 0x43, 0x68, 0x61, 0x69, 0x6e], symbol = [0x42, 0x45, 0x43], version = [0x31, 0x2e, 0x30, 0x2e, 0x30], decimals = 18, _totalSupply = 0
    initialSupply = 0
    
    Transaction trace:
    BecToken.constructor(){ msg.sender: 0x7e1d }
    Warning: CHC: Overflow (resulting value larger than 2**256 - 1) happens here.
    Counterexample:
    name = [0x42, 0x65, 0x61, 0x75, 0x74, 0x79, 0x43, 0x68, 0x61, 0x69, 0x6e], symbol = [0x42, 0x45, 0x43], version = [0x31, 0x2e, 0x30, 0x2e, 0x30], decimals = 18, _totalSupply = 0
    initialSupply = 0
    
    Transaction trace:
    BecToken.constructor(){ msg.sender: 0x7e1d }
       --> src/Bec.sol:280:33:
        |
    280 |         uint256 initialSupply = 7000000000 * (10**uint256(decimals));
        |   

# ERC20

Em uma primeira análise, ao verificar o contrato `StandartToken`, também é notada uma possível vulnerabilidade da função `approve`, ao não restringir o endereço do `spender` ser diferente de nulo. 

    function approve(address _spender, uint256 _value) public virtual override returns (bool) {
        assert(_spender != address(0));
        uint256 previousAllowance = _allowed[msg.sender][_spender];
        _allowed[msg.sender][_spender] = _value;
        
        return true;
    }
    
Ao aplicar o checker, a suspeita é confirmada:

    Warning (6328): CHC: Assertion violation happens here.
    Counterexample:
    _totalSupply = 0
    _spender = 0x0
    _value = 0
     = false
    
    Transaction trace:
    StandardToken.constructor()
    State: _totalSupply = 0
    StandardToken.approve(0x0, 0){ msg.sender: 0x20ad }
    Warning: CHC: Assertion violation happens here.
    Counterexample:
    _totalSupply = 0
    _spender = 0x0
    _value = 0
     = false
    
    Transaction trace:
    StandardToken.constructor()
    State: _totalSupply = 0
    StandardToken.approve(0x0, 0){ msg.sender: 0x20ad }
       --> src/BecOverflow.sol:130:9:
        |
    130 |         assert(_spender != address(0));
        |         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

## Race Condition na Função `approve` e `transferFrom` 

A **race condition** ocorre quando a execução do contrato depende da ordem de execução de transações concorrentes, o que pode levar a comportamentos inesperados se essas transações não forem geridas adequadamente.

### Cenário de Ataque

A race condition pode ocorrer na função `approve` e `transferFrom` porque o contrato permite que um endereço (`_spender`) gaste um valor específico de tokens em nome do proprietário (`msg.sender`). O problema surge quando o valor permitido (`allowance`) é alterado em uma transação, e uma segunda transação também tenta alterar o valor permitido para o mesmo endereço antes que a primeira transação seja completada. De acordo com a [documentação](https://docs.soliditylang.org/en/latest/smtchecker.html) do SMT Checker, é dito que a ferramenta é capaz de identificar problemas concorrentes(conforme foi verificado no experimento anterior). Contudo, todos os asserts do `BecReentrancy.sol` foram considerados seguros.

### Prova por teste

Em dúvida, resolvi aplicar um teste, `TestRaceConditional.t.sol`, disponível no `test`. Após rodar o teste, minhas suspeitas foram confirmadas:
       
    Ran 1 test for test/testReentrancy.t.sol:RaceConditionTest
    [FAIL. Reason: revert: Allowance exceeded] testRaceCondition() (gas: 75038)
    Suite result: FAILED. 0 passed; 1 failed; 0 skipped; finished in 861.90µs (86.27µs CPU time)
    
    Ran 1 test suite in 5.69ms (861.90µs CPU time): 0 tests passed, 1 failed, 0 skipped (1 total tests)
    
    Failing tests:
    Encountered 1 failing test in test/testReentrancy.t.sol:RaceConditionTest
    [FAIL. Reason: revert: Allowance exceeded] testRaceCondition() (gas: 75038)
    
    Encountered a total of 1 failing tests, 0 tests succeeded

Isso gera uma discussão interessante, em como abordar problemas concorrentes usando o SMT Checker. Apesar das asserções simples terem funcionado em um problema de reentrância básico do experimento anterior, essa abordagem se mostrou ineficiente agora.

### Prevenção

Para mitigar esse problema, recomenda-se:

- **Resetar a Allowance:** 
  - Para uma solução simples, o ideal é definir a allowance atual para zero no inicio de cada transação. Isso evita que valores antigos sejam utilizados enquanto uma nova transação está pendente.

    ```solidity
    function approve(address _spender, uint256 _value) public virtual override returns (bool) {
        require(_spender != address(0), "Invalid address");
    
        if (_value > 0) {
            _allowed[msg.sender][_spender] = 0;
        }
    
        _allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

  - Contudo, essa forma gera um gasto desnecessário de gás. Uma solução comum é a criação de funções increaseAllowance e decreaseAllowance.


# Outras Vulnerabilidades

Também foi analisado outras possíveis vulnerabilidades, como inconsistência do owner no Ownable e as funções de pausar o contrato, mas todas se demonstraram confiáveis.

# ERCx

Para informações adicionais, o contrato também foi aplicado no [ERCx](https://ercx.runtimeverification.com/). Os resultados confirmaram a auditoria e também levantaram outros pontos(não necessariamente vulnerabilidades).
![imagem](https://github.com/manvillarim/Beauty-Chain_Audit/blob/main/lib/imagem.png)

# Resultados

**Nota-se que o SMT Checker é uma ferramenta poderosa para auditar contratos, mesmo com a limitação do tamanho do código. Além disso, a falha de encontrar a race condition levanta questões interessantes sobre a abordargem de vulnerabilidades concorrentes, que será explorado nos próximos experimentos.**
