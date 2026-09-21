# Piloto — 30 dias, uso pessoal

Registro do período de prova do fork. Uma linha por evento. Sem evento não há
linha: log vazio por uma semana é informação, não descuido.

Início: 2026-09-20 · Fim previsto: 2026-10-20
Versão inicial: `browser-v2026.9.0` · ID da extensão: `mfpkfneejkegaphnaebeojnkkimbaodk`

## Critérios de aprovação

Todos obrigatórios ao fim dos 30 dias.

- [ ] Todo release do upstream rebasado em até 72 h, sem conflito fora do escopo do patch
- [ ] Nenhum rebase custando mais de uma hora
- [ ] Regressão manual passando em cada rebuild
- [ ] Zero incidente de uso
- [ ] Menos de 4 h totais no mês
- [ ] O teste honesto: parei de usar o popup de busca?

## Desqualificadores imediatos

Qualquer um destes encerra o piloto e devolve o uso à extensão oficial.

- Release de segurança do upstream que não consegui aplicar em 72 h
- Conflito de rebase fora dos arquivos do patch
- O patch deixar de aplicar ou de funcionar após um rebase

Nota de 2026-09-20: o componente Lit deixou de ser desqualificador. O filtro é aplicado
em `renderCiphersForFilterQuery` **antes** da bifurcação `if (this.useLitComponents)`, de
modo que os dois caminhos de render consomem a lista já filtrada. Virar a flag não mata o
recurso; no máximo muda a aparência.

## Eventos

| Data       | Versão upstream   | Minutos | Conflito | Regressão | Observação                                |
| ---------- | ----------------- | ------- | -------- | --------- | ----------------------------------------- |
| 2026-09-20 | browser-v2026.9.0 | —       | não      | —         | Início do piloto. Fases 1 a 3 concluídas. |

Legenda das colunas:

- **Minutos** — tempo de relógio gasto no evento, incluindo build e teste.
- **Conflito** — `não`, `dentro do escopo` ou `FORA do escopo` (desqualificador).
- **Regressão** — resultado do checklist manual abaixo.

## Checklist de regressão manual

Rodar a cada rebuild, antes de voltar a usar no dia a dia.

- [ ] Extensão carrega e o ID continua `mfpkfneejkegaphnaebeojnkkimbaodk`
- [ ] Biometria destrava (se falhar, conferir `allowed_origins` em `chrome.json` — ver `baseline.md`)
- [ ] Login e desbloqueio
- [ ] Sync completo
- [ ] Inline menu aparece ao focar campo de login
- [ ] Digitar filtra a lista
- [ ] Apagar o que foi digitado devolve a lista inteira
- [ ] Texto sem correspondência mostra "Nenhum item corresponde à sua busca"
- [ ] Setas navegam a partir do primeiro item filtrado
- [ ] Autofill preenche usuário e senha
- [ ] TOTP
- [ ] Salvar login novo
- [ ] Passkey
- [ ] Cartão e identidade
- [ ] Domínio excluído continua excluído
- [ ] Formulário dentro de iframe
- [ ] SPA que troca de rota sem recarregar
- [ ] Travar o cofre com o menu aberto: a lista some na hora

## Onde anotar

O log pode ser editado direto pelo GitHub, pelo lápis na página do arquivo. É o caminho
mais prático quando se está em outra máquina e só se quer registrar uma linha.

O preço disso aparece no rebase. `base/upstream` é uma branch **reescrita** todo mês:
rebasear troca os commits por versões novas dos mesmos commits. Duas consequências:

- Antes de rebasear, é preciso trazer o que foi editado pelo site, senão o trabalho fica
  só lá e o rebase parte de uma base velha.
- Depois de rebasear, o `git push` comum é **recusado**. O GitHub vê um histórico que não
  é continuação do que ele tem, e recusa por segurança. Isso é esperado, não é erro.

A saída é `--force-with-lease`, que sobrescreve só se ninguém tiver empurrado nada desde
o último `fetch`. Nunca usar `--force` puro, que sobrescreve mesmo por cima de trabalho
que ainda não se viu.

## Rotina de rebase

No PowerShell, que é o padrão do Windows:

```powershell
git pull --rebase origin base/upstream
git fetch upstream --tags
git rebase browser-v<nova-tag>

npm ci
cd apps/browser
$env:npm_config_script_shell = "C:\Program Files\Git\bin\bash.exe"
npm run build:dev:chrome
cd ../..

npx jest apps/browser/src/autofill
```

No Git Bash, a variável vai como prefixo na mesma linha:

```bash
npm_config_script_shell="C:\Program Files\Git\bin\bash.exe" npm run build:dev:chrome
```

`VAR=valor comando` não existe no PowerShell e falha com `is not recognized as a name of a
cmdlet`. Detalhes em `baseline.md`.

Conferir o ID depois do build. Detalhes e a pegadinha da chave de desenvolvimento estão em
`docs/baseline.md`.

Só depois de o build sair limpo e a regressão passar:

```bash
git push --force-with-lease origin base/upstream
```

Se o push for recusado mesmo com `--force-with-lease`, é sinal de que existe algo no
GitHub que não foi trazido. Rodar `git pull --rebase origin base/upstream` e repetir — não
insistir com `--force`.
