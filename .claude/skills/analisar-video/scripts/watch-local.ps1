<#
.SYNOPSIS
  Roda o plugin Watch (bradautomates/claude-video) SEMPRE no modo local e gratuito,
  gravando todo material bruto em trabalho/<Id>/ (ignorado pelo Git).

.DESCRIPTION
  Garantias deste wrapper (ver docs/decisions/ADR-0003):
    --engine local      nunca usa Gemini, mesmo que exista GEMINI_API_KEY
    --whisper whisperx  fallback de fala sempre local; nunca Groq/OpenAI
    sem cookies         so com -Cookies explicito, autorizado pela Emmily
  O relatorio do Watch vai para a saida padrao e tambem para trabalho/<Id>/relatorio-watch.md.

.EXAMPLE
  .\.claude\skills\analisar-video\scripts\watch-local.ps1 -Fonte "https://www.instagram.com/reel/XXXX/" -Id vkl-0001 -Idioma pt
#>
param(
  [Parameter(Mandatory)][string]$Fonte,          # URL ou caminho de arquivo local
  [Parameter(Mandatory)][ValidatePattern('^(vkl-\d{4}|_validacao)$')][string]$Id,
  [ValidatePattern('^([a-z]{2})?$')][string]$Idioma = '',   # dica de idioma falado p/ WhisperX (pt, en, es). Vazio = autodeteccao
  [ValidateSet('transcript','efficient','balanced','token-burner')][string]$Detalhe = 'balanced',
  [int]$Resolucao = 1024,                        # 1024 ajuda a ler texto e codigo na tela
  [string]$Timestamps = '',                      # ex.: "0:04,0:12" — frames extras em momentos citados na fala
  [string]$Cookies = ''                          # arquivo de cookies FORA do repositorio; so com autorizacao explicita
)
$ErrorActionPreference = 'Stop'

# Ferramentas instaladas via winget podem nao estar no PATH de uma sessao antiga.
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')

$raiz = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$cache = Join-Path $HOME '.claude\plugins\cache\claude-video\watch'
$watch = Get-ChildItem $cache -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match '^\d+(\.\d+)+$' } |
  Sort-Object { [version]$_.Name } -Descending |
  ForEach-Object { Join-Path $_.FullName 'skills\watch\scripts\watch.py' } |
  Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $watch) { Write-Error "Plugin Watch nao encontrado em $cache. Rode: /plugin install watch@claude-video"; exit 2 }

# Python fixo (a maquina tem 3.12 e 3.13). O WhisperX usa o proprio Python 3.12 isolado.
& py -3.13 -c "import sys" 2>$null
if ($LASTEXITCODE) { Write-Error 'Python 3.13 (py -3.13) nao encontrado.'; exit 2 }

$saida = Join-Path $raiz "trabalho\$Id"
New-Item -ItemType Directory -Force $saida | Out-Null

$argsWatch = @($watch, $Fonte, '--engine', 'local', '--whisper', 'whisperx',
               '--detail', $Detalhe, '--resolution', $Resolucao, '--out-dir', $saida)
if ($Timestamps) { $argsWatch += @('--timestamps', $Timestamps) }
if ($Cookies) {
  $cookieAbs = [IO.Path]::GetFullPath($Cookies)
  if ($cookieAbs.StartsWith($raiz, [StringComparison]::OrdinalIgnoreCase)) {
    Write-Error 'Cookies dentro do repositorio sao proibidos. Guarde o arquivo fora do projeto.'; exit 2
  }
  $argsWatch += @('--cookies', $cookieAbs)
}

$env:WATCH_WHISPERX_LANGUAGE = $Idioma
$env:PYTHONIOENCODING = 'utf-8'
$relatorio = Join-Path $saida 'relatorio-watch.md'
# No PS 5.1 o stderr de executavel vira ErrorRecord; com 'Stop' isso abortaria o Watch no 1o aviso.
$ErrorActionPreference = 'Continue'
& py -3.13 @argsWatch 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $relatorio
exit $LASTEXITCODE
