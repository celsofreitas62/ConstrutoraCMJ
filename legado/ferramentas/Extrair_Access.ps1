<#
    Extrair_Access.ps1
    SistemaCMJ - Fase 1, levantamento do Access legado (conversa "01b - Levantamento do Access")
    Criado em 15/11/2026. Parâmetros -ArquivoBE/-SomenteBE para a base antiga de 2015. Revisado em 15/11/2026 (Access sem licença, modo somente leitura: dados lidos pelo DAO, consultas sem depender do vínculo).

    O que faz (sem alterar os .mdb originais: trabalha em cópias na pasta temporária):
      1. Back-end (CashBookCMJ_be.mdb): estrutura das tabelas, campos, índices, relacionamentos e
         quantidade de registros.
      2. Front-end (CashBookCMJ.mdb): tabelas vinculadas, tabelas locais, consultas (SQL de cada uma),
         formulários, relatórios, macros e módulos VBA (SaveAsText), referências do VBA e
         propriedades de inicialização.
      3. Opcional (-ExportarDados): dados de cada tabela do back-end em CSV UTF-8, para a análise
         de qualidade (nulos, duplicidades, datas inválidas, órfãos).

    Saída:
      C:\SistemaCMJ\legado\extracao\      estrutura, consultas e objetos (vai para o Git)
      C:\SistemaCMJ\legado\dados_brutos\  CSV com dados reais (LGPD: fora do Git, ver .gitignore)

    Pré-requisito: Microsoft Access instalado no notebook.

    Como rodar (PowerShell, não precisa ser administrador):
      Set-Location C:\SistemaCMJ
      powershell -ExecutionPolicy Bypass -File .\legado\ferramentas\Extrair_Access.ps1
      powershell -ExecutionPolicy Bypass -File .\legado\ferramentas\Extrair_Access.ps1 -ExportarDados

    Se o back-end tiver senha:  ... -SenhaBE "senha"
    Base antiga (só dados, sem o front-end):
      powershell -ExecutionPolicy Bypass -File .\legado\ferramentas\Extrair_Access.ps1 -ArquivoBE "CashBookCMJ_be 2015.mdb" -SomenteBE -ExportarDados
      (saída em legado\extracao_CashBookCMJ_be_2015 e legado\dados_brutos\CashBookCMJ_be_2015)
    Se o Access usar arquivo de segurança (.mdw): o script avisa no erros.txt.
#>

