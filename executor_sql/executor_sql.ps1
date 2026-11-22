<#
  SistemaCMJ - executor de scripts SQL sem SSMS (fase 3d, 20/11/2026)
  Autor: Celso de Freitas / Refatorado: Claude
  v1.0 (20/11/2026) - Criacao. Fica de olho em executor_sql\entrada\*.sql, roda cada
                      script no banco de DESENVOLVIMENTO (SISTEMACMJ_LOCAL, instancia
                      .\SQL2025), grava o resultado em executor_sql\saida\<nome>.txt
                      (mensagens, resultados e erros, como a aba Mensagens do SSMS) e
                      move o script para executor_sql\processados\.
  Seguranca: banco e instancia fixos; recusa USE de outro banco, DROP/RESTORE DATABASE,
             xp_cmdshell, sp_configure, SHUTDOWN e comandos do modo SQLCMD; confere o
             banco depois de cada lote. Nunca aponta para producao.
  v1.1 (20/11/2026) - Banco escolhido pela linha "-- EXECUTOR: BANCO=<nome>" nas
                      primeiras linhas do script, so entre os bancos permitidos
                      (SISTEMACMJ_LOCAL, padrao, e SISTEMACMJ = banco de ensaio da
                      instalacao no notebook), sempre na instancia .\SQL2025.
                      Recarrega sozinho quando este arquivo muda (sem precisar
                      reinstalar a tarefa).
  v1.2 (20/11/2026) - Pedido de verificacao de compilacao: o arquivo
                      entrada\compilar.pedido faz um "dotnet build" da API numa pasta
                      separada (%LOCALAPPDATA%\SistemaCMJ\artifacts_verificacao),
                      sem mexer no sistema que esta rodando; resultado em
                      saida\compilar.txt. Comando fixo: nao roda nada que venha
                      do pedido.
  v1.3 (20/11/2026) - Pedido de envio ao GitHub: entrada\enviar_github.pedido faz
                      "git push origin main" na pasta do projeto, com o usuario do
                      Windows (credencial ja guardada), sem janela e sem pedir
                      senha (falha em vez de travar); resultado em
                      saida\enviar_github.txt. Autorizado pelo Celso (envio
                      automatico, 16/11/2026). Comando fixo.
  v1.4 (20/11/2026) - Pedido de publicacao: entrada\publicar.pedido roda api\publicar.ps1
                      (gera o pacote de instalacao em C:\SisCMJ_Publicacao, fora do
                      Drive); resultado em saida\publicar.txt. Comando fixo.
  v1.5 (22/11/2026) - Pedido de extracao do Access: entrada\extrair_access.pedido roda
                      legado\ferramentas\Extrair_Access.ps1 -ExportarDados (le copias
                      do CashBookCMJ_be.mdb e regrava legado\dados_brutos e
                      legado\extracao); resultado em saida\extrair_access.txt.
                      Comando fixo. Aprovado pelo Celso (03f, 22/11/2026).
  v1.6 (22/11/2026) - Pedido de testes das telas: entrada\testar_telas.pedido roda
                      testes\telas (Playwright + Edge invisivel: entra, abre cada tela,
                      grava um registro de teste); resultado em saida\testar_telas.txt.
                      Precisa do sistema rodando (api\rodar.cmd). Comando fixo.
                      Testes antes de cada publicacao aprovados pelo Celso (03h/04a).
  Uso: iniciado pela tarefa "SistemaCMJ - Executor SQL" (instalar_executor.cmd).
#>
param(
    [string]$Instancia = '.\SQL2025',
    [string]$Banco     = 'SISTEMACMJ_LOCAL',
    [string[]]$Permitidos = @('SISTEMACMJ_LOCAL', 'SISTEMACMJ'),
    [int]$IntervaloSeg = 3,
    [int]$TimeoutSeg   = 3600,
    [int]$MaxLinhas    = 5000,
    [int]$MaxCelula    = 300
)
$ErrorActionPreference = 'Stop'
$Raiz        = $PSScriptRoot
$Entrada     = Join-Path $Raiz 'entrada'
$Saida       = Join-Path $Raiz 'saida'
$Processados = Join-Path $Raiz 'processados'
$Status      = Join-Path $Raiz 'STATUS.txt'
foreach ($P in @($Entrada, $Saida, $Processados)) { New-Item -ItemType Directory -Force -Path $P | Out-Null }
$Utf8 = New-Object System.Text.UTF8Encoding($false)

