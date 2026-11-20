<#
  SisCMJ - gera o pacote de instalacao para levar ao servidor
  Autor: Celso de Freitas / Refatorado: Claude
  v1.0 (20/11/2026) - Criacao (etapa 03d).
  Saida: C:\SisCMJ_Publicacao\SisCMJ_<versao>_<data>\  (FORA da pasta do Google Drive)
    programa\     executavel unico (telas e ajuda embutidas) + appsettings.json e .Production.json
    sql\          00_Criar_Banco, MASTER e MIGRACAO (rodar no SSMS, nessa ordem)
    instalacao\   instalar_servico.cmd/.ps1, desinstalar_servico.cmd/.ps1
    identidade\   logomarcas da empresa (o instalador copia as que faltam)
    LEIA-ME.txt   ordem da instalacao
  Uso: publicar.cmd (ou pelo executor, pedido publicar.pedido).
#>
param([string]$PastaSaida = 'C:\SisCMJ_Publicacao')
$ErrorActionPreference = 'Stop'
$Raiz = Split-Path $PSScriptRoot -Parent
$Projeto = Join-Path $PSScriptRoot 'SistemaCMJ.Api\SistemaCMJ.Api.csproj'
$Versao = ([xml](Get-Content -LiteralPath $Projeto -Raw)).Project.PropertyGroup.Version | Where-Object { $_ } | Select-Object -First 1
$VersaoBanco = [regex]::Match((Get-Content -LiteralPath (Join-Path $Raiz 'sql\objetos\SIS\Carga_SIS_Versao.sql') -Raw), "@Versao\s+VARCHAR\(20\)\s*=\s*'([0-9.]+)'").Groups[1].Value
$Destino = Join-Path $PastaSaida ('SisCMJ_' + $Versao + '_' + (Get-Date -Format 'yyyyMMdd_HHmm'))
Write-Output ('Programa ' + $Versao + ', banco ' + $VersaoBanco + ' -> ' + $Destino)

$ErrorActionPreference = 'Continue'
$Saida = (& dotnet publish $Projeto -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true --nologo -o (Join-Path $Destino 'programa') 2>&1 | ForEach-Object { "$_" }) -join "`r`n"
$Codigo = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
Write-Output $Saida
if ($Codigo -ne 0) { Write-Output 'RESULTADO: ERRO na publicacao'; exit 1 }

New-Item -ItemType Directory -Force -Path (Join-Path $Destino 'sql'), (Join-Path $Destino 'instalacao'), (Join-Path $Destino 'identidade') | Out-Null
Copy-Item (Join-Path $Raiz 'sql\MASTER\SISTEMACMJ_00_Criar_Banco.sql'), (Join-Path $Raiz 'sql\MASTER\SISTEMACMJ_MASTER_Instalacao.sql'), (Join-Path $Raiz 'sql\MASTER\SISTEMACMJ_MIGRACAO_Instalacao.sql') -Destination (Join-Path $Destino 'sql')
Get-ChildItem -LiteralPath (Join-Path $Raiz 'instalacao') -File | Where-Object { $_.Extension -in '.ps1', '.cmd' } | Copy-Item -Destination (Join-Path $Destino 'instalacao')
Get-ChildItem -LiteralPath (Join-Path $Raiz 'docs\identidade') -File | Where-Object { $_.Extension -in '.png', '.jpg' } | Copy-Item -Destination (Join-Path $Destino 'identidade')

$Leia = @"
SisCMJ $Versao (banco $VersaoBanco) - pacote gerado em $(Get-Date -Format 'dd/MM/yyyy HH:mm')

ORDEM DA INSTALACAO NO SERVIDOR (roteiro completo: docs\Roteiro_Instalacao_Servidor.md)
 1. SQL Server 2025 Express (instancia SQL2025, autenticacao mista), SSMS e .NET 10 Hosting Bundle ja instalados.
 2. SSMS: abrir e rodar sql\SISTEMACMJ_00_Criar_Banco.sql (F5).
 3. SSMS: selecionar o banco SISTEMACMJ, abrir e rodar sql\SISTEMACMJ_MASTER_Instalacao.sql (F5).
 4. (so na virada) SSMS: rodar sql\SISTEMACMJ_MIGRACAO_Instalacao.sql no banco SISTEMACMJ.
 5. instalacao\instalar_servico.cmd -> botao direito -> Executar como administrador.
 6. Neste servidor: https://localhost:5443/instalacao.html -> senhas dos administradores (so na 1a vez).
 7. Computadores dos usuarios: SisCMJ_certificado.cer + preparar_computador_usuario.cmd (gerados pelo passo 5).

ATUALIZACAO (versao nova): passo 3 (MASTER novo) e passo 5 (instalar_servico.cmd de novo). Nada se perde.
"@
[System.IO.File]::WriteAllText((Join-Path $Destino 'LEIA-ME.txt'), $Leia.Replace("`n", "`r`n").Replace("`r`r", "`r"), (New-Object System.Text.UTF8Encoding($true)))

$Exe = Join-Path $Destino 'programa\SistemaCMJ.Api.exe'
$Itens = Get-ChildItem -LiteralPath (Join-Path $Destino 'programa') -Recurse
Write-Output ('Arquivos do programa: ' + (($Itens | Where-Object { -not $_.PSIsContainer } | ForEach-Object { $_.Name }) -join ', '))
Write-Output ('Pasta wwwroot no pacote: ' + $(if (Test-Path -LiteralPath (Join-Path $Destino 'programa\wwwroot')) { 'SIM (ERRO: as telas deviam estar embutidas)' } else { 'nao (telas embutidas)' }))
Write-Output ('Executavel: ' + [math]::Round((Get-Item -LiteralPath $Exe).Length / 1MB, 1) + ' MB')
Write-Output ('PACOTE: ' + $Destino)
Write-Output 'RESULTADO: OK'
exit 0
