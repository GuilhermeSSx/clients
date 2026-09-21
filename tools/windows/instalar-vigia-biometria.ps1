# Instala o vigia que mantem o desbloqueio por biometria funcionando com a
# extensao deste fork.
#
# Contexto: o app desktop do Bitwarden regrava
# %APPDATA%\Bitwarden\browsers\chrome.json em toda inicializacao, restaurando
# apenas os quatro IDs das lojas oficiais. O ID de uma build propria e apagado, e
# sem ele o Chrome recusa a conversa que a biometria precisa. Detalhes em
# docs/baseline.md.
#
# O que este instalador faz:
#   - registra uma tarefa agendada que sobe o vigia no seu logon
#   - inicia o vigia agora, para nao precisar reiniciar
#   - confirma que o ID ficou aplicado
#
# Nao pede privilegio administrativo. Nao altera nada do repositorio.
#
# Uso:
#   pwsh -File tools\windows\instalar-vigia-biometria.ps1
#   pwsh -File tools\windows\instalar-vigia-biometria.ps1 -Desinstalar
#
# A tarefa aponta para o script dentro deste clone. Mover ou apagar o clone
# quebra o vigia, do mesmo jeito que quebra a extensao carregada sem compactacao.

[CmdletBinding()]
param(
    [switch] $Desinstalar,
    [string] $ExtensionId = "mfpkfneejkegaphnaebeojnkkimbaodk"
)

$ErrorActionPreference = "Stop"

$nomeTarefa = "Bitwarden fork - biometria"
$vigia      = Join-Path $PSScriptRoot "bitwarden-fork-biometria.ps1"
$manifesto  = Join-Path $env:APPDATA "Bitwarden\browsers\chrome.json"
$origem     = "chrome-extension://$ExtensionId/"

function Stop-Vigia {
    $processos = Get-CimInstance Win32_Process -Filter "Name='pwsh.exe' OR Name='powershell.exe'" |
        Where-Object { $_.CommandLine -like "*bitwarden-fork-biometria*" }
    foreach ($p in $processos) {
        try { Stop-Process -Id $p.ProcessId -Force } catch { }
    }
    return @($processos).Count
}

if ($Desinstalar) {
    $encerrados = Stop-Vigia
    Unregister-ScheduledTask -TaskName $nomeTarefa -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Vigia removido. Processos encerrados: $encerrados"
    Write-Host "O ID continua no chrome.json ate o app desktop regravar o arquivo."
    Write-Host "A partir dai, a biometria deixa de funcionar com esta extensao."
    return
}

if (-not (Test-Path $vigia)) {
    throw "Script do vigia nao encontrado em: $vigia"
}

$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwshPath) { $pwshPath = (Get-Command powershell).Source }

$conhost = Join-Path $env:SystemRoot "System32\conhost.exe"
if (-not (Test-Path $conhost)) {
    throw "conhost.exe nao encontrado. Ele e necessario para rodar sem janela visivel."
}

Write-Host "Vigia     : $vigia"
Write-Host "Interpreta: $pwshPath"
Write-Host ""

[void](Stop-Vigia)
Unregister-ScheduledTask -TaskName $nomeTarefa -Confirm:$false -ErrorAction SilentlyContinue

# conhost --headless cria o console sem janela. No Windows 11 o host padrao e o
# Windows Terminal, que ignora -WindowStyle Hidden; por isso o lancamento passa
# explicitamente pelo conhost.
$argumentos = "--headless `"$pwshPath`" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$vigia`""

$acao = New-ScheduledTaskAction -Execute $conhost -Argument $argumentos
$gatilho = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$config = New-ScheduledTaskSettingsSet `
    -Hidden `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -MultipleInstances IgnoreNew

# LogonType S4U rodaria sem desktop nenhum e seria mais limpo, mas registrar uma
# tarefa S4U exige privilegio administrativo.
$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Limited

Register-ScheduledTask `
    -TaskName $nomeTarefa `
    -Action $acao `
    -Trigger $gatilho `
    -Settings $config `
    -Principal $principal `
    -Description "Vigia chrome.json e reaplica o ID da extensao do fork sempre que o app desktop do Bitwarden regrava o arquivo." | Out-Null

Write-Host "Tarefa registrada: $nomeTarefa"

Start-ScheduledTask -TaskName $nomeTarefa

$limite = (Get-Date).AddSeconds(20)
$vivo = $false
while ((Get-Date) -lt $limite -and -not $vivo) {
    Start-Sleep -Milliseconds 500
    $vivo = [bool](Get-CimInstance Win32_Process -Filter "Name='pwsh.exe' OR Name='powershell.exe'" |
        Where-Object { $_.CommandLine -like "*bitwarden-fork-biometria*" })
}

Write-Host "Vigia em execucao: $vivo"

$janelas = @(Get-Process -Name pwsh, powershell, conhost, WindowsTerminal -ErrorAction SilentlyContinue |
    Where-Object { $_.Id -ne $PID -and $_.MainWindowHandle -ne 0 }).Count
Write-Host "Janelas visiveis : $janelas  (esperado: 0)"

if (Test-Path $manifesto) {
    $limite = (Get-Date).AddSeconds(15)
    $aplicado = $false
    while ((Get-Date) -lt $limite -and -not $aplicado) {
        Start-Sleep -Milliseconds 500
        try {
            $json = Get-Content $manifesto -Raw | ConvertFrom-Json
            $aplicado = ($json.allowed_origins -contains $origem)
        } catch { }
    }
    Write-Host "ID autorizado    : $aplicado"
} else {
    Write-Host "ID autorizado    : pendente"
    Write-Host ""
    Write-Host "O arquivo $manifesto ainda nao existe."
    Write-Host "Instale o app desktop do Bitwarden e ligue a integracao com o navegador."
    Write-Host "O vigia aplica o ID sozinho assim que o arquivo aparecer."
}

Write-Host ""
Write-Host "Pronto. Log em: $(Join-Path $env:APPDATA 'Bitwarden\browsers\fork-biometria.log')"
Write-Host "Feche o Chrome por completo e abra de novo para a biometria valer."