# Uma instancia so
$Mutex = New-Object System.Threading.Mutex($false, 'Local\SistemaCMJ_ExecutorSQL')
if (-not $Mutex.WaitOne(20000)) { exit 0 }
$MeuArquivo = $MyInvocation.MyCommand.Path
$MinhaVersao = (Get-Item -LiteralPath $MeuArquivo).LastWriteTimeUtc

function Gravar-Status([string]$Texto) {
    try { [System.IO.File]::WriteAllText($Status, ((Get-Date -Format 'dd/MM/yyyy HH:mm:ss') + ' ' + $Texto + "`r`n"), $Utf8) } catch { }
}

function Texto-Valor($V) {
    if ($V -is [System.DBNull] -or $null -eq $V) { return 'NULL' }
    if ($V -is [datetime]) { return $V.ToString('yyyy-MM-dd HH:mm:ss.fff').Replace(' 00:00:00.000', '') }
    if ($V -is [byte[]]) { return '0x' + (($V | Select-Object -First 32 | ForEach-Object { $_.ToString('X2') }) -join '') }
    if ($V -is [decimal] -or $V -is [double] -or $V -is [single]) { return $V.ToString([System.Globalization.CultureInfo]::InvariantCulture) }
    $T = [string]$V
    $T = $T.Replace("`r", ' ').Replace("`n", ' ').Replace("`t", ' ')
    if ($T.Length -gt $MaxCelula) { $T = $T.Substring(0, $MaxCelula) + '...' }
    return $T
}

function Escrever-Tabela($Leitor, $Sb) {
    $N = $Leitor.FieldCount
    $Nomes = @(); for ($i = 0; $i -lt $N; $i++) { $Nome = $Leitor.GetName($i); if ($Nome -eq '') { $Nome = '(sem nome)' }; $Nomes += $Nome }
    $Linhas = New-Object System.Collections.Generic.List[object]
    $Total = 0
    while ($Leitor.Read()) {
        $Total++
        if ($Linhas.Count -lt $MaxLinhas) {
            $L = New-Object string[] $N
            for ($i = 0; $i -lt $N; $i++) { $L[$i] = Texto-Valor $Leitor.GetValue($i) }
            $Linhas.Add($L)
        }
    }
    $Larg = New-Object int[] $N
    for ($i = 0; $i -lt $N; $i++) { $Larg[$i] = $Nomes[$i].Length }
    foreach ($L in $Linhas) { for ($i = 0; $i -lt $N; $i++) { if ($L[$i].Length -gt $Larg[$i]) { $Larg[$i] = $L[$i].Length } } }
    $Cab = @(); $Tra = @()
    for ($i = 0; $i -lt $N; $i++) { $Cab += $Nomes[$i].PadRight($Larg[$i]); $Tra += ('-' * $Larg[$i]) }
    [void]$Sb.AppendLine(($Cab -join ' | '))
    [void]$Sb.AppendLine(($Tra -join '-+-'))
    foreach ($L in $Linhas) {
        $C = @(); for ($i = 0; $i -lt $N; $i++) { $C += $L[$i].PadRight($Larg[$i]) }
        [void]$Sb.AppendLine(($C -join ' | ').TrimEnd())
    }
    if ($Total -gt $Linhas.Count) { [void]$Sb.AppendLine('(... mais ' + ($Total - $Linhas.Count) + ' linhas nao mostradas)') }
    [void]$Sb.AppendLine('(' + $Total + ' linhas)')
    [void]$Sb.AppendLine('')
}

function Dividir-Lotes([string]$Texto) {
    # Separa nos GO sozinhos na linha (como o SSMS); devolve texto e linha inicial de cada lote
    $Lotes = New-Object System.Collections.Generic.List[object]
    $Linhas = $Texto -split "`r?`n"
    $Atual = New-Object System.Text.StringBuilder
    $Inicio = 1
    for ($k = 0; $k -lt $Linhas.Length; $k++) {
        $M = [regex]::Match($Linhas[$k], '^\s*GO\s*(\d+)?\s*(--.*)?$', 'IgnoreCase')
        if ($M.Success) {
            $Rep = 1; if ($M.Groups[1].Success) { $Rep = [int]$M.Groups[1].Value }
            $T = $Atual.ToString()
            if ($T.Trim() -ne '') { for ($r = 0; $r -lt $Rep; $r++) { $Lotes.Add(@($T, $Inicio)) } }
            [void]$Atual.Clear(); $Inicio = $k + 2
        } else { [void]$Atual.AppendLine($Linhas[$k]) }
    }
    $T = $Atual.ToString(); if ($T.Trim() -ne '') { $Lotes.Add(@($T, $Inicio)) }
    return ,$Lotes
}

