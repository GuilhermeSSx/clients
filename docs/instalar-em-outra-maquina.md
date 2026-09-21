# Instalar em outra máquina

Como pôr esta extensão em funcionamento num Windows novo, incluindo o desbloqueio por
biometria.

**Não é preciso clonar o repositório, instalar Node nem compilar nada.** O pacote pronto
tem 26 MB e carrega tudo: a extensão, o vigia da biometria e este documento. Compilar só
interessa a quem vai mexer no código, e está no apêndice.

## A ordem, em uma tela

| #   | Passo                                       | Como    |
| --- | ------------------------------------------- | ------- |
| 1   | Baixar o pacote                             | clique  |
| 2   | Extrair numa pasta definitiva               | clique  |
| 3   | Carregar sem compactação no Chrome          | clique  |
| 4   | Conferir o ID da extensão                   | clique  |
| 5   | URL do servidor, login, ligar o menu inline | clique  |
| 6   | Instalar o vigia da biometria               | comando |
| 7   | Fechar o Chrome por completo e reabrir      | clique  |

Um comando no total. Os passos 6 e 7 só valem para quem usa Windows Hello; o filtro
funciona sem eles.

O passo 5 é o que mais engana: a sugestão de preenchimento vem **desligada** de fábrica, e
o sintoma é o menu não aparecer, sem erro em lugar nenhum.

## Passo 1 — baixar o pacote

Abra a aba **Actions** do repositório, entre na execução mais recente do workflow
`fork-build-browser` que esteja verde, desça até **Artifacts** e clique em
`chrome-dev-<sha>`.

```
https://github.com/GuilhermeSSx/clients/actions
```

**É preciso estar logado no GitHub.** A página mostra o artefato para qualquer um, mas o
download só funciona autenticado — deslogado, o clique não baixa e nada explica por quê.

Artefatos ficam disponíveis por 90 dias. Passado esse prazo, rode o workflow de novo pelo
botão **Run workflow**, ou compile pelo apêndice.

## Passo 2 — extrair

Extraia para uma pasta que **não vai ser apagada**, por exemplo `C:\Bitwarden-fork`.

Nada de Downloads ou Área de Trabalho temporária: o Chrome lê esses arquivos o tempo todo,
e mover ou apagar a pasta desativa a extensão.

Dentro do zip:

```
apps/browser/build/          a extensão
apps/browser/build-files.sha256
tools/windows/               o vigia da biometria
docs/instalar-em-outra-maquina.md
```

## Passo 3 — carregar no Chrome

1. Abra `chrome://extensions`
2. Ligue **Modo do desenvolvedor**, no canto superior direito
3. **Carregar sem compactação**
4. Aponte para a pasta `apps\browser\build` de dentro do que você extraiu

## Passo 4 — conferir o ID

No card da extensão deve aparecer:

```
mfpkfneejkegaphnaebeojnkkimbaodk
```

ID diferente significa pacote sem a chave de desenvolvimento. Não siga adiante: o Chrome
trataria como outra extensão, e a biometria não teria como funcionar. Baixe de novo.

## Passo 5 — configurar

O armazenamento é por máquina, então nada disso vem junto com o pacote.

1. Configure a URL do seu servidor Vaultwarden e faça login
2. **Configurações → Preenchimento automático → Mostrar sugestões de preenchimento
   automático em campos de formulário**

Teste: abra um site com dois ou mais logins salvos, clique no campo de usuário e digite. A
lista deve encolher.

## Passo 6 — biometria

Pule se você não usa Windows Hello.

Antes: o app desktop do Bitwarden precisa estar instalado, com a integração com o navegador
ligada.

```powershell
cd C:\Bitwarden-fork\tools\windows
pwsh -File instalar-vigia-biometria.ps1
```

Sem o PowerShell 7 na máquina, troque `pwsh` por `powershell`. Testado nas duas versões.

Saída esperada:

```
Tarefa registrada: Bitwarden fork - biometria
Vigia em execucao: True
Janelas visiveis : 0  (esperado: 0)
ID autorizado    : True
```

### Por que isso é necessário

O desbloqueio por biometria não acontece dentro da extensão. Ela conversa com o app desktop
do Bitwarden, e o Chrome só permite essa conversa para os IDs listados num arquivo que o
**app desktop** escreve — uma lista fixa com os quatro IDs das lojas oficiais.