param(
    [string]$Pasta = 'C:\SistemaCMJ',
    [switch]$ExportarDados,
    [string]$SenhaBE = '',
    [string]$SenhaFE = '',
    [string]$ArquivoBE = 'CashBookCMJ_be.mdb',   # outro back-end, ex.: 'CashBookCMJ_be 2015.mdb'
    [switch]$SomenteBE                           # pula o front-end (consultas, telas, VBA)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Off

# ---------------------------------------------------------------------------------------------
# Caminhos
# ---------------------------------------------------------------------------------------------
$origFE   = Join-Path $Pasta 'CashBookCMJ\CashBookCMJ.mdb'
$origBE   = Join-Path $Pasta ('CashBookCMJ\' + $ArquivoBE)
$saida    = Join-Path $Pasta 'legado\extracao'
$saidaDad = Join-Path $Pasta 'legado\dados_brutos'
if ($ArquivoBE -ne 'CashBookCMJ_be.mdb') {
    # Back-end alternativo (ex.: base antiga de 2015): saída em pastas próprias, sem misturar com a base atual
    $marca = ([System.IO.Path]::GetFileNameWithoutExtension($ArquivoBE)) -replace '[^A-Za-z0-9]+', '_'
    $saida    = Join-Path $Pasta ('legado\extracao_' + $marca)
    $saidaDad = Join-Path $Pasta ('legado\dados_brutos\' + $marca)
}
$temp     = Join-Path $env:TEMP 'SistemaCMJ_extracao'
$copiaFE  = Join-Path $temp 'FE.mdb'
$copiaBE  = Join-Path $temp 'BE.mdb'

$script:erros = New-Object System.Collections.Generic.List[string]
function Registrar-Erro([string]$onde, $err) {
    $msg = '{0} | {1} | {2}' -f (Get-Date -Format 'HH:mm:ss'), $onde, ($err | Out-String).Trim()
    $script:erros.Add($msg)
    Write-Host "  ERRO em $onde (detalhe em erros.txt)" -ForegroundColor Yellow
}

function Nome-Arquivo([string]$nome) {
    $inval = [System.IO.Path]::GetInvalidFileNameChars()
    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $nome.ToCharArray()) {
        if ($inval -contains $c) { [void]$sb.Append('_') } else { [void]$sb.Append($c) }
    }
    return $sb.ToString()
}

function Gravar-Texto([string]$arquivo, [string]$texto) {
    # UTF-8 com BOM (texto em português), CRLF
    $texto = $texto -replace "`r?`n", "`r`n"
    [System.IO.File]::WriteAllText($arquivo, $texto, (New-Object System.Text.UTF8Encoding($true)))
}

function Texto-Csv($v) {
    # Converte qualquer valor (inclusive vindo do COM) em texto seguro para CSV
    if ($null -eq $v -or $v -is [System.DBNull]) { return '' }
    try {
        if ($v -is [datetime]) { $t = $v.ToString('yyyy-MM-dd HH:mm:ss') }
        elseif ($v -is [byte[]]) { $t = '<binario ' + $v.Length + ' bytes>' }
        elseif ($v -is [double] -or $v -is [single] -or $v -is [decimal]) { $t = $v.ToString([System.Globalization.CultureInfo]::InvariantCulture) }
        else { $t = [string]$v }
    } catch { $t = '<valor ilegivel>' }
    if ($t.IndexOfAny([char[]]@(';', '"', "`r", "`n")) -ge 0) { $t = '"' + $t.Replace('"', '""') + '"' }
    return $t
}

function Gravar-Csv($listas, [string]$arquivo) {
    # $listas: uma ou mais listas de objetos; junta tudo e grava UTF-8 com BOM, separador ';', CRLF
    $todos = New-Object System.Collections.Generic.List[object]
    $fila = New-Object System.Collections.Generic.List[object]
    if ($listas -is [System.Collections.IList]) { for ($k = 0; $k -lt $listas.Count; $k++) { $fila.Add($listas[$k]) } }
    elseif ($null -ne $listas) { $fila.Add($listas) }
    foreach ($l in $fila) {
        if ($null -eq $l) { continue }
        if ($l -is [System.Collections.IList]) {
            for ($k = 0; $k -lt $l.Count; $k++) { if ($null -ne $l[$k]) { $todos.Add($l[$k]) } }
        } else { $todos.Add($l) }
    }
    if ($todos.Count -eq 0) { Gravar-Texto $arquivo '(vazio)'; return }
    $cols = @($todos[0].PSObject.Properties | ForEach-Object { $_.Name })
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append(($cols -join ';')).Append("`r`n")
    foreach ($o in $todos) {
        $vals = foreach ($c in $cols) { $v = $null; try { $v = $o.$c } catch { }; Texto-Csv $v }
        [void]$sb.Append((@($vals) -join ';')).Append("`r`n")
    }
    [System.IO.File]::WriteAllText($arquivo, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
}

function Exportar-Dados($db, [string]$tabela, [string]$arquivo) {
    # Lê pelo DAO (funciona mesmo com o Access em modo somente leitura) em blocos de 5.000 linhas
    # (GetRows: uma chamada ao Access por bloco, muito mais rápido que campo a campo) e grava CSV UTF-8
    $rs = $db.OpenRecordset($tabela, 4)   # 4 = dbOpenSnapshot (nome da tabela sem colchetes)
    $sw = New-Object System.IO.StreamWriter($arquivo, $false, (New-Object System.Text.UTF8Encoding($true)))
    $sw.NewLine = "`r`n"
    try {
        $n = $rs.Fields.Count
        $cab = for ($i = 0; $i -lt $n; $i++) { Texto-Csv $rs.Fields.Item($i).Name }
        $sw.WriteLine((@($cab) -join ';'))
        $linhas = 0
        $sb = New-Object System.Text.StringBuilder
        while (-not $rs.EOF) {
            $bloco = $rs.GetRows(5000)        # matriz [campo, linha]
            $qtd = $bloco.GetLength(1)
            for ($r = 0; $r -lt $qtd; $r++) {
                [void]$sb.Clear()
                for ($i = 0; $i -lt $n; $i++) {
                    if ($i -gt 0) { [void]$sb.Append(';') }
                    [void]$sb.Append((Texto-Csv $bloco[$i, $r]))
                }
                $sw.WriteLine($sb.ToString())
            }
            $linhas += $qtd
            if ($qtd -gt 0) { Write-Host ("    ... {0} linhas" -f $linhas) }
        }
        return $linhas
    } finally {
        $sw.Close()
        $rs.Close()
    }
}

function Ler-Prop($obj, [string]$prop) {
    try { return $obj.Properties.Item($prop).Value } catch { return $null }
}

$tiposDAO = @{
    1='Sim/Não (Boolean)'; 2='Byte'; 3='Inteiro (Integer)'; 4='Inteiro Longo (Long)'; 5='Moeda (Currency)';
    6='Simples (Single)'; 7='Duplo (Double)'; 8='Data/Hora'; 9='Binário'; 10='Texto'; 11='Objeto OLE';
    12='Memorando (Memo)'; 15='GUID'; 16='BigInt'; 17='VarBinary'; 18='Char'; 19='Numeric'; 20='Decimal'
}
$tiposConsulta = @{
    0='Seleção'; 16='Tabela de referência cruzada'; 32='Exclusão'; 48='Atualização'; 64='Acréscimo';
    80='Criar tabela'; 96='Definição de dados'; 112='Passagem (pass-through)'; 128='União'; 144='Pass-through com parâmetros'; 240='Ação'
}

# ---------------------------------------------------------------------------------------------
# Documenta tabelas de um banco aberto via DAO
# ---------------------------------------------------------------------------------------------
function Documentar-Tabelas($db, [string]$origem) {
    $campos = New-Object System.Collections.Generic.List[object]
    $indices = New-Object System.Collections.Generic.List[object]
    $tabelas = New-Object System.Collections.Generic.List[object]

    foreach ($td in $db.TableDefs) {
        $nomeT = $td.Name
        if ($nomeT -like 'MSys*' -or $nomeT -like '~*' -or $nomeT -like 'USys*') { continue }
        if ($td.Connect -ne '') { continue }   # vinculadas são tratadas à parte
        Write-Host "  tabela $nomeT"
        try {
            $qtd = $null
            try { $qtd = $td.RecordCount } catch { $qtd = $null }
            $tabelas.Add([pscustomobject]@{
                Origem = $origem; Tabela = $nomeT; Registros = $qtd
                Campos = $td.Fields.Count; Indices = $td.Indexes.Count
                Descricao = (Ler-Prop $td 'Description')
                DataCriacao = $td.DateCreated; UltimaAlteracao = $td.LastUpdated
            })
            foreach ($f in $td.Fields) {
                $auto = (($f.Attributes -band 16) -ne 0)
                $campos.Add([pscustomobject]@{
                    Origem = $origem; Tabela = $nomeT; Ordem = $f.OrdinalPosition; Campo = $f.Name
                    TipoCodigo = $f.Type; Tipo = $tiposDAO[[int]$f.Type]; Tamanho = $f.Size
                    AutoNumeracao = $auto; Obrigatorio = $f.Required; PermiteVazio = $f.AllowZeroLength
                    ValorPadrao = $f.DefaultValue; RegraValidacao = $f.ValidationRule
                    TextoValidacao = $f.ValidationText; Descricao = (Ler-Prop $f 'Description')
                    Legenda = (Ler-Prop $f 'Caption'); Formato = (Ler-Prop $f 'Format')
                    MascaraEntrada = (Ler-Prop $f 'InputMask'); OrigemLinha = (Ler-Prop $f 'RowSource')
                })
            }
            foreach ($ix in $td.Indexes) {
                $lista = @()
                foreach ($fx in $ix.Fields) { $lista += $fx.Name }
                $indices.Add([pscustomobject]@{
                    Origem = $origem; Tabela = $nomeT; Indice = $ix.Name; Primario = $ix.Primary
                    Unico = $ix.Unique; IgnoraNulos = $ix.IgnoreNulls; Obrigatorio = $ix.Required
                    Estrangeiro = $ix.Foreign; Campos = ($lista -join ', ')
                })
            }
        } catch { Registrar-Erro "tabela $origem.$nomeT" $_ }
    }
    return @{ Tabelas = $tabelas; Campos = $campos; Indices = $indices }
}

function Documentar-Relacoes($db, [string]$origem) {
    $rel = New-Object System.Collections.Generic.List[object]
    foreach ($r in $db.Relations) {
        try {
            $pares = @()
            foreach ($f in $r.Fields) { $pares += ('{0} -> {1}' -f $f.Name, $f.ForeignName) }
            $a = [int]$r.Attributes
            $rel.Add([pscustomobject]@{
                Origem = $origem; Relacao = $r.Name; TabelaPrincipal = $r.Table; TabelaRelacionada = $r.ForeignTable
                Campos = ($pares -join '; ')
                Unica = (($a -band 1) -ne 0); SemIntegridade = (($a -band 2) -ne 0)
                CascataAtualiza = (($a -band 256) -ne 0); CascataExclui = (($a -band 4096) -ne 0)
                Atributos = $a
            })
        } catch { Registrar-Erro "relação $origem.$($r.Name)" $_ }
    }
    return $rel
}

# ---------------------------------------------------------------------------------------------
# Início
# ---------------------------------------------------------------------------------------------
Write-Host '== SistemaCMJ: extração do Access ==' -ForegroundColor Cyan
$exigidos = @($origBE)
if (-not $SomenteBE) { $exigidos += $origFE }
foreach ($a in $exigidos) {
    if (-not (Test-Path -LiteralPath $a)) { throw "Arquivo não encontrado: $a" }
}

foreach ($p in @($saida, (Join-Path $saida 'consultas'), (Join-Path $saida 'objetos\Formularios'),
                 (Join-Path $saida 'objetos\Relatorios'), (Join-Path $saida 'objetos\Macros'),
                 (Join-Path $saida 'objetos\Modulos'), $temp)) {
    if (-not (Test-Path -LiteralPath $p)) { [void](New-Item -ItemType Directory -Path $p) }
}

Write-Host 'Copiando os .mdb para a pasta temporária (os originais não são alterados)...'
if (-not $SomenteBE) { Copy-Item -LiteralPath $origFE -Destination $copiaFE -Force }
Copy-Item -LiteralPath $origBE -Destination $copiaBE -Force

$acc = $null
try {
    $acc = New-Object -ComObject Access.Application
    $acc.Visible = $false
    try { $acc.AutomationSecurity = 3 } catch { Registrar-Erro 'AutomationSecurity' $_ }  # 3 = desabilita macros/VBA ao abrir
    $versaoAccess = $acc.Version
    Write-Host "Access versão $versaoAccess"

    # -----------------------------------------------------------------------------------------
    # 1. Back-end
    # -----------------------------------------------------------------------------------------
    Write-Host 'Back-end: estrutura...' -ForegroundColor Cyan
    $conBE = ''
    if ($SenhaBE -ne '') { $conBE = ";PWD=$SenhaBE" }
    $dbBE = $acc.DBEngine.OpenDatabase($copiaBE, $false, $true, $conBE)
    $versaoBE = $dbBE.Version
    $docBE = Documentar-Tabelas $dbBE 'BE'
    $relBE = Documentar-Relacoes $dbBE 'BE'
    $dbBE.Close()

    $docFE = @{ Tabelas = $null; Campos = $null; Indices = $null }
    $relFE = $null; $vinc = $null; $consultas = $null; $objetos = $null; $refs = $null
    $inicio = [ordered]@{}; $versaoFE = '(não lido)'
    if (-not $SomenteBE) {
        # -----------------------------------------------------------------------------------------
        # 2. Front-end
        # -----------------------------------------------------------------------------------------
        Write-Host 'Front-end: removendo formulário de inicialização da cópia...' -ForegroundColor Cyan
        $conFE = ''
        if ($SenhaFE -ne '') { $conFE = ";PWD=$SenhaFE" }
        $inicio = [ordered]@{}
        $vincOrig = $null
        $script:revincularFalhou = $false
        try {
            $dbTmp = $acc.DBEngine.OpenDatabase($copiaFE, $false, $false, $conFE)
            foreach ($pn in @('StartupForm','AppTitle','StartupShowDBWindow','AllowBypassKey','StartupMenuBar','AllowSpecialKeys')) {
                $inicio[$pn] = Ler-Prop $dbTmp $pn
            }
            try { $dbTmp.Properties.Delete('StartupForm') } catch { }
            # Revincula, só na cópia, as tabelas vinculadas para a cópia do back-end
            $vincOrig = New-Object System.Collections.Generic.List[object]
            foreach ($td in $dbTmp.TableDefs) {
                if ($td.Connect -like '*DATABASE=*') {
                    $vincOrig.Add([pscustomobject]@{ TabelaNoFE = $td.Name; TabelaOrigem = $td.SourceTableName; Conexao = ($td.Connect -replace 'PWD=[^;]*', 'PWD=***') })
                    try { $td.Connect = ";DATABASE=$copiaBE$conBE"; $td.RefreshLink() } catch { $script:revincularFalhou = $true }
                }
            }
            if ($script:revincularFalhou) { $script:erros.Add('AVISO: não foi possível revincular as tabelas na cópia do FE (Access em modo somente leitura). Os parâmetros de algumas consultas não serão lidos; o SQL de todas é extraído normalmente.') }
            $temAutoExec = $false
            foreach ($d in $dbTmp.Containers.Item('Scripts').Documents) { if ($d.Name -eq 'AutoExec') { $temAutoExec = $true } }
            $inicio['MacroAutoExec'] = $temAutoExec
            $dbTmp.Close()
        } catch { Registrar-Erro 'propriedades de inicialização do FE' $_ }

        Write-Host 'Front-end: abrindo no Access...' -ForegroundColor Cyan
        $acc.OpenCurrentDatabase($copiaFE, $false, $SenhaFE)
        $db = $acc.CurrentDb()
        $versaoFE = $db.Version

        # Tabelas vinculadas
        $vinc = $vincOrig
        if ($null -eq $vinc) {
            $vinc = New-Object System.Collections.Generic.List[object]
            foreach ($td in $db.TableDefs) {
                if ($td.Connect -ne '') {
                    $vinc.Add([pscustomobject]@{ TabelaNoFE = $td.Name; TabelaOrigem = $td.SourceTableName; Conexao = ($td.Connect -replace 'PWD=[^;]*', 'PWD=***') })
                }
            }
        }
        # Tabelas locais do FE
        $docFE = Documentar-Tabelas $db 'FE'
        $relFE = Documentar-Relacoes $db 'FE'

        # Consultas
        Write-Host 'Front-end: consultas...' -ForegroundColor Cyan
        $consultas = New-Object System.Collections.Generic.List[object]
        foreach ($q in $db.QueryDefs) {
            try {
                $nomeQ = $q.Name
                $embutida = $nomeQ.StartsWith('~')
                $sqlQ = $q.SQL
                $params = @()
                try {
                    foreach ($pp in $q.Parameters) { $params += ('{0} ({1})' -f $pp.Name, $tiposDAO[[int]$pp.Type]) }
                } catch { $params = @('(não foi possível ler: consulta depende de tabela vinculada ou de outra consulta)') }
                $arq = (Nome-Arquivo $nomeQ) + '.sql'
                $cab = "-- Consulta: $nomeQ`r`n-- Tipo: $($tiposConsulta[[int]$q.Type]) ($($q.Type))`r`n"
                if ($params.Count -gt 0) { $cab += "-- Parâmetros: $($params -join ', ')`r`n" }
                $cab += "-- Descrição: $(Ler-Prop $q 'Description')`r`n`r`n"
                Gravar-Texto (Join-Path $saida "consultas\$arq") ($cab + $sqlQ)
                $consultas.Add([pscustomobject]@{
                    Consulta = $nomeQ; Tipo = $tiposConsulta[[int]$q.Type]; TipoCodigo = $q.Type
                    EmbutidaEmTela = $embutida; Parametros = ($params -join ', ')
                    Descricao = (Ler-Prop $q 'Description'); Arquivo = $arq
                    UltimaAlteracao = $q.LastUpdated
                })
            } catch { Registrar-Erro "consulta $($q.Name)" $_ }
        }

        # Formulários, relatórios, macros, módulos
        $objetos = New-Object System.Collections.Generic.List[object]
        $grupos = @(
            @{ Col = $acc.CurrentProject.AllForms;   Tipo = 2; Nome = 'Formulário'; Pasta = 'Formularios' },
            @{ Col = $acc.CurrentProject.AllReports; Tipo = 3; Nome = 'Relatório';  Pasta = 'Relatorios' },
            @{ Col = $acc.CurrentProject.AllMacros;  Tipo = 4; Nome = 'Macro';      Pasta = 'Macros' },
            @{ Col = $acc.CurrentProject.AllModules; Tipo = 5; Nome = 'Módulo';     Pasta = 'Modulos' }
        )
        foreach ($g in $grupos) {
            Write-Host "Front-end: $($g.Nome)s..." -ForegroundColor Cyan
            foreach ($o in $g.Col) {
                $nomeO = $o.Name
                $arq = (Nome-Arquivo $nomeO) + '.txt'
                $destino = Join-Path $saida ("objetos\{0}\{1}" -f $g.Pasta, $arq)
                $ok = $true
                try { $acc.SaveAsText($g.Tipo, $nomeO, $destino) } catch { $ok = $false; Registrar-Erro "$($g.Nome) $nomeO" $_ }
                $objetos.Add([pscustomobject]@{
                    Tipo = $g.Nome; Objeto = $nomeO; Arquivo = ("objetos\{0}\{1}" -f $g.Pasta, $arq)
                    Exportado = $ok; UltimaAlteracao = $o.DateModified
                })
            }
        }

        # Referências do VBA
        $refs = New-Object System.Collections.Generic.List[object]
        try {
            foreach ($r in $acc.References) {
                $quebrada = $null; $caminho = $null
                try { $quebrada = $r.IsBroken } catch { }
                try { $caminho = $r.FullPath } catch { }
                $refs.Add([pscustomobject]@{ Nome = $r.Name; Caminho = $caminho; Versao = ('{0}.{1}' -f $r.Major, $r.Minor); Quebrada = $quebrada })
            }
        } catch { Registrar-Erro 'referências do VBA' $_ }

        $acc.CloseCurrentDatabase()
    }

    # -----------------------------------------------------------------------------------------
    # 3. Dados (opcional)
    # -----------------------------------------------------------------------------------------
    $exportadas = 0
    if ($ExportarDados) {
        Write-Host 'Dados: exportando tabelas do back-end para CSV UTF-8...' -ForegroundColor Cyan
        if (-not (Test-Path -LiteralPath $saidaDad)) { [void](New-Item -ItemType Directory -Path $saidaDad) }
        $dbDad = $acc.DBEngine.OpenDatabase($copiaBE, $false, $true, $conBE)
        foreach ($t in $docBE.Tabelas) {
            $arq = Join-Path $saidaDad ((Nome-Arquivo $t.Tabela) + '.csv')
            Write-Host "  dados $($t.Tabela) ($($t.Registros) registros)"
            try {
                [void](Exportar-Dados $dbDad $t.Tabela $arq)
                $exportadas++
            } catch { Registrar-Erro "dados $($t.Tabela)" $_ }
        }
        $dbDad.Close()
    }

    # -----------------------------------------------------------------------------------------
    # Gravação dos arquivos de estrutura
    # -----------------------------------------------------------------------------------------
    Write-Host 'Gravando arquivos de estrutura...' -ForegroundColor Cyan
    try { Gravar-Csv @($docBE.Tabelas, $docFE.Tabelas) (Join-Path $saida 'tabelas.csv') } catch { Registrar-Erro 'gravar tabelas.csv' $_ }
    try { Gravar-Csv @($docBE.Campos, $docFE.Campos)  (Join-Path $saida 'campos.csv') } catch { Registrar-Erro 'gravar campos.csv' $_ }
    try { Gravar-Csv @($docBE.Indices, $docFE.Indices) (Join-Path $saida 'indices.csv') } catch { Registrar-Erro 'gravar indices.csv' $_ }
    try { Gravar-Csv @($relBE, $relFE) (Join-Path $saida 'relacoes.csv') } catch { Registrar-Erro 'gravar relacoes.csv' $_ }
    if (-not $SomenteBE) { try { Gravar-Csv $vinc      (Join-Path $saida 'vinculos.csv') } catch { Registrar-Erro 'gravar vinculos.csv' $_ } }
    if (-not $SomenteBE) { try { Gravar-Csv $consultas (Join-Path $saida 'consultas.csv') } catch { Registrar-Erro 'gravar consultas.csv' $_ } }
    if (-not $SomenteBE) { try { Gravar-Csv $objetos   (Join-Path $saida 'objetos.csv') } catch { Registrar-Erro 'gravar objetos.csv' $_ } }
    if (-not $SomenteBE) { try { Gravar-Csv $refs      (Join-Path $saida 'referencias_vba.csv') } catch { Registrar-Erro 'gravar referencias_vba.csv' $_ } }

    $txtInicio = ($inicio.GetEnumerator() | ForEach-Object { '  {0} = {1}' -f $_.Key, $_.Value }) -join "`r`n"
    $resumo = @"
Extração do Access - SistemaCMJ
Data: $(Get-Date -Format 'dd/MM/yyyy HH:mm')
Access: $versaoAccess   Jet/ACE FE: $versaoFE   BE: $versaoBE

Back-end:  $($docBE.Tabelas.Count) tabelas, $($docBE.Campos.Count) campos, $($docBE.Indices.Count) índices, $(@($relBE).Count) relações
Front-end: $($vinc.Count) tabelas vinculadas, $($docFE.Tabelas.Count) tabelas locais, $($consultas.Count) consultas
Objetos:   $(@($objetos | Where-Object Tipo -eq 'Formulário').Count) formulários, $(@($objetos | Where-Object Tipo -eq 'Relatório').Count) relatórios, $(@($objetos | Where-Object Tipo -eq 'Macro').Count) macros, $(@($objetos | Where-Object Tipo -eq 'Módulo').Count) módulos
Dados:     $(if ($ExportarDados) { "$exportadas tabelas exportadas para legado\dados_brutos" } else { 'não exportados (rodar com -ExportarDados)' })
Erros:     $($script:erros.Count) (ver erros.txt)

Inicialização do front-end:
$txtInicio
"@
    Gravar-Texto (Join-Path $saida 'resumo.txt') $resumo
    Write-Host ''
    Write-Host $resumo
}
catch {
    Registrar-Erro 'geral' $_
    $m = ($_ | Out-String)
    if ($m -match 'permiss|mdw|workgroup|grupo de trabalho') {
        $script:erros.Add('DICA: o Access parece usar segurança de grupo de trabalho (.mdw). Avise o Claude e informe onde fica o arquivo .mdw e o usuário/senha.')
    }
    Write-Host 'A extração parou por um erro. Veja legado\extracao\erros.txt e cole o conteúdo na conversa.' -ForegroundColor Red
}
finally {
    $txtErros = '(nenhum erro)'
    if ($script:erros.Count -gt 0) { $txtErros = $script:erros -join "`r`n" }
    Gravar-Texto (Join-Path $saida 'erros.txt') $txtErros
    if ($null -ne $acc) {
        try { $acc.CloseCurrentDatabase() } catch { }
        try { $acc.Quit() } catch { }
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($acc)
    }
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    Start-Sleep -Seconds 2
    try { Remove-Item -LiteralPath $temp -Recurse -Force } catch { }
    Write-Host 'Fim. Avise o Claude na conversa: "Extração concluída".' -ForegroundColor Green
}
