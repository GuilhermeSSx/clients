# Instalar em outra máquina

Passo a passo para pôr esta extensão em funcionamento num Windows novo, incluindo o
desbloqueio por biometria.

Escrito para uso pessoal, com carregamento sem compactação. Distribuição corporativa por
política do Chrome é outra história, e está fora deste documento.

## A ordem, em uma tela

Clonar e rodar o instalador **não basta**. O clone traz o código-fonte; a pasta `build`,
que é o que o Chrome carrega, não é versionada. E o instalador cuida só da biometria.

| #   | Passo                                        | Como    |
| --- | -------------------------------------------- | ------- |
| 1   | Obter a extensão: compilar ou baixar         | comando |
| 2   | Clonar o repositório                         | comando |
| 3   | Carregar sem compactação no Chrome           | manual  |
| 4   | Conferir o ID da extensão                    | manual  |
| 5   | URL do servidor, login, ligar o menu inline  | manual  |
| 6   | App desktop do Bitwarden + integração ligada | manual  |
| 7   | Instalar o vigia da biometria                | comando |
| 8   | Fechar o Chrome por completo e reabrir       | manual  |

Os passos 6 a 8 só valem para quem usa biometria. O filtro funciona sem eles.

O passo 5 é o que mais engana: a sugestão de preenchimento vem **desligada** de fábrica, e
o sintoma é o menu não aparecer, sem erro nenhum em lugar nenhum.

## Antes de começar

| Precisa                    | Por quê                                               |
| -------------------------- | ----------------------------------------------------- |
| Google Chrome              | navegador alvo                                        |
| App desktop do Bitwarden   | **só** se quiser biometria; o filtro funciona sem ele |
| Git                        | para clonar, se for compilar                          |
| Node na versão do `.nvmrc` | **só** se for compilar                                |

Você **não** precisa de privilégio administrativo em nenhum passo.

## Parte 1 — obter a extensão

Dois caminhos. O segundo é mais rápido e não exige nada instalado.

### Caminho A: compilar

```bash
git clone https://github.com/GuilhermeSSx/clients.git
cd clients
git switch base/upstream
npm ci
cd apps/browser
npm_config_script_shell="C:\Program Files\Git\bin\bash.exe" npm run build:dev:chrome
```

Gera `apps/browser/build`. Leva por volta de 3 minutos e ocupa cerca de 3 GB entre clone,
`node_modules` e saída. Nunca use `npm run build:chrome` sozinho: o motivo está em
`baseline.md`, na seção sobre a chave de desenvolvimento.

### Caminho B: baixar o pacote pronto

Em `github.com/GuilhermeSSx/clients/actions`, abra a execução mais recente do workflow
`fork-build-browser` e baixe o artefato `chrome-dev-<sha>`. São 26 MB compactados.
Descompacte e use a pasta `build` de dentro dele.

O pacote já sai com a chave de desenvolvimento aplicada, então produz o mesmo ID de
extensão. Artefatos do GitHub Actions expiram em 14 dias; passado esse prazo, rode o
workflow de novo ou compile.

Se quiser o vigia da Parte 3, você vai precisar do clone de qualquer forma.

## Parte 2 — carregar no Chrome

1. Ponha a pasta `build` num lugar **definitivo**. O Chrome lê esses arquivos o tempo
   todo; mover ou apagar desativa a extensão
2. Abra `chrome://extensions`
3. Ligue **Modo do desenvolvedor**, no canto superior direito
4. **Carregar sem compactação** e aponte para a pasta `build`
5. Confirme que o ID é `mfpkfneejkegaphnaebeojnkkimbaodk`

ID diferente significa build sem a chave de desenvolvimento. Não siga adiante: recompile
com o comando correto ou baixe o artefato.

### Configurar

O armazenamento é por máquina, então nada disso vem junto.

1. Configure a URL do seu servidor Vaultwarden e faça login
2. **Configurações → Preenchimento automático → Mostrar sugestões de preenchimento
   automático em campos de formulário**

Esse segundo passo é fácil de esquecer e o sintoma engana: o menu simplesmente não aparece,
sem erro nenhum. O padrão de fábrica é desligado.

Teste: abra um site com dois ou mais logins salvos, clique no campo de usuário, digite. A
lista deve encolher.

## Parte 3 — biometria

Pule se você não usa Windows Hello.

### Por que precisa de um passo extra

O desbloqueio por biometria não acontece dentro da extensão. Ela conversa com o app desktop
do Bitwarden, e o Chrome só permite essa conversa para os IDs listados num arquivo que o
**app desktop** escreve — uma lista fixa com os quatro IDs das lojas oficiais.

O ID desta build não está nela. Pior: o app **regrava esse arquivo em toda inicialização**,
então corrigir à mão dura até o próximo boot.

A solução é um vigia que observa o arquivo e devolve o ID sempre que ele é apagado. Reage
em cerca de meio segundo, o que cobre boot, reinício do app no meio do dia e atualização.

O raciocínio completo está em `baseline.md`.

### Instalar

Com o app desktop do Bitwarden instalado e a integração com o navegador ligada:

```powershell
cd <pasta-do-clone>
pwsh -File tools\windows\instalar-vigia-biometria.ps1
```

Sem o PowerShell 7 na máquina, troque `pwsh` por `powershell`. O instalador foi testado nas
duas versões e escolhe sozinho o interpretador para o vigia.

Saída esperada:

```
Tarefa registrada: Bitwarden fork - biometria
Vigia em execucao: True
Janelas visiveis : 0  (esperado: 0)
ID autorizado    : True
```

Feche o Chrome por completo e abra de novo. Ligue a biometria nas configurações da
extensão.

O instalador registra uma tarefa agendada que sobe o vigia no seu logon, inicia o vigia
agora e confirma que o ID ficou aplicado. Não pede privilégio administrativo e não altera
nada do repositório.

**A tarefa aponta para o script dentro do clone.** Mover ou apagar o clone quebra o vigia,
do mesmo jeito que quebra a extensão.

### Remover

```powershell
pwsh -File tools\windows\instalar-vigia-biometria.ps1 -Desinstalar
```

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

**O menu não aparece.** Quase sempre é a configuração de preenchimento automático
desligada. Verifique também se o ID confere. E lembre que o Chrome não injeta o script em
abas que já estavam abertas quando a extensão foi carregada: recarregue a página.

**A biometria não destrava.** Confira as origens autorizadas:

```powershell
(Get-Content "$env:APPDATA\Bitwarden\browsers\chrome.json" -Raw | ConvertFrom-Json).allowed_origins
```

Devem aparecer cinco entradas, a última sendo a do fork. Se houver só quatro, o vigia não
está rodando — rode o instalador de novo e olhe o log.

**O Chrome bloqueia carregar sem compactação.** Se a máquina tem Chrome gerenciado por
política corporativa, o modo do desenvolvedor pode estar desabilitado ou a extensão pode
ser removida sozinha. Isso é política, não defeito da build, e não tem contorno local.

**Login e configurações sumiram depois de recompilar.** O build perdeu a chave de
desenvolvimento e o Chrome passou a tratar a extensão como outra. Confirme o ID e leia a
seção sobre a chave em `baseline.md`.

## O que não viaja entre máquinas

- Login e sessão do cofre
- Todas as configurações da extensão, inclusive a do menu de preenchimento
- A autorização da biometria, que precisa do vigia instalado em cada máquina
- A pasta `build`, que não é versionada
