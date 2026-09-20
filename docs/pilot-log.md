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

## Rotina de rebase

```bash
git fetch upstream --tags
git rebase browser-v<nova-tag>
npm ci
cd apps/browser
npm_config_script_shell="C:\Program Files\Git\bin\bash.exe" npm run build:dev:chrome
cd ../..
npx jest apps/browser/src/autofill
```

Conferir o ID depois do build. Detalhes e a pegadinha da chave de desenvolvimento estão
em `docs/baseline.md`.
