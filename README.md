# Verificação Formal do Contrato BeautyChain

**Esse projeto visa auditar o contrato [BeautyChain](https://etherscan.io/token/0xc5d105e63711398af9bbff092d4b6769c82f793d#code) a partir do SMT Checker, model checker do compilador Solidity.**

## Metodologia

**1ª Etapa:** Análise do Contrato

**2ª Etapa:** Identificar as possíveis vulnerabilidades e aplicar o SMT Checker.

**3ª Etapa:** Análise dos resultados obtidos.


## Sobre o BeautyChain

**O arquivo Bec.sol compõe contratos que formam um token ERC20 básico, com algumas funcionalidades adicionais que deveriam garantir a segurança do contrato. Como o SMT Checker não suporta analisar o arquivo completo, os outros arquivos do src são as versões otimizadas para a análise de cada vulnerabilidade.**

# Vulnerabilidades

**1. Overflow e Underflow**

Quando uma operação matemática resulta em um valor máximo ou mínimo ao que o tipo de dado suporta. 

Em uma análise visual do contrato, percebe-se um grande risco de overflow na seguinte função:

    function batchTransfer(address[] calldata _receivers, uint256 _value) public returns (bool) {
        uint256 cnt = _receivers.length;
        uint256 amount = cnt * _value;
        require(cnt > 0 && cnt <= 20, "Invalid receivers count");
        require(_value > 0 && _balances[msg.sender] >= amount, "Insufficient balance");

        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        for (uint i = 0; i < cnt; i++) {
            _balances[_receivers[i]] = _balances[_receivers[i]].add(_value);
            emit Transfer(msg.sender, _receivers[i], _value);
        }
        return true;
    }
Na linha `uint256 amount = cnt * _value;` não foi utilizada a função mul da SafeMath, que iria prevenir o overflow, sendo assim necessário aplicar o SMT Checker.
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







