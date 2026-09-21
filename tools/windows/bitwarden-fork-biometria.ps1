# Mantem o ID da extensao do fork na lista de origens autorizadas do native messaging
# do Bitwarden, para que o desbloqueio por Windows Hello funcione.
#
# Por que e necessario:
#   O app desktop regrava chrome.json em TODA inicializacao
#   (apps/desktop/src/main.ts chama generateManifests sem depender da configuracao),
#   restaurando apenas os quatro IDs das lojas oficiais. O ID de uma build propria
#   e sempre perdido.
#
# Como funciona:
#   Vigia o proprio arquivo com FileSystemWatcher em vez de vigiar o processo do
#   app. O dano e a regravacao do arquivo, entao reagir a ela cobre todos os casos:
#   logon, reinicio do app no meio do dia, atualizacao. A reacao e em milissegundos.
#
#   Uma varredura lenta a cada 60 s serve de rede de seguranca, para o caso de um
#   evento se perder ou de o arquivo ainda nao existir quando o vigia comeca.
#
#   Reaplicar e idempotente: se o ID ja esta la, nada acontece. A propria escrita
#   dispara mais um evento, que encontra o ID presente e nao faz nada. Sem laco.
#
# Seguranca:
#   Nao cria superficie nova. O arquivo ja e gravavel pelo proprio usuario, entao
#   qualquer coisa capaz de alterar este script conseguiria editar o chrome.json
#   diretamente. A diferenca em relacao a uma correcao manual e que este processo
#   fica residente, reaplicando enquanto a sessao durar.
#
# Parar: encerre o processo, ou desabilite a tarefa "Bitwarden fork - biometria".

$extensionId  = "chrome-extension://mfpkfneejkegaphnaebeojnkkimbaodk/"
$pasta        = Join-Path $env:APPDATA "Bitwarden\browsers"
$manifestPath = Join-Path $pasta "chrome.json"
$logPath      = Join-Path $pasta "fork-biometria.log"

function Write-Log([string] $message) {
    $line = "{0}  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $message
    try { Add-Content -Path $logPath -Value $line } catch { }
}

function Sync-AllowedOrigin {
    if (-not (Test-Path $manifestPath)) { return "ausente" }

    try {
        $manifest = Get-Content -Path $manifestPath -Raw -ErrorAction Stop | ConvertFrom-Json
    } catch {
        # O app pode estar gravando neste instante. A proxima volta pega.
        return "ocupado"
    }

    if ($null -eq $manifest.allowed_origins) { return "sem-lista" }
    if ($manifest.allowed_origins -contains $extensionId) { return "ja-presente" }

    $manifest.allowed_origins = @($manifest.allowed_origins) + $extensionId
    $texto = $manifest | ConvertTo-Json -Depth 5

    # UTF8Encoding($false) grava sem BOM tanto no PowerShell 5.1 quanto no 7.
    # Set-Content -Encoding utf8 escreveria BOM no 5.1 e o Chrome pararia de ler.
    try {
        [System.IO.File]::WriteAllText($manifestPath, $texto, (New-Object System.Text.UTF8Encoding $false))
    } catch {
        return "ocupado"
    }

    return "reaplicado"
}

function Invoke-Verificacao([string] $origem) {
    try {
        if ((Sync-AllowedOrigin) -eq "reaplicado") {
            Write-Log ("ID reaplicado ({0})" -f $origem)
        }
    } catch {
        # Nenhuma falha isolada pode derrubar o vigia.
    }
}

if (-not (Test-Path $pasta)) {
    New-Item -ItemType Directory -Path $pasta -Force | Out-Null
}

Write-Log "vigia iniciado"
Invoke-Verificacao "inicio"

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $pasta
$watcher.Filter = "chrome.json"
$watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::FileName
$watcher.EnableRaisingEvents = $true

$null = Register-ObjectEvent -InputObject $watcher -EventName Changed -SourceIdentifier "bwChanged"
$null = Register-ObjectEvent -InputObject $watcher -EventName Created -SourceIdentifier "bwCreated"
$null = Register-ObjectEvent -InputObject $watcher -EventName Renamed -SourceIdentifier "bwRenamed"

$ultimaVarredura = Get-Date

try {
    while ($true) {
        $evento = Wait-Event -Timeout 15
        if ($evento) {
            Remove-Event -EventIdentifier $evento.EventIdentifier
            # O app grava em varias etapas. Um respiro evita ler no meio da escrita.
            Start-Sleep -Milliseconds 400
            Invoke-Verificacao "evento"
            # Drena eventos acumulados da mesma gravacao.
            while (Get-Event -ErrorAction SilentlyContinue) { Get-Event | Remove-Event }
        }

        if (((Get-Date) - $ultimaVarredura).TotalSeconds -ge 60) {
            Invoke-Verificacao "varredura"
            $ultimaVarredura = Get-Date
        }
    }
} finally {
    $watcher.EnableRaisingEvents = $false
    Unregister-Event -SourceIdentifier "bwChanged" -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier "bwCreated" -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier "bwRenamed" -ErrorAction SilentlyContinue
    $watcher.Dispose()
    Write-Log "vigia encerrado"
}