function Conferir-Proibidos([string]$Texto, [string]$Alvo) {
    $SemComent = [regex]::Replace($Texto, '/\*.*?\*/', ' ', 'Singleline')
    $SemComent = [regex]::Replace($SemComent, '--[^\r\n]*', ' ')
    $Regras = @(
        @('(?im)^\s*:', 'comando do modo SQLCMD (:r, :setvar, :connect)'),
        @('(?im)^\s*USE\s+(?!\[?' + $Alvo + '\]?\s*;?\s*$)', 'USE de outro banco'),
        @('(?i)\bDROP\s+DATABASE\b', 'DROP DATABASE'),
        @('(?i)\bRESTORE\s+DATABASE\b', 'RESTORE DATABASE'),
        @('(?i)\bxp_cmdshell\b', 'xp_cmdshell'),
        @('(?i)\bsp_configure\b', 'sp_configure'),
        @('(?i)\bSHUTDOWN\b', 'SHUTDOWN'),
        @('(?i)\bALTER\s+SERVER\b', 'ALTER SERVER')
    )
    foreach ($R in $Regras) { if ([regex]::IsMatch($SemComent, $R[0])) { return $R[1] } }
    return $null
}

function Executar-Script([string]$Arquivo) {
    $Nome = [System.IO.Path]::GetFileNameWithoutExtension($Arquivo)
    $Sb = New-Object System.Text.StringBuilder
    $script:Sb = $Sb
    $script:Erros = 0
    $script:OffsetLinha = 0
    $Ini = Get-Date
    $Texto = [System.IO.File]::ReadAllText($Arquivo, [System.Text.Encoding]::UTF8)
    $Alvo = $Banco
    $Dir = [regex]::Match(($Texto -split "`n" | Select-Object -First 15) -join "`n", '(?im)^\s*--\s*EXECUTOR:\s*BANCO\s*=\s*\[?(\w+)\]?')
    if ($Dir.Success) { $Alvo = $Dir.Groups[1].Value.ToUpper() }
    [void]$Sb.AppendLine('SistemaCMJ - executor SQL v1.1')
    [void]$Sb.AppendLine('Script : ' + [System.IO.Path]::GetFileName($Arquivo))
    [void]$Sb.AppendLine('Banco  : ' + $Instancia + ' / ' + $Alvo)
    [void]$Sb.AppendLine('Inicio : ' + $Ini.ToString('dd/MM/yyyy HH:mm:ss'))
    [void]$Sb.AppendLine(('=' * 70))
    $Resultado = ''
    $Motivo = $null
    if ($Permitidos -notcontains $Alvo) { $Motivo = 'banco nao permitido (' + $Alvo + '; permitidos: ' + ($Permitidos -join ', ') + ')' }
    if (-not $Motivo) { $Motivo = Conferir-Proibidos $Texto $Alvo }
    if ($Motivo) {
        [void]$Sb.AppendLine('RECUSADO: o script contem ' + $Motivo + '. Nada foi executado.')
        $Resultado = 'RECUSADO'
    } else {
        $Lotes = Dividir-Lotes $Texto
        $Con = New-Object System.Data.SqlClient.SqlConnection("Server=$Instancia;Database=$Alvo;Integrated Security=SSPI;Application Name=SistemaCMJ Executor SQL")
        $Con.FireInfoMessageEventOnUserErrors = $true
        $Con.add_InfoMessage({
            param($Origem, $Ev)
            foreach ($E in $Ev.Errors) {
                if ($E.Class -gt 10) {
                    $script:Erros++
                    [void]$script:Sb.AppendLine('*** ERRO Msg ' + $E.Number + ', Nivel ' + $E.Class + ', Linha ' + ($E.LineNumber + $script:OffsetLinha) + ': ' + $E.Message)
                } else { [void]$script:Sb.AppendLine($E.Message) }
            }
        })
        try {
            $Con.Open()
            $n = 0
            foreach ($Lote in $Lotes) {
                $n++
                $script:OffsetLinha = [int]$Lote[1] - 1
                $Cmd = $Con.CreateCommand(); $Cmd.CommandText = $Lote[0]; $Cmd.CommandTimeout = $TimeoutSeg
                try {
                    $Leitor = $Cmd.ExecuteReader()
                    do { if ($Leitor.FieldCount -gt 0) { Escrever-Tabela $Leitor $Sb } } while ($Leitor.NextResult())
                    $Leitor.Close()
                } catch {
                    $script:Erros++
                    [void]$Sb.AppendLine('*** ERRO no lote ' + $n + ' (linha ' + $Lote[1] + '): ' + $_.Exception.Message)
                    if ($Con.State -ne 'Open') { [void]$Sb.AppendLine('*** Conexao perdida; execucao interrompida.'); break }
                }
                $Chk = $Con.CreateCommand(); $Chk.CommandText = 'SELECT DB_NAME()'
                $Db = [string]$Chk.ExecuteScalar()
                if ($Db -ne '' -and $Db -ne $Alvo) {  # vazio = SET NOEXEC ON (script abortou de proposito)
                    $script:Erros++; [void]$Sb.AppendLine('*** INTERROMPIDO: o script mudou para o banco ' + $Db + '.'); break }
            }
            [void]$Sb.AppendLine(('=' * 70))
            [void]$Sb.AppendLine('Lotes  : ' + $n + ' de ' + $Lotes.Count)
        } catch {
            $script:Erros++
            [void]$Sb.AppendLine('*** ERRO de conexao: ' + $_.Exception.Message)
        } finally { $Con.Close() }
        if ($script:Erros -eq 0) { $Resultado = 'OK' } else { $Resultado = 'COM ERROS (' + $script:Erros + ')' }
    }
    $Fim = Get-Date
    [void]$Sb.AppendLine('Fim    : ' + $Fim.ToString('dd/MM/yyyy HH:mm:ss') + '  (' + [math]::Round(($Fim - $Ini).TotalSeconds, 1) + ' s)')
    [void]$Sb.AppendLine('RESULTADO: ' + $Resultado)
    $Destino = Join-Path $Saida ($Nome + '.txt')
    $Tmp = $Destino + '.tmp'
    [System.IO.File]::WriteAllText($Tmp, $Sb.ToString(), $Utf8)
    Move-Item -LiteralPath $Tmp -Destination $Destino -Force
    Move-Item -LiteralPath $Arquivo -Destination (Join-Path $Processados ((Get-Date -Format 'yyyyMMdd_HHmmss') + '_' + [System.IO.Path]::GetFileName($Arquivo))) -Force
    return $Resultado
}

