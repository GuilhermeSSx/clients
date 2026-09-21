# Baseline reprodutível — Fase 1

Registro do build oficial **sem nenhuma modificação funcional**, para servir de ponto de
comparação em todas as fases seguintes.

## Identidade do commit

| Campo          | Valor                                                |
| -------------- | ---------------------------------------------------- |
| Upstream       | `https://github.com/bitwarden/clients`               |
| Tag usada      | `browser-v2026.9.0`                                  |
| SHA            | `07ac2aa903459ea8e1c18e3295b765be0bc3585f`           |
| Data do commit | 2026-09-07 10:06:16 -0400                            |
| Assunto        | `Bumped client version(s) (#23038)`                  |
| Branch local   | `base/upstream`                                      |
| Fork           | `https://github.com/GuilhermeSSx/clients` (`origin`) |

Remotes:

```
origin    https://github.com/GuilhermeSSx/clients.git
upstream  https://github.com/bitwarden/clients.git
```

A branch parte da **tag de release**, nunca de `main`.

## Ambiente

| Componente | Versão                    | Origem                |
| ---------- | ------------------------- | --------------------- |
| SO         | Windows 11 Pro 10.0.26100 | —                     |
| RAM        | 15,8 GB                   | —                     |
| Node       | **v24.21.0**              | `fnm` 1.39.0          |
| npm        | 11.19.0                   | bundled com o Node 24 |
| git        | 2.53.0.windows.1          | —                     |
| jq         | 1.8.2                     | winget `jqlang.jq`    |
| gh         | 2.96.0                    | —                     |

Exigências do repositório, conferidas: `.nvmrc` = `v24`;
`package.json` → `engines` = `{"node": ">=24.17.0", "npm": "~11"}`. Ambas atendidas.

### Gerenciamento de versão do Node

`fnm` foi instalado via `winget install Schniz.fnm`. O hook fica em
`~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1`:

```powershell
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
}
```

Com isso o `.nvmrc` ativa o Node 24 ao entrar na pasta do repositório, e o Node global
da máquina (v22.18.0) continua servindo os outros projetos.

## Comandos exatos que funcionaram

```bash
# 1. clone + remotes
git clone https://github.com/bitwarden/clients.git ~/projetos/clients
cd ~/projetos/clients
git remote rename origin upstream
git remote add origin https://github.com/GuilhermeSSx/clients.git
git fetch upstream --tags

# 2. branch a partir da tag de release
git switch -c base/upstream browser-v2026.9.0

# 3. dependências — npm ci sempre, npm install nunca
npm ci

# 4. build de desenvolvimento para Chrome, com a chave que fixa o ID da extensão
#    Um comando só. Ver "A pegadinha que custou uma sessão" logo abaixo antes de
#    considerar separar isso em dois passos.
cd apps/browser
npm_config_script_shell="C:\\Program Files\\Git\\bin\\bash.exe" npm run build:dev:chrome
```

### A pegadinha que custou uma sessão

Duas armadilhas se combinam no Windows.

A primeira: `npm run` usa `cmd.exe`, que não executa `.sh`. Como `update:dev:chrome` é um
shell script, `npm run build:dev:chrome` falha a menos que o shell seja informado.

A segunda, pior: contornar a primeira rodando `npm run build:chrome` e depois
`bash ./scripts/update-manifest-dev.sh` funciona **uma vez**. Todo `build:chrome`
posterior regenera `build/manifest.json` a partir do código-fonte e apaga a chave de
desenvolvimento. Se o script não for reexecutado, o build fica sem chave.

Sem a chave, o Chrome deriva outro ID para a extensão. ID diferente é extensão diferente:
todo o storage some. Login perdido, cofre re-sincronizado, e todas as configurações de
volta ao default — incluindo `inlineMenuVisibility`, cujo default é `Off`
(`libs/common/src/autofill/services/autofill-settings.service.ts`). O sintoma é o inline
menu parar de aparecer sem erro nenhum no console, o que manda o diagnóstico para o lado
errado.

Aconteceu em 2026-09-20: três builds seguidos sem reaplicar a chave, o ID mudou de
`mfpkfneejkegaphnaebeojnkkimbaodk` para `acklnbnimhjndpeicokcijniiaedkggb`, e o menu
sumiu.

**Use sempre o comando único**, verificado nesta máquina:

```bash
cd apps/browser
npm_config_script_shell="C:\Program Files\Git\bin\bash.exe" npm run build:dev:chrome
```

A variável vale só para aquela invocação; nenhum arquivo do repositório é alterado. O
`update-manifest-dev.sh` escreve apenas em `apps/browser/build/manifest.json`, que é saída
de build, então a regra 6 continua valendo.

