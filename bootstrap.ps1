<#
.SYNOPSIS
    Prepara este projeto para rodar nesta maquina.

.DESCRIPTION
    Parte do contrato de portabilidade do Emmily AI Project OS: quem clona o
    projeto em outra maquina roda ISTO e descobre o que falta, sem adivinhar.

    O script e IDEMPOTENTE e NAO-DESTRUTIVO: pode ser rodado quantas vezes
    quiser; ele nunca sobrescreve um .env existente nem apaga nada.

.PARAMETER Check
    Modo diagnostico: nao cria .venv, nao instala dependencia e nao cria .env.

    ATENCAO, e isto e uma correcao de contrato apontada pelo qa-reviewer na
    2.4: -Check RODA a suite de testes do projeto. Rodar teste e o unico jeito
    de saber que o comando documentado funciona, e essa era a lacuna mais cara
    da Fase 1 - mas a suite e do PROJETO, e o que ela escreve (fixture em
    logs/ ou output/, por exemplo) e escrito. Este script nao cria nada; a
    suite do projeto pode.

.EXAMPLE
    .\bootstrap.ps1
    .\bootstrap.ps1 -Check

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 em UTF-8 sem BOM como ANSI.
#>
[CmdletBinding()]
param(
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$problemas = @()
$avisos    = @()

function Invoke-GitLocal {
    <#
      Roda o git e devolve @{ Ok = <bool>; Saida = <linhas> }.

      Existe porque o Invoke-Git da plataforma vive em scripts/lib/, que NAO
      viaja com o projeto - e o bootstrap e justamente o arquivo que roda numa
      maquina onde nada mais foi verificado.

      Duas coisas, e as duas foram achado do qa-reviewer no fechamento da 2.4:

        1. Sob $ErrorActionPreference = 'Stop', stderr de executavel nativo
           vira erro TERMINANTE no PowerShell 5.1. Um aviso do git derrubava
           este script antes do resumo - o diagnostico que ele existe para dar
           nao saia.
        2. E '2>$null' sozinho NAO protege - esta plataforma media isso. Pior:
           mascarar a falha fazia o check de seguranca imprimir
           "[OK] nenhum .env ou chave versionada" com o git sem ter respondido.
           Silencio indistinguivel de "nada a acusar", dentro do unico check
           de seguranca que um projeto governado roda sozinho.

      Por isso quem chama recebe Ok = $false e tem de tratar como NAO
      VERIFICADO - nunca como ausencia de achado.
    #>
    param([Parameter(Mandatory = $true)][string[]]$Argumentos)
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $saida = & git @Argumentos 2>$null
        $codigo = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $anterior
    }
    return @{ Ok = ($codigo -eq 0); Saida = @($saida) }
}

function Write-Item {
    param([string]$Estado, [string]$Texto)
    $cor = switch ($Estado) {
        'OK'    { 'Green' }
        'FALTA' { 'Red' }
        'AVISO' { 'Yellow' }
        default { 'Gray' }
    }
    Write-Host ("  [{0,-5}] {1}" -f $Estado, $Texto) -ForegroundColor $cor
}

Write-Host ""
Write-Host "=== bootstrap: Video Knowledge Lab ===" -ForegroundColor Cyan
Write-Host "    $Root"
Write-Host ""

# --- 1. Git -------------------------------------------------------------------
Write-Host "Git" -ForegroundColor White
if (Get-Command git -ErrorAction SilentlyContinue) {
    $rVer = Invoke-GitLocal @('--version')
    if ($rVer.Ok -and $rVer.Saida.Count -gt 0) {
        Write-Item 'OK' ("git " + (($rVer.Saida[0] -split ' ')[2]))
    } else {
        Write-Item 'AVISO' "git respondeu, mas nao deu a versao"
    }

    # 'config' sai com 1 quando a chave nao existe: aqui codigo != 0 e
    # RESPOSTA (nao configurado), nao falha.
    $nome  = (Invoke-GitLocal @('-C', $Root, 'config', 'user.name')).Saida  | Select-Object -First 1
    $email = (Invoke-GitLocal @('-C', $Root, 'config', 'user.email')).Saida | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($nome) -or [string]::IsNullOrWhiteSpace($email)) {
        $problemas += "Identidade Git ausente: o primeiro commit vai falhar. Configure user.name e user.email."
        Write-Item 'FALTA' "identidade Git (user.name / user.email)"
    } else {
        Write-Item 'OK' "identidade: $nome <$email>"
    }

    if (Test-Path (Join-Path $Root '.git')) {
        Write-Item 'OK' "repositorio inicializado"
    } else {
        $avisos += "Este projeto ainda nao e um repositorio Git. Rode: git init"
        Write-Item 'AVISO' "sem repositorio Git"
    }
} else {
    $problemas += "Git nao encontrado no PATH."
    Write-Item 'FALTA' "git"
}