function Verificar-Compilacao {
    $ErrorActionPreference = 'Continue'   # git/dotnet escrevem andamento no stderr: nao e erro
    $Projeto = Join-Path (Split-Path $Raiz -Parent) 'api\SistemaCMJ.Api\SistemaCMJ.Api.csproj'
    $Pasta = Join-Path $env:LOCALAPPDATA 'SistemaCMJ\artifacts_verificacao'
    $Ini = Get-Date
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $Saida = (& dotnet build $Projeto --nologo --artifacts-path $Pasta 2>&1 | ForEach-Object { "$_" }) -join "`r`n"
    $Codigo = $LASTEXITCODE
    # v1.4: o gerador de licenca tambem e conferido
    $Gerador = Join-Path (Split-Path $Raiz -Parent) 'api\GeradorLicenca\GeradorLicenca.csproj'
    if (Test-Path -LiteralPath $Gerador) {
        $Saida += "`r`n--- Gerador de licenca ---`r`n" + ((& dotnet build $Gerador --nologo --artifacts-path $Pasta 2>&1 | ForEach-Object { "$_" }) -join "`r`n")
        if ($LASTEXITCODE -ne 0) { $Codigo = $LASTEXITCODE }
    }
    $Texto = 'SistemaCMJ - verificacao de compilacao (executor v1.2)' + "`r`n" + 'Inicio : ' + $Ini.ToString('dd/MM/yyyy HH:mm:ss') + "`r`n" + ('=' * 70) + "`r`n" + $Saida + "`r`n" + ('=' * 70) + "`r`n" + 'CODIGO_SAIDA=' + $Codigo + "`r`n" + 'RESULTADO: ' + $(if ($Codigo -eq 0) { 'OK' } else { 'COM ERROS' }) + "`r`n"
    $Destino = Join-Path (Join-Path $Raiz 'saida') 'compilar.txt'
    [System.IO.File]::WriteAllText($Destino + '.tmp', $Texto, $Utf8)
    Move-Item -LiteralPath ($Destino + '.tmp') -Destination $Destino -Force
    return $Codigo
}