Confirme o ID depois de todo build:

```bash
node -e 'const c=require("crypto"),fs=require("fs");const m=JSON.parse(fs.readFileSync("build/manifest.json","utf8"));const h=c.createHash("sha256").update(Buffer.from(m.key,"base64")).digest("hex").slice(0,32);console.log([...h].map(x=>String.fromCharCode(97+parseInt(x,16))).join(""))'
```

Deve imprimir `mfpkfneejkegaphnaebeojnkkimbaodk`. Qualquer outra coisa significa build sem
chave, e recarregar assim vai zerar o perfil da extensão de novo.

### Memória

O `.npmrc` da raiz já define `node-options=--max-old-space-size=8192` para todos os
scripts do repositório, e os próprios scripts de build repetem isso via `cross-env`.
Não é preciso exportar `NODE_OPTIONS` à mão. Com 15,8 GB de RAM o build passou sem
pressão.

## Resultado

| Medida                    | Valor                                                                  |
| ------------------------- | ---------------------------------------------------------------------- |
| `npm ci`                  | exit 0, **75 s**                                                       |
| `npm run build:chrome`    | exit 0, **120 s** (main 47,4 s + background 53,3 s)                    |
| `update-manifest-dev.sh`  | exit 0                                                                 |
| webpack                   | 5.106.2, compilado com 106 warnings (todos pré-existentes do upstream) |
| Tamanho do build          | 121 MB                                                                 |
| Clone (`.git` + worktree) | ~1,5 GB                                                                |
| `node_modules`            | ~1,4 GB                                                                |

### Pasta a carregar no Chrome

A pasta `build` dentro do app do navegador, no clone do fork:

```
<pasta-do-fork>\apps\browser\build
```

`chrome://extensions` → ativar **Modo do desenvolvedor** → **Carregar sem compactação** →
apontar para a pasta acima.

Ela não está versionada (`.gitignore`), então clonar o repositório não a traz. Ou se
compila localmente, ou se baixa o artefato `chrome-dev-<sha>` da aba Actions, que é gerado
pelo mesmo workflow e já sai com a chave de desenvolvimento aplicada.

O Chrome lê os arquivos dessa pasta continuamente. Mover, renomear ou apagar o clone
desativa a extensão.

### Identidade da extensão

A chave de desenvolvimento do upstream fixa o ID, então recarregar não muda o ID:

```
mfpkfneejkegaphnaebeojnkkimbaodk
```

Manifest gerado:

```json
{ "manifest_version": 3, "name": "__MSG_extName__", "version": "2026.9.0" }
```

## Invariantes verificados

| Verificação                   | Comando                                                 | Resultado              |
| ----------------------------- | ------------------------------------------------------- | ---------------------- |
| Lockfile intacto              | `git status --porcelain package-lock.json`              | saída vazia            |
| Manifest fonte intacto        | `git status --porcelain apps/browser/src/manifest.json` | saída vazia            |
| Permissões do manifest gerado | `diff` contra `apps/browser/src/manifest.v3.json`       | idênticas              |
| Árvore de código do upstream  | `git status --porcelain`                                | só os arquivos do fork |

Permissões do build (iguais às do upstream, nenhuma adicionada):

```
permissions:          activeTab, alarms, clipboardRead, clipboardWrite, contextMenus,
                      idle, offscreen, scripting, sidePanel, storage, tabs,
                      unlimitedStorage, webNavigation, webRequest,
                      webRequestAuthProvider, notifications
host_permissions:     https://*/*, http://*/*
optional_permissions: nativeMessaging, privacy
```

## CI

`.github/workflows/fork-build-browser.yml` reproduz o mesmo pacote a partir do mesmo
commit. `permissions: contents: read`, `npm ci`, verificação de lockfile, build, hash
sha256 dos arquivos e upload do artefato. Todas as `actions/*` pinadas por SHA:

| Action                    | Tag | SHA                                        |
| ------------------------- | --- | ------------------------------------------ |
| `actions/checkout`        | v7  | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| `actions/setup-node`      | v7  | `820762786026740c76f36085b0efc47a31fe5020` |
| `actions/upload-artifact` | v7  | `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` |

Os workflows do upstream que disparam em `push` estão todos travados nas branches
`main`, `rc` e `hotfixrc*`. Empurrar `base/upstream` ou `feat/**` para o fork não dispara
nenhum deles — só o `fork-build-browser.yml`. Abrir um pull request _dentro_ do fork, por
outro lado, dispara os workflows de `pull_request` do upstream.

## Biometria: o ID do fork precisa ser autorizado à mão

