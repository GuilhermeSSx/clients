# Revisão de segurança — Fase 3

Revisão do patch do filtro contra a tag `browser-v2026.9.0` (SHA `07ac2aa9`).
Tudo abaixo é resultado de execução, não de leitura de código.

## 1. Superfície do diff

```
apps/browser/src/autofill/background/abstractions/overlay.background.ts       +6   -0
apps/browser/src/autofill/background/overlay.background.spec.ts              +54   -0
apps/browser/src/autofill/background/overlay.background.ts                   +45   -0
apps/browser/src/autofill/overlay/inline-menu/abstractions/…-list.ts          +9   -0
apps/browser/src/autofill/overlay/inline-menu/pages/list/…-list.spec.ts     +138   -0
apps/browser/src/autofill/overlay/inline-menu/pages/list/…-list.ts           +54   -5
apps/browser/src/autofill/overlay/inline-menu/pages/list/filter-….spec.ts   +169   -0
apps/browser/src/autofill/overlay/inline-menu/pages/list/filter-….ts         +66   -0
apps/browser/src/autofill/services/autofill-overlay-content.service.spec.ts  +80   -6
apps/browser/src/autofill/services/autofill-overlay-content.service.ts       +47   -8
```

Cinco arquivos ficam fora de `overlay/inline-menu/`, todos aprovados explicitamente antes
de serem tocados. Os dois `filter-inline-menu-ciphers.*` são arquivos novos e não existem
no upstream, então nunca produzem conflito de rebase.

## 2. Arquivos protegidos

| Arquivo                             | Diff contra a tag |
| ----------------------------------- | ----------------- |
| `package-lock.json`                 | vazio             |
| `apps/browser/src/manifest.json`    | vazio             |
| `apps/browser/src/manifest.v3.json` | vazio             |
| `package.json` (raiz e browser)     | vazio             |

Nenhuma dependência nova. Nenhuma permissão nova. Nenhum host novo.

## 3. Build limpo contra build do fork

A tag pristina foi compilada num checkout separado e comparada com o build do fork.

- **`manifest.json` gerado: idêntico.** Comparação por `jq -S` nos dois arquivos.
- Seis arquivos diferem, e todos são exatamente os bundles que carregam o código alterado:
  `background.js` (+ `.map`), `content/bootstrap-autofill-overlay.js`,
  `content/bootstrap-autofill-overlay-menu.js`,
  `content/bootstrap-autofill-overlay-notifications.js` e `overlay/menu-list.js`.
- **Nenhum arquivo a mais ou a menos** nos dois lados. Nada extra é embarcado.

## 4. Padrões proibidos em linhas adicionadas

| Padrão                       | Ocorrências |
| ---------------------------- | ----------- |
| `innerHTML`                  | 0           |
| `insertAdjacentHTML`         | 0           |
| `new RegExp`                 | 0           |
| `eval(`                      | 0           |
| `Function(`                  | 0           |
| `console.`                   | 0           |
| `addEventListener("message"` | 0           |

Também zero chamadas diretas a `chrome.*`, exigência do `apps/browser/CLAUDE.md`. As
únicas ocorrências de `chrome.` no diff são anotações de tipo
(`chrome.runtime.MessageSender`), no mesmo estilo do arquivo em volta.

## 5. Suíte de testes completa

Suíte inteira do upstream, não só autofill:

```
Test Suites: 2 failed, 1289 passed, 1291 total
Tests:       4 failed, 6 skipped, 5 todo, 25274 passed, 25289 total
Snapshots:   32 passed, 32 total
Time:        381.844 s
```

As quatro falhas são pré-existentes deste ambiente e inalcançáveis a partir deste diff:

| Suíte                                                                         | Testes | Por que não é do fork                                                                                                                             |
| ----------------------------------------------------------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `apps/browser/src/autofill/services/collect-autofill-content.service.spec.ts` | 1      | Reproduzida com a tag pristina em checkout limpo, sem nenhuma alteração aplicada. O arquivo tem diff vazio contra a tag.                          |
| `libs/common/src/services/api.service.spec.ts`                                | 3      | `libs/` tem diff vazio contra a tag, o patch inteiro vive em `apps/browser/src/autofill/`, e o spec não referencia `autofill` nem `apps/browser`. |

