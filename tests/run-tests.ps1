<#
.SYNOPSIS
    Ponto de entrada unico dos testes deste projeto.

.DESCRIPTION
    Parte do contrato de verificacao do Emmily AI Project OS. Todo projeto
    governado roda os testes pelo MESMO comando, qualquer que seja a
    linguagem:

        .\tests\run-tests.ps1

    Isso existe por dois motivos medidos, nao por gosto:

    1. O comando longo e especifico da maquina (o caminho do python do .venv)
       ficava copiado em CLAUDE.md e README.md de cada projeto, e divergia.
       Comando de teste documentado e nunca executado foi a lacuna mais cara
       do teste de aceitacao da Fase 1.

    2. Ausencia de teste NAO e teste verde. Um runner que nao encontra suite
       nenhuma e sai com 0 diz "passou" sobre nada. Aqui isso sai com 2.

    Trilhas detectadas, nesta ordem:

      Python      tests/*.py            -> pytest, no .venv do projeto
      PowerShell  tests/suites/*.ps1    -> dot-source do harness e das suites

    Um projeto usa UMA das duas. O /os:new-project apaga a trilha que nao se
    aplica, como ja faz com o requirements.txt.

.PARAMETER Suite
    So na trilha PowerShell: nomes das suites a rodar. Sem isto, roda todas.

.PARAMETER List
    Lista o que seria rodado e sai.

.OUTPUTS
    Codigo de saida, mesma convencao do ADR-0009:
      0  a suite rodou e passou
      1  a suite rodou e falhou
      2  a suite NAO rodou (sem suite, sem .venv, sem pytest)

    O 2 nao e uma variacao do 1. "Nao verificado" e um terceiro estado, e
    quem le precisa poder distinguir - ver docs/VERIFICATION-POLICY.md 4.5.

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>
[CmdletBinding()]
param(
    [string[]]$Suite,
    [switch]$List
)

$ErrorActionPreference = 'Stop'
$TestsRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root      = Split-Path -Parent $TestsRoot

function Write-Cab {
    param([string]$Texto)
    Write-Host ""
    Write-Host ("=== " + $Texto + " ===") -ForegroundColor Cyan
    Write-Host ("    " + $Root)
    Write-Host ""
}

function Exit-NaoRodou {
    <#
      Saida 2 com o motivo escrito. Chamar isto em vez de sair com 0 e a
      unica coisa que impede "sem teste" de parecer "teste passando".
    #>
    param([string]$Motivo, [string]$Como)
    Write-Host ""
    Write-Host "  A SUITE NAO RODOU (saida 2)" -ForegroundColor Red
    Write-Host ("  Motivo: " + $Motivo) -ForegroundColor Yellow
    if ($Como) { Write-Host ("  Como resolver: " + $Como) -ForegroundColor Yellow }
    Write-Host "  Isto NAO e o mesmo que teste passando - ver VERIFICATION-POLICY 4.5." -ForegroundColor DarkGray
    Write-Host ""
    exit 2
}

# --- Deteccao da trilha -------------------------------------------------------
$arquivosPy = @(Get-ChildItem $TestsRoot -Filter 'test_*.py' -File -ErrorAction SilentlyContinue)
$dirSuites  = Join-Path $TestsRoot 'suites'
$arquivosPs = @()
if (Test-Path $dirSuites -PathType Container) {
    $arquivosPs = @(Get-ChildItem $dirSuites -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
}

if ($arquivosPy.Count -gt 0 -and $arquivosPs.Count -gt 0) {
    # Ambiguidade e defeito de instanciacao: o /os:new-project deveria ter
    # apagado uma das trilhas. Recusar e melhor que escolher em silencio.
    Exit-NaoRodou 'as DUAS trilhas existem (tests/test_*.py e tests/suites/*.ps1)' `
                  'apague a trilha que este projeto nao usa - ver tests/README.md'
}

if ($arquivosPy.Count -eq 0 -and $arquivosPs.Count -eq 0) {
    Exit-NaoRodou 'nenhuma suite encontrada em tests/' `
                  'escreva um teste. Pasta de verificacao vazia nao conta (VERIFICATION-POLICY 4.4)'
}

# --- Trilha Python ------------------------------------------------------------
if ($arquivosPy.Count -gt 0) {
    if ($List) {
        Write-Cab 'testes deste projeto: trilha Python'
        foreach ($f in $arquivosPy) { Write-Host ("  " + $f.Name) }
        Write-Host ""
        exit 0
    }

    $venvPython = Join-Path $Root '.venv\Scripts\python.exe'
    if (-not (Test-Path $venvPython -PathType Leaf)) {
        # pytest nao existe nos interpretadores globais desta maquina. Cair
        # para o python global daria "ModuleNotFoundError: pytest", que parece
        # erro do projeto e nao falta de ambiente.
        Exit-NaoRodou 'o .venv do projeto nao existe' '.\bootstrap.ps1'
    }

    # A preferencia tambem baixa AQUI, e nao so em volta do pytest: qualquer
    # stderr deste interpretador - aviso de depreciacao, sitecustomize, plugin
    # - viraria terminante sob 'Stop' e o runner sairia com 1, "a suite rodou
    # e falhou", para um problema de AMBIENTE que o contrato manda reportar
    # como 2. Achado do qa-reviewer: era a mesma confusao 1-vs-2, um ramo
    # antes do que ja tinha sido corrigido.
    $antesSonda = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $venvPython -c "import importlib.util,sys; sys.exit(0 if importlib.util.find_spec('pytest') else 1)" 2>$null | Out-Null
        $codigoSonda = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $antesSonda
    }
    if ($codigoSonda -ne 0) {
        Exit-NaoRodou 'pytest nao esta instalado no .venv (ou o interpretador do .venv nao respondeu)' '.\bootstrap.ps1'
    }

    Write-Cab 'testes deste projeto: trilha Python'
    # Preferencia baixada em volta da chamada: se o pytest escrever em stderr
    # (um aviso de plugin basta), no PowerShell 5.1 isso vira ErrorRecord e
    # sob 'Stop' derrubaria o runner com saida 1 - "falhou" no lugar de
    # "avisou". Achado do qa-reviewer.
    $antes = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $venvPython -m pytest $TestsRoot -q
        $codigo = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $antes
    }
    Write-Host ""
    if ($codigo -eq 0) { exit 0 }

    # Os codigos do pytest que significam "a suite NAO rodou", e nao "a suite
    # rodou e falhou". Mapear so o 5 deixava os outros dois virarem 1 - e
    # apagar essa distincao e apagar a razao de existir desta subfase:
    #   2 interrompido    3 erro interno    4 erro de uso    5 nada coletado
    $naoRodou = @{
        2 = @('a execucao do pytest foi interrompida', 'rode de novo; se repetir, rode o pytest a mao para ver onde para')
        3 = @('erro INTERNO do pytest', 'rode o pytest a mao: pode ser plugin incompativel no .venv')
        4 = @('erro de USO do pytest - tipicamente falha ao coletar (erro de import ou de sintaxe em conftest.py ou num test_*.py)', 'rode o pytest a mao para ver o traceback da coleta')
        5 = @('o pytest nao coletou nenhum teste', 'confira o nome dos arquivos (test_*.py) e das funcoes (test_*)')
    }
    if ($naoRodou.ContainsKey($codigo)) {
        Exit-NaoRodou $naoRodou[$codigo][0] $naoRodou[$codigo][1]
    }
    exit 1
}

# --- Trilha PowerShell --------------------------------------------------------
$harness = Join-Path $TestsRoot '_harness.ps1'
if (-not (Test-Path $harness -PathType Leaf)) {
    Exit-NaoRodou 'tests/_harness.ps1 nao existe' `
                  'a trilha PowerShell precisa do harness - ver tests/README.md'
}

$disponiveis = $arquivosPs | ForEach-Object { $_.BaseName } | Sort-Object

if ($List) {
    Write-Cab 'testes deste projeto: trilha PowerShell'
    foreach ($n in $disponiveis) {
        $casos = (Select-String -Path (Join-Path $dirSuites "$n.ps1") -Pattern '^Test-Caso ').Count
        Write-Host ("  {0,-14} {1} casos" -f $n, $casos)
    }
    Write-Host ""
    exit 0
}

if ($Suite) {
    $invalidas = $Suite | Where-Object { $disponiveis -notcontains $_ }
    if ($invalidas) {
        Write-Host ""
        Write-Host ("  Suite desconhecida: " + ($invalidas -join ', ')) -ForegroundColor Red
        Write-Host ("  Disponiveis: " + ($disponiveis -join ', ')) -ForegroundColor Yellow
        Write-Host ""
        exit 2
    }
    $aRodar = $disponiveis | Where-Object { $Suite -contains $_ }
} else {
    $aRodar = $disponiveis
}

Write-Cab 'testes deste projeto: trilha PowerShell'

. $harness

foreach ($n in $aRodar) {
    Write-Suite $n
    . (Join-Path $dirSuites "$n.ps1")
}

Write-Host ""
Write-Host "=== resultado ===" -ForegroundColor Cyan
Write-Host ("  passou: {0}   falhou: {1}" -f $script:passou, $script:falhou)

if (($script:passou + $script:falhou) -eq 0) {
    # Suite existe, foi carregada, e nao executou caso nenhum. Verde por
    # vacuidade e o modo de falha mais barato que existe: foreach sobre lista
    # vazia passa. Recusar.
    Exit-NaoRodou 'as suites carregaram e nao executaram nenhum caso' `
                  'confira se os casos estao escritos como: Test-Caso "nome" { ... }'
}

if ($script:falhou -gt 0) {
    Write-Host ""
    Write-Host "  falhas:" -ForegroundColor Red
    foreach ($f in $script:falhas) { Write-Host "    - $f" -ForegroundColor Red }
    Write-Host ""
    exit 1
}
Write-Host ""
exit 0