O desbloqueio por Windows Hello não acontece dentro da extensão. A extensão conversa com o
app desktop do Bitwarden por native messaging, e o Chrome só permite essa conversa para os
IDs listados num manifesto que o **app desktop** escreve.

Essa lista é fixa no código do upstream, em
`apps/desktop/src/main/native-messaging.main.ts`, em `loadChromeIds()`:

```
chrome-extension://nngceckbapebfimnlniiiahkandclblb/   Chrome oficial
chrome-extension://hccnnhgbibccigepcmlgppchkpfdophk/   Chrome beta
chrome-extension://jbkfoedolllekgbhcbcoahefnbanhhlh/   Edge
chrome-extension://ccnckbpmaceehanjmeomladnmlffdjgn/   Opera
```

Há um ramo que varre os perfis do Chrome atrás de IDs de desenvolvimento, mas ele só roda
sob `isDev()`, ou seja, apenas quando o **app desktop** é build de desenvolvimento. Com o
desktop oficial instalado, valem só os quatro acima.

O ID deste fork não está na lista, então o Chrome recusa a conexão antes de qualquer
tentativa e a biometria simplesmente não funciona — sem erro visível na extensão.

### Correção, a repetir em cada máquina

Arquivo, colável direto na barra do Explorador:

```
%APPDATA%\Bitwarden\browsers\chrome.json
```

Quem aponta para ele é a chave de registro
`HKCU\Software\Google\Chrome\NativeMessagingHosts\com.8bit.bitwarden`, que o app desktop
cria. Para conferir o caminho resolvido numa máquina:

```powershell
(Get-ItemProperty 'HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.8bit.bitwarden').'(default)'
```

Acrescentar o ID do fork à lista, preservando os quatro oficiais. Faz backup antes e
exige `jq` no PATH:

```bash
cd "$APPDATA/Bitwarden/browsers"
cp chrome.json chrome.json.bak-antes-do-fork
jq '.allowed_origins += ["chrome-extension://mfpkfneejkegaphnaebeojnkkimbaodk/"]' \
  chrome.json > chrome.json.tmp && mv chrome.json.tmp chrome.json
jq -r '.allowed_origins[]' chrome.json
```

A última linha deve imprimir cinco entradas, a última sendo a do fork. Em seguida, fechar
o Chrome inteiro — todas as janelas — e reabrir.

O `desktop_proxy.exe` não mantém lista própria — essa verificação só existe uma vez, na
escrita do manifesto. Editar o arquivo basta.

### Isso se perde em toda inicialização, não só ao alternar o botão

A primeira versão desta nota dizia que bastava não alternar a integração com o navegador.
Está errado. `apps/desktop/src/main.ts` chama `generateManifests()` no caminho de
inicialização do app, **sem depender da configuração** — só a integração com o DuckDuckGo
é condicional:

```ts
try {
  await this.nativeMessagingMain.generateManifests();
  await this.nativeMessagingMain.listen();
} catch (err) {
```

Ou seja, todo boot, toda abertura do app e toda atualização regravam o arquivo com apenas
os quatro IDs das lojas. A edição manual dura uma sessão.

### Mantendo a correção entre reinícios

`~\bin\bitwarden-fork-biometria.ps1`, lançado por `bitwarden-fork-biometria.cmd`.

Ele não aplica uma vez e sai, porque perderia a corrida: no logon o script e o app sobem
juntos, o script é rápido, o app é Electron e demora — aplicar de imediato seria
sobrescrito segundos depois. Em vez disso reaplica a cada cinco segundos por uma janela de
seis minutos, o que cobre o app subindo atrasado. É idempotente: se o ID já está lá, não
faz nada.

Grava em UTF-8 sem BOM via `File.WriteAllText` com `UTF8Encoding($false)`, e não por
`Set-Content -Encoding utf8`, que no PowerShell 5.1 escreveria BOM e quebraria a leitura
do arquivo pelo Chrome.

Registra o que fez em `%APPDATA%\Bitwarden\browsers\fork-biometria.log`.

Verificado removendo o ID à mão e confirmando que volta, que o arquivo continua sem BOM e
que `name`, `type` e `path` permanecem intactos.

**O que ainda não cobre:** se o app desktop reiniciar no meio do dia — atualização, queda,
reinício manual — a janela já terminou e a biometria quebra até o próximo boot. Nesse caso,
clique duplo no `.cmd`.

**Alternativa sem nada disso:** o desbloqueio por PIN passa por `PinServiceAbstraction`,
dentro da própria extensão, e não toca em native messaging. Não quebra em boot nem em
atualização, e não precisa de script. Foi descartado aqui por preferência pelo Windows
Hello, não por limitação técnica.

### O que isso significa