## 6. Fluxo de dados

O patch adiciona exatamente **dois** envios, ambos no sentido de entrada:

1. `sendExtensionMessage("updateAutofillInlineMenuFilterQuery", …)` — content script para
   o background.
2. `postMessageToPort(this.inlineMenuListPort, …)` — background para o iframe do menu,
   pela porta que já carregava as atualizações de cifras.

Nenhum listener global de `message` foi registrado. O canal é o que já existia.

A página da lista posta 14 comandos para fora do iframe. Nenhum deles carrega a string de
busca nem os itens que casaram. Os únicos que levam dado de cifra são `viewSelectedCipher`
e `fillAutofillInlineMenuCipher`, ambos disparados por clique do usuário e pré-existentes.

## 7. Achados

### 7.1 Conteúdo de campo de senha nunca é usado como filtro

Um campo `type="password"` devolve query vazia. A lista casa por nome de item e username,
então mandar a senha para o frame do menu espalharia o segredo sem nenhum ganho.

Coberto por `never sends the contents of a password field as a filter query`.

### 7.2 Oráculo de substring via altura do iframe — encontrado e corrigido

**Severidade: alta. Introduzido pelo próprio patch.**

A lista reporta a própria altura para fora com `updateAutofillInlineMenuListHeight`, e o
content script aplica essa altura no elemento iframe dentro do DOM da página. A página
consegue ler esse valor.

Isso era inofensivo enquanto digitar fechava a lista. Com o filtro, uma página maliciosa
poderia disparar eventos `input` sintéticos com strings escolhidas e medir a altura
resultante para descobrir quantos itens casaram — o suficiente para enumerar nome e
username de tudo que o cofre guarda para aquele domínio, caractere a caractere, sem
nenhuma interação do usuário.

Correção: só evento gerado pelo próprio navegador alimenta o filtro. Entrada por script
manda query vazia, a lista permanece na altura cheia e não informa nada novo. A checagem
usa `EventSecurity.isEventTrusted`, que o mesmo arquivo já aplica em outros dois handlers
pela mesma razão.

Coberto por `does not filter on scripted input, which would let the page probe the list`.
Esse teste precisa restaurar o comportamento real de `isEventTrusted`, porque a suíte do
upstream o substitui globalmente por `true` para que eventos sintéticos cheguem aos
handlers.

### 7.3 Regex a partir de entrada do usuário

Não existe. A comparação é `String.prototype.includes` sobre valor normalizado com
`normalize("NFD")` e remoção de marcas combinantes. Metacaracteres como `.*` e `(a+)+`
são texto literal, o que descarta backtracking catastrófico. Coberto por seis testes.

### 7.4 A lista nunca cresce

O filtro opera sobre `availableCiphers`, que é exatamente o que o background entregou.
Nenhum caminho novo pede mais cifras. Coberto por
`never asks the background for more ciphers while filtering` e por
`never requests further ciphers in response to a query`.

## 8. Itens da Fase 3 não entregues

Pedidos no plano, não executados por falta de aprovação para arquivos fora do escopo:

- **`scripts/verify-fork-surface.sh`** (item 6). As verificações 1, 2 e 4 acima foram
  feitas à mão nesta sessão; falta automatizá-las como step obrigatório do workflow.
- **Attestation de proveniência e sha256 no workflow** (item 7). O workflow já calcula o
  sha256 dos arquivos do build e o publica no summary, mas sem attestation assinada — isso
  exigiria `id-token` e `attestations` nas permissões do job, hoje restritas a
  `contents: read`.
- **Página de teste hostil no repositório** (item 8). A página de login local usada durante
  o desenvolvimento vive fora do repositório. A variante hostil — rajada de `focus` e
  `input`, tentativa de ler `contentDocument` do iframe e `postMessage` com wildcard —
  não foi escrita.

O achado 7.2 é precisamente o tipo de coisa que a página hostil existiria para pegar. Ele
foi encontrado por inspeção do fluxo de dados, mas um teste automatizado seria melhor que
inspeção manual repetida a cada rebase.