function Enviar-GitHub {
    $ErrorActionPreference = 'Continue'   # git/dotnet escrevem andamento no stderr: nao e erro
    $Projeto = Split-Path $Raiz -Parent
    $Ini = Get-Date
    $env:GIT_TERMINAL_PROMPT = '0'
    $env:GCM_INTERACTIVE = 'never'
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $Saida = (& git -C $Projeto push origin main 2>&1 | ForEach-Object { "$_" }) -join "`r`n"
    $Codigo = $LASTEXITCODE
    $Texto = 'SistemaCMJ - envio ao GitHub (executor v1.3)' + "`r`n" + 'Inicio : ' + $Ini.ToString('dd/MM/yyyy HH:mm:ss') + "`r`n" + ('=' * 70) + "`r`n" + $Saida + "`r`n" + ('=' * 70) + "`r`n" + 'CODIGO_SAIDA=' + $Codigo + "`r`n" + 'RESULTADO: ' + $(if ($Codigo -eq 0) { 'OK' } else { 'COM ERROS' }) + "`r`n"
    $Destino = Join-Path (Join-Path $Raiz 'saida') 'enviar_github.txt'
    [System.IO.File]::WriteAllText($Destino + '.tmp', $Texto, $Utf8)
    Move-Item -LiteralPath ($Destino + '.tmp') -Destination $Destino -Force
    return $Codigo
}

function Publicar {
    $ErrorActionPreference = 'Continue'
    $Script = Join-Path (Split-Path $Raiz -Parent) 'api\publicar.ps1'
    $Ini = Get-Date
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $Saida = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script 2>&1 | ForEach-Object { "$_" }) -join "`r`n"
    $Codigo = $LASTEXITCODE
    $Texto = 'SistemaCMJ - publicacao (executor v1.4)' + "`r`n" + 'Inicio : ' + $Ini.ToString('dd/MM/yyyy HH:mm:ss') + "`r`n" + ('=' * 70) + "`r`n" + $Saida + "`r`n" + ('=' * 70) + "`r`n" + 'CODIGO_SAIDA=' + $Codigo + "`r`n"
    $Destino = Join-Path (Join-Path $Raiz 'saida') 'publicar.txt'
    [System.IO.File]::WriteAllText($Destino + '.tmp', $Texto, $Utf8)
    Move-Item -LiteralPath ($Destino + '.tmp') -Destination $Destino -Force
    return $Codigo
}

function Testar-Telas {
    $ErrorActionPreference = 'Continue'   # dotnet escreve andamento no stderr: nao e erro
    $Projeto = Join-Path (Split-Path $Raiz -Parent) 'testes\telas\TestesTelas.csproj'
    $Ini = Get-Date
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $Saida = (& dotnet run --project $Projeto -c Release 2>&1 | ForEach-Object { "$_" }) -join "`r`n"
    $Codigo = $LASTEXITCODE
    if ($Saida -notmatch 'RESULTADO: ') { $Saida += "`r`nRESULTADO: ERRO (os testes nao rodaram ate o fim)" }
    $Texto = 'SistemaCMJ - testes das telas (executor v1.6)' + "`r`n" + 'Inicio : ' + $Ini.ToString('dd/MM/yyyy HH:mm:ss') + "`r`n" + 'Fim    : ' + (Get-Date).ToString('dd/MM/yyyy HH:mm:ss') + "`r`n" + ('=' * 70) + "`r`n" + $Saida + "`r`n" + ('=' * 70) + "`r`n" + 'CODIGO_SAIDA=' + $Codigo + "`r`n"
    $Destino = Join-Path (Join-Path $Raiz 'saida') 'testar_telas.txt'
    [System.IO.File]::WriteAllText($Destino + '.tmp', $Texto, $Utf8)
    Move-Item -LiteralPath ($Destino + '.tmp') -Destination $Destino -Force
    return $Codigo
}

function Extrair-Access {
    $ErrorActionPreference = 'Continue'
    $Script = Join-Path (Split-Path $Raiz -Parent) 'legado\ferramentas\Extrair_Access.ps1'
    $Ini = Get-Date
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $Saida = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script -ExportarDados 2>&1 | ForEach-Object { "$_" }) -join "`r`n"
    $Codigo = $LASTEXITCODE
    $Texto = 'SistemaCMJ - extracao do Access (executor v1.5)' + "`r`n" + 'Inicio : ' + $Ini.ToString('dd/MM/yyyy HH:mm:ss') + "`r`n" + 'Fim    : ' + (Get-Date).ToString('dd/MM/yyyy HH:mm:ss') + "`r`n" + ('=' * 70) + "`r`n" + $Saida + "`r`n" + ('=' * 70) + "`r`n" + 'CODIGO_SAIDA=' + $Codigo + "`r`n"
    $Destino = Join-Path (Join-Path $Raiz 'saida') 'extrair_access.txt'
    [System.IO.File]::WriteAllText($Destino + '.tmp', $Texto, $Utf8)
    Move-Item -LiteralPath ($Destino + '.tmp') -Destination $Destino -Force
    return $Codigo
}

