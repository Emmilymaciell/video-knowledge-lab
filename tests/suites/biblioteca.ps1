<#
    Validacao de estrutura da biblioteca (ADR-0002).

    O produto deste projeto e documento, entao a verificacao e de estrutura do
    artefato (VERIFICATION-POLICY secao 2): cada analise tem frontmatter valido,
    as 10 secoes obrigatorias, tema coerente com a pasta, ID e URL unicos, e o
    indice.md bate com os arquivos nos dois sentidos.

    O validador prova que acusa (politica 4.1): roda contra o exemplo sintetico
    valido (deve ficar quieto) e contra versoes quebradas dele (deve acusar).

    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
    Os titulos das secoes sao comparados sem acento (Remove-Acento).
#>

if (-not (Get-Command Test-Caso -ErrorAction SilentlyContinue)) {
    throw "Rode pelo tests\run-tests.ps1 - esta suite nao carrega o harness sozinha."
}

$Raiz       = Get-RaizDoProjeto
$DirBib     = Join-Path $Raiz 'biblioteca'
$Indice     = Join-Path $Raiz 'indice.md'
$Modelo     = Join-Path $Raiz 'templates\analise-video.md'
$Sintetico  = Join-Path $Raiz 'examples\synthetic\vkl-9999-exemplo-sintetico.md'

$script:SecoesObrigatorias = @(
    'Identificacao', 'Resumo', 'Analise completa', 'Transcricao', 'Evidencias visuais',
    'Conhecimentos extraidos', 'Procedimentos demonstrados', 'Possiveis aplicacoes',
    'Limitacoes e incertezas', 'Referencias'
)
$script:CamposObrigatorios = @(
    'id', 'titulo', 'fonte', 'url', 'criador', 'publicado_em', 'analisado_em', 'tema',
    'temas_relacionados', 'tags', 'duracao', 'idioma',
    'cobertura_audio', 'cobertura_visual', 'cobertura_legendas', 'status'
)

function Remove-Acento([string]$s) {
    $d = $s.Normalize([Text.NormalizationForm]::FormD)
    return ($d -replace '\p{Mn}', '').Normalize([Text.NormalizationForm]::FormC)
}

function Get-Frontmatter([string]$Texto) {
    # Devolve hashtable campo -> valor, ou $null se nao houver frontmatter.
    $t = $Texto -replace "`r", ''
    if (-not $t.StartsWith("---`n")) { return $null }
    $fim = $t.IndexOf("`n---`n", 4)
    if ($fim -lt 0) { return $null }
    $h = @{}
    foreach ($linha in ($t.Substring(4, $fim - 4) -split "`n")) {
        if ($linha -match '^([a-z_]+):(.*)$') {
            $v = $Matches[2] -replace '\s{2,}#.*$', ''
            $v = $v.Trim()
            if ($v.Length -ge 2 -and $v.StartsWith('"') -and $v.EndsWith('"')) { $v = $v.Substring(1, $v.Length - 2) }
            $h[$Matches[1]] = $v
        }
    }
    return $h
}

function Get-Secoes([string]$Texto) {
    return @(($Texto -replace "`r", '') -split "`n" |
             Where-Object { $_ -match '^## ' } |
             ForEach-Object { Remove-Acento ($_.Substring(3).Trim()) })
}

