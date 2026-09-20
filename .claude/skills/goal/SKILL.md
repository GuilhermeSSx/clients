---
name: goal
description: Executa uma fase inteira do plano do fork sem devolver o controle no meio. Use quando o usuário disser "/goal <N>", "roda a fase N", "conclui a fase N", ou pedir para trabalhar continuamente até um critério de conclusão estar atendido. Impõe evidência de execução em vez de leitura de código, limite de 3 tentativas por erro, e cinco condições estritas de parada.
---

# /goal — modo de operação e critério de parada

Objetivo desta sessão: concluir a **FASE $ARGUMENTS** integralmente.

Trabalhe de forma contínua até o critério de conclusão da fase estar atendido.
Não peça confirmação para ações rotineiras (ler arquivo, rodar build, rodar teste,
corrigir erro seu, reverter alteração sua). Não encerre com "sugestões de próximos
passos" enquanto houver item pendente. Não devolva o controle no meio.

## PRONTO SIGNIFICA

A fase só está concluída quando todos os itens do critério estiverem verificados
por execução, não por leitura de código. Para cada item, cole a saída real do
comando. Item sem evidência de execução conta como não concluído.

## QUANDO ALGO FALHAR

1. Diagnostique antes de alterar e diga a causa provável.
2. Corrija e execute de novo.
3. Se o mesmo erro persistir após 3 tentativas com abordagens diferentes, pare e
   traga: o erro completo, o que já foi tentado, e as duas hipóteses mais
   prováveis. Não empilhe tentativas cegas.

## PROIBIDO PARA "FAZER PASSAR"

- Desabilitar, pular ou afrouxar teste
- Relaxar qualquer regra do CLAUDE.md
- Mockar o que deveria ser real
- Marcar item como concluído sem execução

Se a única forma de fazer passar for violar uma regra, isso não é obstáculo
técnico, é sinal de que o desenho está errado. Pare e diga.

## PARE E PERGUNTE APENAS NESTES CASOS

- A estrutura do código diverge do que o plano descreve
- A correção exigiria tocar arquivo fora do escopo permitido
- Seria necessária dependência nova, permissão nova ou mudança no manifest
- Algo de criptografia, sincronização, SDK ou autenticação entrou no caminho
- Uma decisão de produto que o usuário não especificou

Fora desses cinco casos, siga sozinho até o fim.

## AO TERMINAR

Relatório com: o que foi feito, evidência de cada item do critério, resumo do
diff, o que ficou de fora e por quê, e o que depende do usuário (validação manual
no Chrome, que você não consegue executar).