Gravar-Status 'ativo (iniciado)'
$UltimoStatus = Get-Date
$TextoStatus = 'ativo'
while ($true) {
    try {
        $Lista = @(Get-ChildItem -LiteralPath $Entrada -Filter '*.sql' -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddSeconds(-2) } | Sort-Object Name)
        foreach ($F in $Lista) {
            Gravar-Status ('executando ' + $F.Name)
            $R = Executar-Script $F.FullName
            $TextoStatus = 'ativo; ultimo: ' + $F.Name + ' -> ' + $R
            Gravar-Status $TextoStatus; $UltimoStatus = Get-Date
        }
        $Pedido = Join-Path $Entrada 'compilar.pedido'
        if (Test-Path -LiteralPath $Pedido) {
            Remove-Item -LiteralPath $Pedido -Force
            Gravar-Status 'verificando a compilacao'
            $C = Verificar-Compilacao
            $TextoStatus = 'ativo; ultima compilacao -> ' + $(if ($C -eq 0) { 'OK' } else { 'COM ERROS' })
            Gravar-Status $TextoStatus; $UltimoStatus = Get-Date
        }
        $Pedido = Join-Path $Entrada 'enviar_github.pedido'
        if (Test-Path -LiteralPath $Pedido) {
            Remove-Item -LiteralPath $Pedido -Force
            Gravar-Status 'enviando ao GitHub'
            $C = Enviar-GitHub
            $TextoStatus = 'ativo; ultimo envio ao GitHub -> ' + $(if ($C -eq 0) { 'OK' } else { 'COM ERROS' })
            Gravar-Status $TextoStatus; $UltimoStatus = Get-Date
        }
        $Pedido = Join-Path $Entrada 'publicar.pedido'
        if (Test-Path -LiteralPath $Pedido) {
            Remove-Item -LiteralPath $Pedido -Force
            Gravar-Status 'publicando'
            $C = Publicar
            $TextoStatus = 'ativo; ultima publicacao -> ' + $(if ($C -eq 0) { 'OK' } else { 'COM ERROS' })
            Gravar-Status $TextoStatus; $UltimoStatus = Get-Date
        }
        $Pedido = Join-Path $Entrada 'extrair_access.pedido'
        if (Test-Path -LiteralPath $Pedido) {
            Remove-Item -LiteralPath $Pedido -Force
            Gravar-Status 'extraindo o Access'
            $C = Extrair-Access
            $TextoStatus = 'ativo; ultima extracao do Access -> CODIGO ' + $C
            Gravar-Status $TextoStatus; $UltimoStatus = Get-Date
        }
        $Pedido = Join-Path $Entrada 'testar_telas.pedido'
        if (Test-Path -LiteralPath $Pedido) {
            Remove-Item -LiteralPath $Pedido -Force
            Gravar-Status 'testando as telas'
            $C = Testar-Telas
            $TextoStatus = 'ativo; ultimo teste das telas -> ' + $(if ($C -eq 0) { 'OK' } else { 'COM FALHAS' })
            Gravar-Status $TextoStatus; $UltimoStatus = Get-Date
        }
        # Sinal de vida a cada minuto (sem regravar a cada ciclo, para nao encher a sincronizacao do Drive)
        if (((Get-Date) - $UltimoStatus).TotalSeconds -ge 60) { Gravar-Status $TextoStatus; $UltimoStatus = Get-Date }
    } catch { Gravar-Status ('ativo; erro no ciclo: ' + $_.Exception.Message); $UltimoStatus = Get-Date }
    # Arquivo do executor mudou: abre a versao nova e sai (a nova espera o mutex)
    try {
        if ((Get-Item -LiteralPath $MeuArquivo).LastWriteTimeUtc -ne $MinhaVersao) {
            Gravar-Status 'reiniciando com a versao nova do executor'
            Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', ('"' + $MeuArquivo + '"'))
            $Mutex.ReleaseMutex()
            exit 0
        }
    } catch { }
    Start-Sleep -Seconds $IntervaloSeg
}