# --- 2. Python ----------------------------------------------------------------
Write-Host ""
Write-Host "Python" -ForegroundColor White
$pyEsperado = 'nao-usa'
if ($pyEsperado -eq 'nao-usa') {
    Write-Item 'INFO' "este projeto nao usa Python"
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
    $disponiveis = (py -0 2>$null) -join ' '
    if ($disponiveis -match [regex]::Escape($pyEsperado)) {
        Write-Item 'OK' "Python $pyEsperado disponivel (use: py -$pyEsperado)"
    } else {
        $problemas += "Python $pyEsperado nao encontrado. Disponiveis: $disponiveis"
        Write-Item 'FALTA' "Python $pyEsperado"
    }
} else {
    $problemas += "Launcher 'py' nao encontrado."
    Write-Item 'FALTA' "launcher py"
}

# --- 3. Ambiente Python do projeto --------------------------------------------
# Existe porque o teste de aceitacao da Fase 1 mostrou o problema: o comando
# de teste documentado nao funcionava, porque pytest nao esta instalado nos
# interpretadores globais. Descobrir isso a mao, projeto por projeto, e o tipo
# de atrito que o bootstrap existe para eliminar.
if ($pyEsperado -ne 'nao-usa') {
    Write-Host ""
    Write-Host "Ambiente do projeto" -ForegroundColor White
    $venvPython = Join-Path $Root '.venv\Scripts\python.exe'
    $requisitos = Join-Path $Root 'requirements.txt'

    if (Test-Path $venvPython) {
        Write-Item 'OK' ".venv presente"
    } elseif ($Check) {
        $avisos += ".venv ausente. Rode o bootstrap sem -Check para criar."
        Write-Item 'AVISO' ".venv ausente"
    } else {
        & py "-$pyEsperado" -m venv (Join-Path $Root '.venv')
        if (Test-Path $venvPython) {
            Write-Item 'OK' ".venv criado com Python $pyEsperado"
        } else {
            $problemas += "Falhou ao criar o .venv."
            Write-Item 'FALTA' ".venv"
        }
    }

    if (-not (Test-Path $requisitos)) {
        Write-Item 'INFO' "sem requirements.txt (projeto sem dependencia externa)"
    } elseif (-not (Test-Path $venvPython)) {
        Write-Item 'AVISO' "dependencias nao instaladas (sem .venv)"
    } elseif ($Check) {
        # Nao instala em modo diagnostico; so diz se falta algo.
        $instalados = & $venvPython -m pip freeze 2>$null
        $declarados = Get-Content $requisitos |
                      Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#' } |
                      ForEach-Object { ($_ -split '[<>=!~]')[0].Trim() }
        $faltando = $declarados | Where-Object { $p = $_; -not ($instalados | Where-Object { $_ -match "^$p" }) }
        if ($faltando) {
            $avisos += "Dependencias declaradas e nao instaladas: " + ($faltando -join ', ')
            Write-Item 'AVISO' ("nao instaladas: " + ($faltando -join ', '))
        } else {
            Write-Item 'OK' "dependencias instaladas"
        }
    } else {
        & $venvPython -m pip install --quiet --disable-pip-version-check -r $requisitos
        if ($LASTEXITCODE -eq 0) {
            Write-Item 'OK' "dependencias instaladas de requirements.txt"
        } else {
            $problemas += "pip install falhou. Rode a mao para ver o erro."
            Write-Item 'FALTA' "dependencias"
        }
    }
}

