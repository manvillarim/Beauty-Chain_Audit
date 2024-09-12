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

Quando uma operação matemática resultado em um valor máximo ou mínimo ao que o tipo de dado suporta. 

Em uma análise visual do contrato, percebe-se um grande risco de overflow na seguinte função:







