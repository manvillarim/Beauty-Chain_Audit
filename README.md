# Verificação Formal do Contrato BeautyChain

**Esse projeto visa auditar o contrato [BeautyChain](https://etherscan.io/token/0xc5d105e63711398af9bbff092d4b6769c82f793d#code) a partir do SMT Checker, model checker do compilador Solidity.**

## Metodologia

**1ª Etapa:** Análise do Contrato

**2ª Etapa:** Identificar as possíveis vulnerabilidades e aplicar o SMT Checker.

**3ª Etapa:** Análise dos resultados obtidos.


## Sobre o BeautyChain

**O arquivo Bec.sol compõe contratos que formam um token ERC20 básico, com algumas funcionalidades adicionais que deveriam garantir a segurança do contrato. Como o SMT Checker não suporta analisar o arquivo completo, os outros arquivos do src são as versões otimizadas para a análise de cada vulnerabilidade. Além disso, foi necessário dar um upgrade no contrato para versão 0.8 para ficar compatível com a ferramenta, mas a lógica pemaneceu inalterada.**

# Vulnerabilidades

# 1. Overflow e Underflow

Quando uma operação matemática resulta em um valor máximo ou mínimo ao que o tipo de dado suporta. 

Em uma análise visual do contrato, percebe-se um grande risco de overflow na seguinte função:

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

# ERC20

Em uma primeira análise, ao verificar o contrato `StandartToken`, também é notada uma possível vulnerabilidade da função `approve`, ao não restringir o endereço do `spender` ser diferente de nulo. 

    function approve(address _spender, uint256 _value) public virtual override returns (bool) {
        assert(_spender != address(0));
        uint256 previousAllowance = _allowed[msg.sender][_spender];
        _allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        
        assert(_allowed[msg.sender][_spender] >= previousAllowance);
        
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

Na função aprove também é percebida outra vulnerabilidade, ao SMT ter esse resultado:

    Warning (6328): CHC: Assertion violation happens here.
       --> src/BecReentrancy.sol:135:9:
        |
    135 |         assert(_allowed[msg.sender][_spender] >= previousAllowance);
        |         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

## Race Condition na Função `approve`

Como o contrato não possui uma função para atualizar a allowance ou pausar essa função, ele está suscetível a ataques de **Race Condition**. 

### O que é uma Race Condition?

A **race condition** ocorre quando a execução do contrato depende da ordem de execução de transações concorrentes, o que pode levar a comportamentos inesperados se essas transações não forem geridas adequadamente.

### Cenário de Ataque

A race condition pode ocorrer na função `approve` porque o contrato permite que um endereço (`_spender`) gaste um valor específico de tokens em nome do proprietário (`msg.sender`). O problema surge quando o valor permitido (`allowance`) é alterado em uma transação, e uma segunda transação também tenta alterar o valor permitido para o mesmo endereço antes que a primeira transação seja completada.

#### Fluxo do Ataque:

1. **Transação Inicial:** 
   - O proprietário (`msg.sender`) chama a função `approve` para autorizar o `_spender` a gastar um valor específico de tokens.

2. **Transação de Ataque:** 
   - Um contrato malicioso detecta que a função `approve` está sendo chamada e também envia uma transação para chamar `approve` com um novo valor para o mesmo `_spender`.

3. **Condição de Corrida:** 
   - Se a primeira transação ainda não foi confirmada e a segunda transação é executada, o atacante pode usar a `allowance` anterior (antes da atualização) para transferir tokens antes que o valor permitido seja redefinido.

### Exemplo Visual

1. **Estado Inicial:** O proprietário aprova um valor de `1000` para o `_spender`.
2. **Ataque:** Um contrato malicioso detecta a chamada e aprova um valor de `5000` para o mesmo `_spender`.
3. **Resultado:** O atacante pode gastar `1000` tokens antes que o valor seja atualizado para `5000`.

### Prevenção

Para mitigar esse problema, recomenda-se:

- **Resetar a Allowance:** 
  - Antes de definir um novo valor de allowance, definir a allowance atual para zero. Isso evita que valores antigos sejam utilizados enquanto uma nova transação está pendente.

    ```solidity
    function approve(address _spender, uint256 _value) public virtual override returns (bool) {
        require(_spender != address(0), "Invalid address");
    
        // Reset allowance to zero before setting new value
        if (_value > 0) {
            _allowed[msg.sender][_spender] = 0;
        }
    
        _allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }


Ao aplicar esse contrato ao [ERCx](https://ercx.runtimeverification.com/), os resultados não só se repetem, como ele também identifica novas vulnerabilidades:

![Imagem do Projeto](https://github.com/manvillarim/Beauty-Chain_Audit/blob/main/lib/imagem.png)


# Outras Vulnerabilidades

Também foi analisado outras possíveis vulnerabilidades, como inconscistência do owner no Ownable e as funções de pausar o contrato, mas todas se demonstraram confiáveis.

# Resultados

**Nota-se que o BeautyChain tem diversas vulnerabilidades, demonstrando que mesmo na blockchain, um contrato não está livre de erros e, consequentemente, há grandes riscos em sua utilização. ALém disso, mesmo sem ter capacidade de analisar contratos longos de forma inteira, o SMT Checker se prova como uma ferramenta poderosa para auditar contratos.**