# --- 4. .env ------------------------------------------------------------------
Write-Host ""
Write-Host "Configuracao local" -ForegroundColor White
$envExample = Join-Path $Root '.env.example'
$envReal    = Join-Path $Root '.env'
if (-not (Test-Path $envExample)) {
    Write-Item 'INFO' "projeto sem .env.example"
} elseif (Test-Path $envReal) {
    Write-Item 'OK' ".env presente (nao foi tocado)"
    # Variavel declarada no exemplo mas ausente no real = quebra silenciosa.
    $chavesEx   = Select-String -Path $envExample -Pattern '^\s*#?\s*([A-Z_][A-Z0-9_]*)=' -AllMatches |
                  ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    $chavesReal = Select-String -Path $envReal -Pattern '^\s*([A-Z_][A-Z0-9_]*)=' -AllMatches |
                  ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    $faltando = $chavesEx | Where-Object { $chavesReal -notcontains $_ }
    if ($faltando) {
        $avisos += "Variaveis do .env.example ausentes no .env: " + ($faltando -join ', ')
        Write-Item 'AVISO' ("variaveis ausentes no .env: " + ($faltando -join ', '))
    }
} elseif ($Check) {
    $avisos += ".env ausente. Rode o bootstrap sem -Check para criar a partir do exemplo."
    Write-Item 'AVISO' ".env ausente"
} else {
    Copy-Item $envExample $envReal
    Write-Item 'OK' ".env criado a partir de .env.example (preencha os valores)"
}

# --- 5. Estrutura minima ------------------------------------------------------
Write-Host ""
Write-Host "Estrutura" -ForegroundColor White
foreach ($f in @('CLAUDE.md', 'README.md', 'project.yaml', 'docs\STATE.md', '.gitignore')) {
    if (Test-Path (Join-Path $Root $f)) {
        Write-Item 'OK' $f
    } else {
        $avisos += "Arquivo esperado ausente: $f"
        Write-Item 'AVISO' "$f ausente"
    }
}

# --- 6. Seguranca basica ------------------------------------------------------
Write-Host ""
Write-Host "Seguranca" -ForegroundColor White
if (Test-Path (Join-Path $Root '.git')) {
    # O erro mais caro e barato de detectar: .env versionado.
    #
    # E a resposta do git tem de ser CONFERIDA antes de virar afirmacao. A
    # versao anterior fazia 'git ls-files 2>$null' e, com o indice ilegivel ou
    # um index.lock de outro processo, a lista vinha vazia e este bloco
    # imprimia "[OK] nenhum .env ou chave versionada". Afirmar seguranca sobre
    # um git que nao respondeu, no unico check que o projeto roda sozinho.
    $rGit = Invoke-GitLocal @('-C', $Root, 'ls-files')
    if (-not $rGit.Ok) {
        $problemas += "NAO FOI POSSIVEL VERIFICAR se ha arquivo sensivel versionado: o git nao respondeu (indice ilegivel, index.lock de outro processo, permissao). Isto NAO e o mesmo que estar limpo."
        Write-Item 'FALTA' "o git nao respondeu: verificacao de arquivo sensivel NAO aconteceu"
    } else {
        $vazando = $rGit.Saida | Where-Object { $_ -match '(^|/)\.env$' -or $_ -match '\.(key|pem|pfx|p12)$' }
        if ($vazando) {
            $problemas += "ARQUIVO SENSIVEL VERSIONADO: " + ($vazando -join ', ')
            Write-Item 'FALTA' ("sensivel no Git: " + ($vazando -join ', '))
        } else {
            Write-Item 'OK' ("nenhum .env ou chave versionada (" + $rGit.Saida.Count + " arquivo(s) rastreado(s) conferido(s))")
        }
    }
}

# --- 7. Testes ----------------------------------------------------------------
# Roda a suite de verdade, nao apenas confere que a pasta existe. O historico
# desta plataforma e claro sobre por que: no teste de aceitacao da Fase 1 o
# comando de teste documentado nao funcionava, e ninguem tinha rodado. O
# bootstrap e o lugar onde isso se descobre em dez segundos.
#
# Roda tambem em -Check: executar teste nao cria nada.
Write-Host ""
Write-Host "Testes" -ForegroundColor White
$runner = Join-Path $Root 'tests\run-tests.ps1'