function Get-ProblemasAnalise([string]$Texto, [string]$RelPath) {
    # RelPath: caminho relativo a biblioteca/, com '/' (ex.: saude/vkl-0001-x.md)
    $p = @()
    $fm = Get-Frontmatter $Texto
    if ($null -eq $fm) { return @('sem frontmatter (--- ... ---) no inicio') }

    foreach ($c in $script:CamposObrigatorios) {
        if (-not $fm.ContainsKey($c)) { $p += "campo ausente no frontmatter: $c" }
    }
    if ($fm['id'] -notmatch '^vkl-\d{4}$')                 { $p += "id invalido: '$($fm['id'])' (esperado vkl-NNNN)" }
    if ([string]::IsNullOrWhiteSpace($fm['titulo']))       { $p += 'titulo vazio' }
    if ($fm['fonte'] -notin @('instagram','youtube','youtube-shorts','tiktok','arquivo-local','outro')) { $p += "fonte invalida: '$($fm['fonte'])'" }
    if ([string]::IsNullOrWhiteSpace($fm['url']))          { $p += 'url vazia' }
    if ($fm['analisado_em'] -notmatch '^\d{4}-\d{2}-\d{2}$') { $p += "analisado_em invalido: '$($fm['analisado_em'])'" }
    if ($fm['status'] -notin @('completo','parcial'))      { $p += "status invalido: '$($fm['status'])'" }
    foreach ($c in 'cobertura_audio','cobertura_visual') {
        if ($fm[$c] -notin @('completa','parcial','indisponivel')) { $p += "$c invalido: '$($fm[$c])'" }
    }
    if ($fm['cobertura_legendas'] -notin @('existentes','geradas','indisponivel')) { $p += "cobertura_legendas invalido: '$($fm['cobertura_legendas'])'" }

    # tema = pasta, no maximo 2 niveis, kebab-case
    $partes = $RelPath -split '/'
    $pasta  = ($partes[0..($partes.Count - 2)]) -join '/'
    $nome   = $partes[-1]
    if ($partes.Count -lt 2)  { $p += 'arquivo fora de pasta de tema (direto em biblioteca/)' }
    if ($partes.Count -gt 3)  { $p += "mais de 2 niveis de tema: $pasta" }
    if ($fm['tema'] -ne $pasta) { $p += "tema '$($fm['tema'])' nao bate com a pasta '$pasta'" }
    foreach ($seg in ($pasta -split '/')) {
        if ($seg -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { $p += "pasta de tema fora de kebab-case: '$seg'" }
    }
    if ($nome -notmatch '^vkl-\d{4}-[a-z0-9]+(-[a-z0-9]+)*\.md$') { $p += "nome de arquivo fora do padrao vkl-NNNN-slug.md: $nome" }
    elseif (-not $nome.StartsWith($fm['id'] + '-'))                { $p += "nome do arquivo nao comeca pelo id $($fm['id'])" }

    $secoes = Get-Secoes $Texto
    foreach ($s in $script:SecoesObrigatorias) {
        if ($secoes -notcontains $s) { $p += "secao obrigatoria ausente: ## $s" }
    }
    if ($Texto -match 'vkl-NNNN|AAAA-MM-DD') { $p += 'sobrou marcador do modelo (vkl-NNNN ou AAAA-MM-DD)' }
    return $p
}

function Get-ArquivosBiblioteca {
    if (-not (Test-Path $DirBib -PathType Container)) { return @() }
    return @(Get-ChildItem $DirBib -Recurse -File -Filter '*.md')
}

function Get-RelBib($Arquivo) {
    return $Arquivo.FullName.Substring($DirBib.Length + 1).Replace('\', '/')
}

function Get-LinhasIndice {
    # Linhas da tabela de conteudos: | vkl-NNNN | ... | [..](biblioteca/...) |
    param([string]$Texto = (Get-Texto $Indice))
    $out = @()
    foreach ($l in ($Texto -replace "`r", '') -split "`n") {
        if ($l -match '^\|\s*(vkl-\d{4})\s*\|') {
            # Guardar o ID ANTES do segundo -match: ele sobrescreve $Matches.
            # Sem isto o Id virava o caminho do link e toda analise real
            # aparecia como "fora do indice" (achado na 1a analise, 2026-11-06).
            $id = $Matches[1]
            $link = ''
            if ($l -match '\]\(([^)]+)\)\s*\|\s*$') { $link = $Matches[1] }
            $out += [pscustomobject]@{ Id = $id; Link = $link }
        }
    }
    return $out
}

# --- O modelo -----------------------------------------------------------------

Test-Caso "modelo: templates\analise-video.md tem todos os campos e as 10 secoes" {
    $t = Get-Texto $Modelo
    $fm = Get-Frontmatter $t
    Assert-True ($null -ne $fm) "modelo sem frontmatter"
    $faltam = @($script:CamposObrigatorios | Where-Object { -not $fm.ContainsKey($_) })
    Assert-True ($faltam.Count -eq 0) ("campos ausentes no modelo: " + ($faltam -join ', '))
    $secoes = Get-Secoes $t
    $faltamS = @($script:SecoesObrigatorias | Where-Object { $secoes -notcontains $_ })
    Assert-True ($faltamS.Count -eq 0) ("secoes ausentes no modelo: " + ($faltamS -join ', '))
}

# --- O validador prova que acusa (politica 4.1) --------------------------------

Test-Caso "validador: exemplo sintetico valido NAO gera problema" {
    $prob = @(Get-ProblemasAnalise (Get-Texto $Sintetico) 'exemplo/vkl-9999-exemplo-sintetico.md')
    Assert-True ($prob.Count -eq 0) ("falso positivo: " + ($prob -join ' | '))
}

Test-Caso "validador: ACUSA secao ausente, id invalido, tema fora da pasta e marcador do modelo" {
    $ok = Get-Texto $Sintetico
    $casos = @(
        @{ Txt = ($ok -replace '(?m)^## Refer\S+ncias', '## Fontes');      Rel = 'exemplo/vkl-9999-exemplo-sintetico.md'; Nome = 'secao ausente' },
        @{ Txt = ($ok -replace 'id: vkl-9999', 'id: video-1');             Rel = 'exemplo/vkl-9999-exemplo-sintetico.md'; Nome = 'id invalido' },
        @{ Txt = $ok;                                                      Rel = 'saude/vkl-9999-exemplo-sintetico.md';   Nome = 'tema != pasta' },
        @{ Txt = $ok;                                                      Rel = 'a/b/c/vkl-9999-exemplo-sintetico.md';   Nome = '3 niveis' },
        @{ Txt = ($ok -replace 'analisado_em: \S+', 'analisado_em: AAAA-MM-DD'); Rel = 'exemplo/vkl-9999-exemplo-sintetico.md'; Nome = 'marcador do modelo' },
        @{ Txt = ($ok -replace '(?s)^---.*?\n---\n', '');                  Rel = 'exemplo/vkl-9999-exemplo-sintetico.md'; Nome = 'sem frontmatter' }
    )
    foreach ($c in $casos) {
        $prob = @(Get-ProblemasAnalise $c.Txt $c.Rel)
        Assert-True ($prob.Count -gt 0) ("o validador NAO acusou: " + $c.Nome)
    }
}

# --- A biblioteca real --------------------------------------------------------

Test-Caso "biblioteca: toda analise passa no validador" {
    $erros = @()
    foreach ($a in Get-ArquivosBiblioteca) {
        $rel = Get-RelBib $a
        foreach ($pr in @(Get-ProblemasAnalise (Get-Texto $a.FullName) $rel)) { $erros += "$rel -> $pr" }
    }
    Assert-True ($erros.Count -eq 0) ($erros -join "`n         ")
}

Test-Caso "biblioteca: IDs e URLs sao unicos" {
    $ids = @{}; $urls = @{}; $dup = @()
    foreach ($a in Get-ArquivosBiblioteca) {
        $fm = Get-Frontmatter (Get-Texto $a.FullName)
        if ($null -eq $fm) { continue }
        if ($ids.ContainsKey($fm['id'])) { $dup += "id $($fm['id'])" } else { $ids[$fm['id']] = 1 }
        if ($fm['url']) { if ($urls.ContainsKey($fm['url'])) { $dup += "url $($fm['url'])" } else { $urls[$fm['url']] = 1 } }
    }
    Assert-True ($dup.Count -eq 0) ("duplicados: " + ($dup -join ', '))
}

Test-Caso "validador: leitor do indice extrai ID e link de uma linha real (regressao do `$Matches sobrescrito)" {
    $linha = '| vkl-0042 | Titulo | saude | - | youtube | canal | 2026-01-01 | [vkl-0042](biblioteca/saude/vkl-0042-x.md) |'
    $l = @(Get-LinhasIndice ("cabecalho`n" + $linha))
    Assert-True ($l.Count -eq 1) "esperava 1 linha, veio $($l.Count)"
    Assert-True ($l[0].Id -eq 'vkl-0042') "Id lido errado: '$($l[0].Id)'"
    Assert-True ($l[0].Link -eq 'biblioteca/saude/vkl-0042-x.md') "Link lido errado: '$($l[0].Link)'"
}

Test-Caso "indice: cada analise esta no indice.md, e cada linha do indice aponta para arquivo que existe" {
    $linhas = @(Get-LinhasIndice)
    $noIndice = @{}; foreach ($l in $linhas) { $noIndice[$l.Id] = $l.Link }
    $erros = @()
    foreach ($a in Get-ArquivosBiblioteca) {
        $fm = Get-Frontmatter (Get-Texto $a.FullName)
        if ($null -ne $fm -and -not $noIndice.ContainsKey($fm['id'])) { $erros += "fora do indice: $(Get-RelBib $a)" }
    }
    foreach ($l in $linhas) {
        if (-not $l.Link) { $erros += "linha $($l.Id) sem link para o arquivo"; continue }
        if (-not (Test-Path (Join-Path $Raiz $l.Link) -PathType Leaf)) { $erros += "linha $($l.Id) aponta para arquivo inexistente: $($l.Link)" }
    }
    Assert-True ($erros.Count -eq 0) ($erros -join "`n         ")
}

# --- Guarda-corpo do Git -------------------------------------------------------

Test-Caso "gitignore: midia, frames, area de trabalho e cookies NAO entram; analise entra" {
    # Repositorio Git proprio em Temp com o .gitignore do projeto: o teste nao depende de a
    # pasta do projeto ser um repositorio (a copia publica pode nao ser).
    $repo = Join-Path ([IO.Path]::GetTempPath()) ("vkl-gitignore-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $repo | Out-Null
    git init -q -- $repo 2>$null | Out-Null
    Copy-Item -LiteralPath (Join-Path $Raiz '.gitignore') -Destination (Join-Path $repo '.gitignore')
    Push-Location $repo
    try {
        foreach ($f in 'trabalho/vkl-0001/video.mp4', 'trabalho/vkl-0001/transcricao-bruta.txt', 'video.mp4', 'audio.m4a',
                       'reel.webm', 'frame-001.jpg', 'cookies.txt', 'www.instagram.com_cookies.txt', '.env') {
            git check-ignore -q -- $f
            Assert-True ($LASTEXITCODE -eq 0) "NAO ignorado (deveria): $f"
        }
        foreach ($f in 'biblioteca/saude/vkl-0001-exemplo.md', 'indice.md', 'templates/analise-video.md') {
            git check-ignore -q -- $f
            Assert-True ($LASTEXITCODE -ne 0) "ignorado (nao deveria): $f"
        }
    } finally { Pop-Location; Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
}