Aquela lista é a fronteira que decide quais extensões podem pedir ao app desktop para
destravar o cofre. Acrescentar um ID concede esse direito à extensão correspondente. Aqui
é uma build gerada localmente a partir de código revisado, e a decisão foi consciente.

### Impacto na trilha corporativa

Cada máquina da equipe teria o mesmo bloqueio, e a cada logon, não uma vez só. Como
o app regrava o arquivo em toda inicialização, não bastaria empurrar um `chrome.json`
ajustado por GPO: seria preciso um script de logon em cada máquina, competindo com a
inicialização do próprio Bitwarden. As outras saídas são forkar também o app desktop,
o que é grande demais, ou padronizar o desbloqueio por PIN. Nem o plano original nem a
Fase 4 dimensionavam isso; entra na conta antes de decidir pela distribuição interna.

## Validação manual — resultado

Executada em 2026-09-20 no Chrome do usuário, perfil próprio, contra o Vaultwarden
self-hosted. Extensão carregada sem compactação a partir de `apps/browser/build`.

| Item                        | Resultado                                                                     |
| --------------------------- | ----------------------------------------------------------------------------- |
| Extensão carrega            | OK — ID `mfpkfneejkegaphnaebeojnkkimbaodk`, igual ao derivado da chave de dev |
| URL do servidor self-hosted | OK                                                                            |
| Login                       | OK                                                                            |
| Desbloqueio                 | OK                                                                            |
| Sync completo               | OK — SignalR conecta, cifras descriptografam                                  |
| Inline menu aparece         | OK                                                                            |
| Lista de cifras renderiza   | OK — vários logins do mesmo domínio listados                                  |
| Autofill preenche           | pendente                                                                      |
| TOTP                        | pendente                                                                      |
| Salvar login novo           | pendente                                                                      |

### Erros observados e o que são

- `Uncaught (in promise) Error: Could not establish connection. Receiving end does not exist.`
  — **já diagnosticado, não re-investigar.** A origem é
  `broadcastTargetingRulesCacheInvalidation` em
  `apps/browser/src/autofill/background/overlay.background.ts`, introduzida pelo upstream
  no commit `bc9e7a2887` (PM-38617). Ela varre todas as abas e faz
  `void BrowserApi.tabSendMessage(tab, { command: "clearTargetingRulesCache" })`.

  O comentário da própria função afirma que abas sem content script vão "silently no-op",
  mas `void` apenas descarta o valor da promise: a rejeição continua sem tratamento e o
  Chrome registra. Toda aba sem content script — `chrome://`, abas abertas antes do load
  unpacked — produz uma entrada.

  É cosmético e não quebra nada. Decisão de 2026-09-20: **não corrigir no fork.** Um
  `.catch()` resolveria em uma linha, mas é diff que não pertence ao filtro e vira mais um
  ponto de conflito no rebase mensal. O fork precisa ser entediante. Se algum dia incomodar
  de verdade, o caminho é um PR isolado para o upstream, não um patch local.

- `Unable to fetch ServerConfig from https://localhost:8080/api` — resíduo da primeira
  configuração, antes de apontar para o servidor real. A página de Erros do Chrome é
  cumulativa e não limpa sozinha.
- `KeyIdBackfillError: API call failed during user key id backfill` (HTTP 404) — o
  Vaultwarden não implementa o endpoint que o cliente oficial chama. Lacuna de paridade
  de API do servidor, não defeito do fork; ocorreria igual com a extensão da Web Store.
  Cai em criptografia, então pela regra 8 não é tocado.
- `Lit is in dev mode` e `allowSignalWrites is deprecated` — esperados num build de
  desenvolvimento do upstream.

### Linha de base de UX, para comparar depois do patch

`autofill-inline-menu-list.ts` define `showCiphersPerPage = 6`, com carregamento
incremental conforme o scroll. Na prática, cerca de **3 itens ficam visíveis** antes de
precisar rolar. Com dezenas de logins no mesmo domínio, escolher exige rolagem — que é
exatamente o problema que o filtro da Fase 2 ataca.

### Página de teste local

`scratchpad/login-test.html` servida em `http://localhost:8787` por um servidor Node de
oito linhas, sem dependências. Formulário de login simples, campos com
`autocomplete="username"` e `autocomplete="current-password"`. Útil para exercitar o
inline menu sem depender de site externo. Ainda fora do repositório: entra na Fase 3,
junto com a variante hostil.

### Observação sobre automação

O inline menu se esconde quando o documento perde o foco. Dirigir a página por automação
cria os elementos no DOM — dá para confirmar via `MutationObserver` que o botão e a lista
nascem em ~38 ms após o foco — mas a renderização visual só acontece com a janela em foco
real. Verificação visual do menu é sempre manual.

## Checklist de validação manual