# O que o manifesto DECLARA. Comparar declaracao com realidade e o trabalho
# do /os:doctor; aqui fica a parte que custa uma linha e pega o caso mais
# comum: manifesto dizendo tests:true sobre uma pasta que nao verifica nada.
$declaraTests = $false
$manifesto = Join-Path $Root 'project.yaml'
if (Test-Path $manifesto -PathType Leaf) {
    $txtManifesto = [System.IO.File]::ReadAllText($manifesto, [System.Text.Encoding]::UTF8)
    # Leitura ESTRUTURAL, nao regex solta. A versao anterior casava
    # 'tests: true' em qualquer bloco do arquivo e NAO casava 'tests: "true"'
    # - e aspas sao o estilo dominante no proprio template, entao um manifesto
    # perfeitamente valido rebaixava BLOQUEIA para aviso justamente onde o
    # principio e "declaracao nao e verificacao". Achado do security-reviewer.
    #
    # Este script nao pode usar o leitor do harness: a trilha Python apaga
    # tests\_harness.ps1. Entao a leitura e minima e escopada: acha a linha
    # 'verificacao:' na coluna 0 e procura 'tests:' mais indentado, parando no
    # proximo bloco de coluna 0.
    $dentroDeVerificacao = $false
    foreach ($linhaMan in ($txtManifesto -split "`r?`n")) {
        if ($linhaMan -match '^verificacao:\s*$') { $dentroDeVerificacao = $true; continue }
        if ($dentroDeVerificacao -and $linhaMan -match '^\S') { break }
        if ($dentroDeVerificacao -and $linhaMan -match '^\s+tests:\s*"?true"?\s*(#.*)?$') {
            $declaraTests = $true
            break
        }
    }
}

if (-not (Test-Path $runner -PathType Leaf)) {
    if ($declaraTests) {
        $problemas += "project.yaml declara verificacao.tests: true e tests\run-tests.ps1 nao existe."
        Write-Item 'FALTA' "tests\run-tests.ps1 (declarado no manifesto)"
    } else {
        $avisos += "Sem tests\run-tests.ps1. Pasta de verificacao vazia nao conta (VERIFICATION-POLICY 4.4)."
        Write-Item 'AVISO' "sem suite de testes"
    }
} else {
    # $ErrorActionPreference baixado em volta da chamada, e isto NAO e zelo
    # excessivo: com 'Stop' (linha 27) e o '2>&1' trazendo o stderr do filho
    # para o pipeline, um ParserError na suite que voce escreveu vira
    # NativeCommandError terminante e o bootstrap ABORTA antes do resumo -
    # sem [FALTA], sem lista de problemas, com uma mensagem sobre
    # 'powershell :'. O diagnostico que este script existe para dar nao sai.
    # Achado do qa-reviewer no fechamento da 2.4: a protecao existia no
    # harness de teste da plataforma e nao aqui, no arquivo entregue.
    $antesTestes = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $saidaTestes = & powershell -NoProfile -ExecutionPolicy Bypass -File $runner 2>&1 | Out-String
        $codigoTestes = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $antesTestes
    }
    switch ($codigoTestes) {
        0 {
            Write-Item 'OK' "a suite rodou e passou"
        }
        2 {
            # Terceiro estado: nao verificado. Nunca tratar como verde.
            $motivo = 'a suite NAO rodou (saida 2)'
            if ($declaraTests) {
                $problemas += "$motivo, e o project.yaml declara verificacao.tests: true. Declaracao nao e verificacao."
                Write-Item 'FALTA' $motivo
            } else {
                $avisos += "$motivo. Nao e o mesmo que teste passando - ver VERIFICATION-POLICY 4.5."
                Write-Item 'AVISO' $motivo
            }
            $primeira = ($saidaTestes -split "`r?`n" | Where-Object { $_ -match 'Motivo:|Como resolver:' })
            foreach ($l in $primeira) { Write-Host ("         " + $l.Trim()) -ForegroundColor DarkGray }
        }
        default {
            $problemas += "A suite de testes FALHOU. Rode: .\tests\run-tests.ps1"
            Write-Item 'FALTA' "a suite rodou e falhou"
            $resumo = ($saidaTestes -split "`r?`n" | Where-Object { $_ -match 'falhou|FAIL|failed|passou' })
            foreach ($l in ($resumo | Select-Object -Last 6)) { Write-Host ("         " + $l.Trim()) -ForegroundColor DarkGray }
        }
    }
}

# --- Resumo -------------------------------------------------------------------
Write-Host ""
Write-Host "=== resumo ===" -ForegroundColor Cyan
if ($problemas.Count -eq 0 -and $avisos.Count -eq 0) {
    Write-Host "  Tudo pronto." -ForegroundColor Green
    exit 0
}
foreach ($p in $problemas) { Write-Host "  BLOQUEIA: $p" -ForegroundColor Red }
foreach ($a in $avisos)    { Write-Host "  atencao : $a" -ForegroundColor Yellow }
Write-Host ""
if ($problemas.Count -gt 0) { exit 1 }
exit 0