O ID desta build não está nela. E o app **regrava esse arquivo em toda inicialização**,
então corrigir à mão dura até o próximo boot.

O vigia observa o arquivo e devolve o ID sempre que ele é apagado, em cerca de meio segundo.
Isso cobre boot, reinício do app no meio do dia e atualização. Ele sobe sozinho no seu logon
e roda sem janela. O raciocínio completo está em `baseline.md`.

**A tarefa aponta para o script dentro da pasta extraída.** Mover ou apagar essa pasta
quebra o vigia, do mesmo jeito que quebra a extensão.

### Remover

```powershell
pwsh -File instalar-vigia-biometria.ps1 -Desinstalar
```

## Passo 7 — reabrir o Chrome

Feche **todas** as janelas do Chrome e abra de novo. Depois ligue a biometria nas
configurações da extensão.

## Verificação final

| O quê                  | Como conferir                                                   |
| ---------------------- | --------------------------------------------------------------- |
| ID da extensão         | `chrome://extensions` mostra `mfpkfneejkegaphnaebeojnkkimbaodk` |
| Filtro                 | digitar num campo de login encolhe a lista                      |
| Sem correspondência    | aparece "Nenhum item corresponde à sua busca"                   |
| Vigia                  | log tem `vigia iniciado`                                        |
| Biometria              | travar o cofre e destravar com Windows Hello                    |
| Nenhuma janela no boot | reiniciar e observar                                            |

Log do vigia:

```
%APPDATA%\Bitwarden\browsers\fork-biometria.log
```

## Quando algo não funciona

**O artefato não baixa.** Você está deslogado do GitHub. A página mostra o arquivo mesmo
assim, o que confunde.

**O menu não aparece.** Quase sempre é a sugestão de preenchimento desligada, no passo 5.
Confira também o ID. E lembre que o Chrome não injeta o script em abas que já estavam
abertas quando a extensão foi carregada: recarregue a página.

**A biometria não destrava.** Confira as origens autorizadas:

```powershell
(Get-Content "$env:APPDATA\Bitwarden\browsers\chrome.json" -Raw | ConvertFrom-Json).allowed_origins
```

Devem aparecer cinco entradas, a última sendo a do fork. Se houver só quatro, o vigia não
está rodando — rode o instalador de novo e olhe o log.

**O Chrome bloqueia carregar sem compactação.** Se a máquina tem Chrome gerenciado por
política corporativa, o modo do desenvolvedor pode estar desabilitado ou a extensão pode ser
removida sozinha. Isso é política, não defeito do pacote, e não tem contorno local.

## O que não viaja entre máquinas

- Login e sessão do cofre
- Todas as configurações da extensão, inclusive a do menu de preenchimento
- A autorização da biometria, que precisa do vigia instalado em cada máquina

## Apêndice — compilar em vez de baixar

Só interessa se você vai alterar o código, ou se o artefato expirou e você prefere não rodar
o workflow.

Custa cerca de 3 GB entre clone, `node_modules` e saída, e uns 3 minutos de build. Exige Git
e a versão de Node do `.nvmrc`.

**No PowerShell**, que é o que abre por padrão no Windows:

```powershell
git clone https://github.com/GuilhermeSSx/clients.git
cd clients
git switch base/upstream
npm ci
cd apps/browser
$env:npm_config_script_shell = "C:\Program Files\Git\bin\bash.exe"
npm run build:dev:chrome
```

**No Git Bash**, a variável vai como prefixo na mesma linha:

```bash
npm_config_script_shell="C:\Program Files\Git\bin\bash.exe" npm run build:dev:chrome
```

Escolha um shell e siga até o fim. A forma `VAR=valor comando` é sintaxe POSIX e **não
existe no PowerShell**, onde falha com `The term 'npm_config_script_shell=…' is not
recognized as a name of a cmdlet` — mensagem que parece npm quebrado, mas é só sintaxe.

Nunca rode `npm run build:chrome` sozinho: ele apaga a chave de desenvolvimento e muda o ID
da extensão. O motivo está em `baseline.md`.

O resultado fica em `apps/browser/build`, e daí em diante vale o passo 3. O vigia, neste
caso, sai de `tools/windows` do próprio clone.
