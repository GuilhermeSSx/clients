# Fork Bitwarden — filtro de busca no inline menu

> Este arquivo entra em toda sessão do Claude Code neste repositório.
> Ele NÃO descreve o upstream. Descreve as regras deste fork.

## Contexto

Este é um fork de `bitwarden/clients` com **uma única mudança funcional**: permitir
filtrar por digitação a lista de logins que aparece no inline menu de autofill.

Motivo: dezenas de logins legítimos e distintos para o mesmo site, e hoje a única forma
de escolher é rolar a lista. O recurso não existe no upstream, é pedido aberto na
comunidade desde 2024, e um PR da comunidade (PM-38025 / PR #20836) foi rejeitado em
setembro de 2026 por capacidade da equipe, não por mérito.

Ambiente:

- Navegador alvo: Google Chrome (Windows)
- Servidor: Vaultwarden self-hosted (a URL é configurada na extensão, nunca no código)
- Etapa atual: uso pessoal, apenas nesta máquina, com load unpacked
- Etapa futura: distribuição corporativa por política — **ainda não é para isso**

Princípio que rege o projeto: **o fork precisa ser entediante.** Diff mínimo, zero
dependência nova, zero permissão nova, e fácil de rebasear todo mês. Cada linha a mais é
custo de manutenção para sempre.

## Regras invioláveis

### Segurança do produto

1. O filtro opera exclusivamente sobre a lista de cifras que o background já entregou ao
   inline menu. Nunca solicitar cifras adicionais, nunca buscar no cofre inteiro, nunca
   criar modo "buscar em tudo". Ampliar essa lista transformaria o menu numa superfície de
   exfiltração para uma página maliciosa.
2. Fluxo de dados em uma direção só: a string de busca entra no iframe do menu. Nada sai —
   nem o texto digitado, nem os itens que casaram — para a página ou para fora do canal já
   existente.
3. Renderização apenas com `textContent` / `document.createElement`. Proibido `innerHTML` e
   `insertAdjacentHTML`.
4. Proibido construir `RegExp` a partir de entrada do usuário. Comparação por `includes`
   sobre string normalizada.
5. Nenhum `console.log`, `console.debug` ou similar contendo nome de item, username ou a
   string de busca.
6. `manifest.json` não é tocado. Nenhuma permissão nova, nenhum host novo.
7. Não registrar novos listeners globais de `message`. Usar o canal de mensagens que já
   existe entre content script, background e iframe do menu.
8. Não tocar em nada de criptografia, sincronização, SDK ou autenticação. Se um rebase ou
   uma tarefa levar a esses caminhos, pare e avise.

### Disciplina de repositório

9. `npm ci` sempre, `npm install` nunca. O lockfile não pode ser alterado.
10. Diff restrito a `apps/browser/src/autofill/overlay/inline-menu/` e aos arquivos de teste
    correspondentes. Qualquer arquivo fora disso precisa de aprovação explícita do usuário.
11. Nenhuma dependência nova, em nenhuma circunstância.
12. Nunca commitar chave, `.pem`, token ou credencial.

### Como trabalhar neste repositório

13. Não inventar caminhos de arquivo nem nomes de script. Localizar no repositório, mostrar
    o que foi encontrado, e só então editar.
14. Antes de editar, apresentar o plano e esperar OK.
15. Se a estrutura real do código divergir do que estas notas descrevem, parar e dizer o que
    foi encontrado. O upstream muda com frequência; estas notas podem estar desatualizadas,
    e corrigir o rumo é preferível a uma adaptação criativa.
16. Ao final de cada fase, entregar: o que mudou, o diff resumido, o que foi testado, e o
    que ficou pendente.

## Estado do fork

- Branch base: `base/upstream`, criada a partir da tag de release do browser (nunca de `main`).
- `origin` = `GuilhermeSSx/clients` · `upstream` = `bitwarden/clients`
- Node exigido: ver `.nvmrc` e `engines` em `package.json`. Gerenciado por `fnm`.
- Baseline reprodutível registrada em `docs/baseline.md`.

## Divergências conhecidas entre estas notas e o código real

Verificadas em 2026-09-20 contra a tag `browser-v2026.9.0` (SHA `07ac2aa9`).
Sem números de linha de propósito: eles mudam a cada rebase. Procure pelos símbolos.

1. **Caminho de render duplo no arquivo do patch.**
   `apps/browser/src/autofill/overlay/inline-menu/pages/list/autofill-inline-menu-list.ts`
   já contém `useLitComponents`, `litHost` e `litCipherListScrollElement`, com ramificações
   `if (this.useLitComponents)` em vários pontos do render. A flag
   `LitInlineMenuComponents` existe em `libs/common/src/enums/feature-flag.enum.ts` com
   default `FALSE`. Não é um componente separado atrás de flag — são dois caminhos de
   render no mesmo arquivo. Decidir explicitamente qual dos dois o patch cobre.

2. **O repasse da query não cabe na regra 10.** A digitação no campo da página é observada
   em `apps/browser/src/autofill/services/autofill-overlay-content.service.ts` e a lista é
   montada em `apps/browser/src/autofill/background/overlay.background.ts`. Ambos fora de
   `overlay/inline-menu/`. Precisa de aprovação explícita antes de qualquer edição ali.

3. **Precedente útil.** O mesmo arquivo já tem `getFilteredCiphersForTotpField(ciphers)` —
   filtro in-place sobre `InlineMenuCipherData[]` chamado no início de `updateListItems()`,
   com `buildNoResultsInlineMenuList()` logo abaixo para o estado vazio. O canal de entrada
   é `inlineMenuListWindowMessageHandlers`, alimentado por `postMessageToIFrame` em
   `iframe-content/autofill-inline-menu-iframe.service.ts`. O patch espelha esse padrão em
   vez de inventar arquitetura.

## Toolchain nesta máquina

- Node gerenciado por `fnm`; o `.nvmrc` ativa o v24 ao entrar na pasta.
- `jq` é necessário para o script `update-manifest-dev.sh`.

### Sempre use o comando único de build

No PowerShell, que é o padrão do Windows:

```powershell
cd apps/browser
$env:npm_config_script_shell = "C:\Program Files\Git\bin\bash.exe"
npm run build:dev:chrome
```

No Git Bash:

```bash
cd apps/browser
npm_config_script_shell="C:\Program Files\Git\bin\bash.exe" npm run build:dev:chrome
```

A forma `VAR=valor comando` é sintaxe de shell POSIX e **não existe no PowerShell**. Lá ela
falha com `The term 'npm_config_script_shell=…' is not recognized`. No PowerShell a variável
é definida antes, com `$env:`, e vale pelo resto da sessão.

**Nunca rode `npm run build:chrome` sozinho.** Ele regenera `build/manifest.json` do
código-fonte e, ao fazer isso, apaga a chave de desenvolvimento que o
`update-manifest-dev.sh` injetou no build anterior.

Sem essa chave o Chrome deriva o ID da extensão de outra forma. ID diferente significa
extensão diferente para o Chrome: **todo o storage some**. Na prática, login perdido,
cofre re-sincronizado do zero e — o mais traiçoeiro — todas as configurações de volta ao
default, inclusive `inlineMenuVisibility`, cujo default é `Off`. O sintoma é o inline menu
simplesmente parar de aparecer, sem nenhum erro no console.

O `npm_config_script_shell` existe porque no Windows o `npm run` usa `cmd.exe`, que não
executa `.sh`, e `update:dev:chrome` é um shell script. A variável vale só para aquela
invocação; nenhum arquivo do repositório é alterado.

ID esperado com a chave aplicada: `mfpkfneejkegaphnaebeojnkkimbaodk`. Conferir depois de
todo build:

```bash
node -e 'const c=require("crypto"),fs=require("fs");const m=JSON.parse(fs.readFileSync("build/manifest.json","utf8"));const h=c.createHash("sha256").update(Buffer.from(m.key,"base64")).digest("hex").slice(0,32);console.log([...h].map(x=>String.fromCharCode(97+parseInt(x,16))).join(""))'
```
