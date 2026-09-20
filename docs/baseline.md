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

# 4. build de desenvolvimento para Chrome
cd apps/browser
npm run build:chrome

# 5. chave de desenvolvimento (fixa o ID da extensão)
#    NÃO usar `npm run build:dev:chrome` no Windows — ver "Pegadinha do Windows"
bash ./scripts/update-manifest-dev.sh
```

### Pegadinha do Windows

`npm run` no Windows executa scripts com `cmd.exe`, que não roda `.sh`. O script
`update:dev:chrome` (e o `update:beta:chrome`) é um shell script, então
`npm run build:dev:chrome` **falha no Windows**.

Duas saídas, ambas equivalentes:

```bash
# A) build e chave em dois passos (o que foi usado aqui)
npm run build:chrome
bash ./scripts/update-manifest-dev.sh

# B) forçar o shell do npm só nessa invocação, sem alterar nenhum arquivo do repo
npm_config_script_shell="C:\Program Files\Git\bin\bash.exe" npm run build:dev:chrome
```

O `update-manifest-dev.sh` só escreve em `apps/browser/build/manifest.json` — a **saída**
do build. O manifest fonte não é tocado, então a regra 6 continua valendo.

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

```
C:\Users\ususario\projetos\clients\apps\browser\build
```

`chrome://extensions` → ativar **Modo do desenvolvedor** → **Carregar sem compactação** →
apontar para a pasta acima.

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

## Checklist de validação manual

Só o usuário consegue executar. Perfil separado do Chrome, apontando para o Vaultwarden
self-hosted (a URL é configurada na UI da extensão, nunca no código).

- [ ] Extensão carrega sem erro no console do service worker
- [ ] Configurar a URL do servidor self-hosted
- [ ] Login
- [ ] Desbloqueio
- [ ] Sync completo do cofre
- [ ] Inline menu aparece em campo de login
- [ ] Autofill preenche usuário e senha
- [ ] TOTP
- [ ] Salvar login novo
