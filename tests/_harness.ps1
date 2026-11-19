<#
.SYNOPSIS
    Harness da trilha PowerShell dos testes deste projeto.

.DESCRIPTION
    Carregado por dot-source pelo tests\run-tests.ps1. As suites nao carregam
    isto sozinhas.

    Este arquivo e a mesma infraestrutura que a plataforma Emmily AI Project OS
    usa nos proprios testes, entregue aos projetos governados. O que ele resolve
    e sempre o mesmo: um caso que quebra nao pode derrubar os outros, ler
    arquivo tem de respeitar UTF-8, e criterio de aceite tem de vir do
    project.yaml e nao de um numero cravado na assercao.

    Se este projeto usa Python, APAGUE esta trilha inteira (tests\_harness.ps1
    e tests\suites\) - o /os:new-project deveria ter apagado.

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

$script:passou = 0
$script:falhou = 0
$script:falhas = @()

function Test-Caso {
    <#
      Executa um caso. Excecao = falha; retornar $false tambem.
    #>
    param([string]$Nome, [scriptblock]$Bloco)
    try {
        $r = & $Bloco
        if ($r -eq $false) { throw "retornou falso" }
        Write-Host ("  [PASS] " + $Nome) -ForegroundColor Green
        $script:passou++
    } catch {
        Write-Host ("  [FAIL] " + $Nome) -ForegroundColor Red
        Write-Host ("         " + $_.Exception.Message) -ForegroundColor DarkRed
        $script:falhou++
        $script:falhas += $Nome
    }
}

function Assert-True {
    # Parametro [bool] NAO aceita string: use -not [string]::IsNullOrWhiteSpace($x),
    # nunca Assert-True ($minhaString).
    param([bool]$Condicao, [string]$Mensagem)
    if (-not $Condicao) { throw $Mensagem }
}

function Get-Texto {
    <#
      Le um arquivo como UTF-8, sempre.

      Get-Content -Raw SEM -Encoding assume a codepage ANSI no PowerShell 5.1:
      um acento vira dois caracteres e qualquer regex sobre ele falha em
      silencio. O BOM ja e consumido por ReadAllText - nao remende o sintoma.
    #>
    param([string]$Caminho)
    # UTF8Encoding($false, $true): o segundo argumento e throwOnInvalidBytes.
    #
    # [Text.Encoding]::UTF8 substitui byte invalido por U+FFFD EM SILENCIO, e o
    # gemeo Python levanta UnicodeDecodeError no mesmo arquivo. Nona assimetria
    # entre os dois, achada pelo qa-reviewer: um project.yaml salvo em ANSI
    # pelo Bloco de Notas - cenario que o proprio runbook desta plataforma
    # documenta como recorrente - fazia a trilha PowerShell seguir VERDE com o
    # criterio corrompido enquanto a Python errava duro. Mesma direcao das
    # outras: o lado PowerShell aceitava o que o Python recusava.
    #
    # O BOM continua sendo consumido: quem consome e o StreamReader por
    # deteccao de preambulo, nao a flag de emissao.
    $codificacao = New-Object System.Text.UTF8Encoding($false, $true)
    try {
        return [System.IO.File]::ReadAllText($Caminho, $codificacao)
    } catch [System.Text.DecoderFallbackException] {
        # A mensagem diz o que o caso PROVA - byte invalido solto - e nao
        # promete paridade geral. O security-reviewer mediu o limite: um
        # arquivo em UTF-16LE COM BOM e decodificado com sucesso aqui (o
        # StreamReader detecta o preambulo) e recusado pelo gemeo Python, que
        # le utf-8-sig. Essa divergencia existe e NAO esta provada por caso
        # nenhum - esta no backlog, nao na mensagem de erro.
        throw "'$Caminho' nao e UTF-8 valido (byte invalido solto). Salvo em ANSI/Windows-1252, tipicamente. O gemeo Python recusa este mesmo caso."
    }
}

function Write-Suite {
    param([string]$Nome)
    Write-Host ""
    Write-Host $Nome -ForegroundColor White
}

# Capturado no momento do dot-source. NAO usar $PSCommandPath dentro da
# funcao: numa funcao chamada depois, de outra suite, ele resolve para o
# arquivo de quem chamou, e a raiz sai errada sem erro nenhum.
$PastaDosTestes = $PSScriptRoot

function Get-RaizDoProjeto {
    return Split-Path -Parent $PastaDosTestes
}

function New-ValorNaoLegivel {
    # Valor que o manifesto declara e este leitor nao sabe ler. Ele e
    # REGISTRADO, nao ignorado: ignorar faria a chave parecer ausente, e
    # ausente parece "nao declarei" - que e outra coisa.
    param([string]$Motivo)
    return [pscustomobject]@{ NaoLegivel = $Motivo }
}

function Test-IndicadorDeBlocoYaml {
    <#
      '>' ou '|', opcionalmente com indicador de indentacao (1-9) e de
      chomping (+/-), em qualquer ordem: | |- |+ |2 |2- |-2 > >- >3 ...

      A versao anterior reconhecia so as SEIS formas sem digito, e o
      security-reviewer achou o furo: 'criterio_de_pronto: |2' caia no ramo de
      escalar comum, o valor virava a string '|2' - nao vazio, sem '{{', nao
      bloco - e o leitor DEVOLVIA. Pior: as linhas de prosa do bloco, que
      ninguem pulava, viravam chaves fabricadas no bloco pai. Os dois gemeos
      erravam igual, entao nao era divergencia: era defeito compartilhado.
    #>
    param([string]$Valor)
    return ($Valor -match '^[>|](?:[1-9][-+]?|[-+][1-9]?)?$')
}

function Get-ValorSemAspas {
    <#
      Remove UM par de aspas nas pontas, e so quando ha par.

      .Trim('"') remove TODAS as ocorrencias em cada ponta, sem exigir par:
      'roda no modo ''privado''' perdia a apostrofe final e o valor saia
      corrompido - enquanto o gemeo Python devolvia a frase inteira. Mesmo
      manifesto, valor diferente conforme a linguagem. Achado do qa-reviewer.
    #>
    param([string]$Valor)
    if ($Valor.Length -ge 2) {
        $a = $Valor[0]
        $b = $Valor[$Valor.Length - 1]
        if ($a -eq $b -and ($a -eq '"' -or $a -eq "'")) {
            return $Valor.Substring(1, $Valor.Length - 2)
        }
    }
    return $Valor
}

function New-BlocoDeManifesto {
    # Hashtable com comparacao ORDINAL. A @{} do PowerShell e
    # case-insensitive e o dict do Python nao: um manifesto com
    # 'Verificacao:' capitalizado era lido pela trilha PowerShell e falhava na
    # Python, e duas chaves que diferem so na caixa colapsavam em silencio
    # aqui. Achado do qa-reviewer.
    return New-Object 'System.Collections.Hashtable' ([System.StringComparer]::Ordinal)
}

function Read-ManifestoDoProjeto {
    <#
      Le o project.yaml inteiro numa estrutura aninhada, e devolve a raiz.

      GEMEO de ler_manifesto() em tests/conftest.py. Os dois tem de aceitar e
      recusar as MESMAS coisas, e devolver o MESMO valor: os revisores
      independentes acharam cinco divergencias entre eles ao longo da 2.4, e
      divergencia aqui significa projeto Python e projeto PowerShell com rigor
      diferente sobre o mesmo arquivo.

      Le a arvore e procura depois - a estrutura decide, nao a ordem de
      aparicao. Foi o que fechou os dois fail-open da 2.4: bloco irmao
      satisfazendo o caminho pedido, e chave que a regex nao reconhecia sendo
      descartada em silencio sem encerrar o bloco da mae.

      O que ele NAO le - e registra em vez de ignorar:
        - lista ('- item')
        - escalar de bloco ('>' e '|', com ou sem indicador)
      Pedir uma dessas chaves LANCA. Pedir OUTRA funciona, e isso importa: o
      project.yaml da propria plataforma tem lista em
      'ambiente.dependencias_externas', e o ADR-0010 manda preencher
      'classificacao.dados_sensiveis_excecoes' com entradas de lista.
    #>
    param([Parameter(Mandatory = $true)][string]$Caminho)

    if (-not (Test-Path $Caminho -PathType Leaf)) { throw "project.yaml nao encontrado em $Caminho" }

    $linhas = (Get-Texto $Caminho) -split "`r?`n"
    $raiz = New-BlocoDeManifesto
    $pilha = New-Object System.Collections.ArrayList
    [void]$pilha.Add([pscustomobject]@{ Indent = -1; Bloco = $raiz })

    $ultimoPai = $raiz
    $ultimaChave = $null
    # Indentacao do marcador '-' da lista corrente, ou da chave do escalar de
    # bloco corrente. -1 = nenhum em curso.
    $indentLista = -1
    $indentEscalar = -1

    for ($i = 0; $i -lt $linhas.Count; $i++) {
        $linha = $linhas[$i]
        $numero = $i + 1
        if (-not $linha.Trim()) { continue }
        if ($linha.Trim().StartsWith('#')) { continue }

        $indent = $linha.Length - $linha.TrimStart(' ').Length
        $conteudo = $linha.Trim()
        $ehItem = ($conteudo.StartsWith('- ') -or $conteudo -eq '-')

        # --- dentro de uma lista em curso ------------------------------------
        # Pula item irmao no MESMO indent e continuacao mais indentada. Chave
        # irma no indent do marcador ENCERRA a lista.
        #
        # A versao anterior pulava tudo com 'indent >= indentIgnoravel', e no
        # estilo compacto do YAML - que e a saida padrao do yaml.dump, e o
        # estilo que o ADR-0010 produz -
        #
        #     dados_sensiveis_excecoes:
        #     - caminho: "x"
        #     componente_llm: false
        #
        # o 'componente_llm' esta no MESMO indent do marcador e era pulado em
        # SILENCIO: o leitor lia meio manifesto sem dizer que leu meio.
        # Achado dos dois revisores.
        if ($indentLista -ge 0) {
            if ($ehItem -and $indent -eq $indentLista) { continue }
            if ($indent -gt $indentLista) { continue }
            $indentLista = -1
        }

        # --- dentro de um escalar de bloco em curso -------------------------
        if ($indentEscalar -ge 0) {
            if ($indent -gt $indentEscalar) { continue }
            $indentEscalar = -1
        }

        if ($ehItem) {
            if ($null -ne $ultimaChave) {
                $ultimoPai[$ultimaChave] = (New-ValorNaoLegivel 'lista')
                $indentLista = $indent
                # A lista pode ter aberto um bloco pelo lookahead da chave;
                # desempilhar para a chave nao ficar valendo bloco E lista.
                while ($pilha.Count -gt 1 -and $pilha[$pilha.Count - 1].Indent -ge $indent) {
                    $pilha.RemoveAt($pilha.Count - 1)
                }
            }
            continue
        }

        # Chave: tudo ate o PRIMEIRO ':'. Aceita hifen, ponto e aspas, porque
        # recusar em silencio foi um dos fail-open da 2.4.
        if ($conteudo -notmatch '^([^\s:#][^:]*):(.*)$') {
            throw ("project.yaml linha ${numero} nao e 'chave: valor' nem 'chave:' nem item de lista: " +
                   "'" + $conteudo + "'. Este leitor e estrito de proposito - o que ele nao entende, ele recusa.")
        }
        $chave = Get-ValorSemAspas ($matches[1].Trim())
        if (-not $chave) {
            throw "project.yaml linha ${numero}: chave vazia. Este leitor recusa; o gemeo Python tambem."
        }
        $bruto = $matches[2].Trim()

        while ($pilha.Count -gt 0 -and $indent -le $pilha[$pilha.Count - 1].Indent) {
            $pilha.RemoveAt($pilha.Count - 1)
        }
        if ($pilha.Count -eq 0) { throw "project.yaml linha ${numero}: indentacao inconsistente." }
        $pai = $pilha[$pilha.Count - 1].Bloco

        # Comentario no fim da linha. Qualquer espaco em branco antes do '#'
        # conta - inclusive TAB, que era a sexta divergencia entre os gemeos.
        #
        # MAS nao dentro de string entre aspas: 'criterio: "roda o passo #3"'
        # e string literal em YAML, e a versao anterior cortava no primeiro
        # espaco-'#' e devolvia 'roda o passo' com aspa orfa - verde sobre um
        # criterio de aceite TRUNCADO, no campo que esta subfase existe para
        # tornar fonte de verdade. Os dois gemeos erravam igual, entao o caso
        # de comparacao nao alcancava. Achado do qa-reviewer.
        if ($bruto.Length -ge 2 -and ($bruto[0] -eq '"' -or $bruto[0] -eq "'")) {
            $fecha = $bruto.IndexOf($bruto[0], 1)
            if ($fecha -gt 0) {
                $depois = $bruto.Substring($fecha + 1)
                # '\s+#', nao '\s#': o manifesto da plataforma alinha os
                # comentarios com VARIOS espacos - 'revisao_independente:
                # "qa+security"   # derivado...' tem tres. Com um so, o
                # comentario nao era cortado, o valor saia com o comentario
                # colado e as aspas deixavam de formar par. Pego pelo caso
                # que le o manifesto REAL, e nao por um sintetico.
                if ($depois -match '^\s+#') { $bruto = $bruto.Substring(0, $fecha + 1) }
            }
        } elseif ($bruto -match '^(.*?)\s#') {
            $bruto = $matches[1].Trim()
        }
        # Valor que e SO comentario e valor ausente. Em YAML,
        #     criterio_de_pronto:  # preencher depois
        # e null - mas os dois leitores devolviam a string
        # '# preencher depois' como se fosse o criterio de aceite. A remocao
        # de comentario exigia espaco ANTES do '#', e depois do Trim() o '#'
        # fica na posicao 0, entao nada casava. Direcao proibida: afirmava
        # criterio onde nao havia, no campo que esta subfase existe para
        # tornar fonte de verdade. Achado do qa-reviewer, e os dois gemeos
        # erravam igual - por isso o caso de comparacao nao podia alcancar.
        if ($bruto.StartsWith('#')) { $bruto = '' }

        # O indicador de bloco e testado no valor CRU, antes de tirar aspas:
        # 'algum: ">"' e a string '>', nao um escalar de bloco. O gemeo Python
        # tirava as aspas primeiro e divergia justamente aqui.
        if (Test-IndicadorDeBlocoYaml $bruto) {
            $pai[$chave] = (New-ValorNaoLegivel ("escalar de bloco ('" + $bruto + "')"))
            $indentEscalar = $indent
            $ultimoPai = $pai
            $ultimaChave = $chave
            continue
        }

        if ($bruto -eq '{}' -or $bruto -eq '[]') {
            $novo = New-BlocoDeManifesto
            $pai[$chave] = $novo
            [void]$pilha.Add([pscustomobject]@{ Indent = $indent; Bloco = $novo })
            $ultimoPai = $pai
            $ultimaChave = $chave
            continue
        }

        if ($bruto -eq '') {
            # 'chave:' sem valor abre bloco SO se a proxima linha significativa
            # for mais indentada. Caso contrario e campo declarado VAZIO - e
            # vazio nao e bloco. Mesma regra do gemeo Python.
            $prox = $null
            for ($j = $i + 1; $j -lt $linhas.Count; $j++) {
                if ($linhas[$j].Trim() -and -not $linhas[$j].Trim().StartsWith('#')) { $prox = $linhas[$j]; break }
            }
            if ($null -ne $prox -and (($prox.Length - $prox.TrimStart(' ').Length) -gt $indent)) {
                $novo = New-BlocoDeManifesto
                $pai[$chave] = $novo
                [void]$pilha.Add([pscustomobject]@{ Indent = $indent; Bloco = $novo })
            } else {
                $pai[$chave] = ''
            }
            $ultimoPai = $pai
            $ultimaChave = $chave
            continue
        }

        $pai[$chave] = (Get-ValorSemAspas $bruto)
        $ultimoPai = $pai
        $ultimaChave = $chave
    }

    return $raiz
}

function Get-CampoDoManifesto {
    <#
      Le um campo do project.yaml pelo caminho pontuado, e FALHA se nao achar.

      Get-CampoDoManifesto 'verificacao.limites.erro_maximo_m'

      Nao devolve valor padrao de proposito. Criterio de aceite que nao esta
      no manifesto nao e criterio, e um padrao silencioso transformaria "o
      projeto nao declarou" em "passou" - a violacao descrita em
      VERIFICATION-POLICY 4.5.

      Nao devolve bloco onde se esperava valor, nao devolve valor de bloco
      irmao, nao devolve o indicador de escalar de bloco como se fosse o
      valor, e nao devolve vazio para campo declarado vazio. Cada uma dessas
      quatro coisas ja foi um defeito real aqui.
    #>
    param([Parameter(Mandatory = $true)][string]$Caminho)

    $arq = Join-Path (Get-RaizDoProjeto) 'project.yaml'
    $raiz = Read-ManifestoDoProjeto $arq

    $partes = $Caminho -split '\.'
    $atual = $raiz
    $andado = @()
    foreach ($parte in $partes) {
        if ($atual -is [pscustomobject] -and $atual.PSObject.Properties.Name -contains 'NaoLegivel') {
            throw "project.yaml: um trecho de '$Caminho' e $($atual.NaoLegivel), que este leitor nao le."
        }
        if ($atual -isnot [System.Collections.Hashtable]) {
            throw "project.yaml: '$($andado -join '.')' nao e um bloco, entao '$Caminho' nao existe."
        }
        if (-not $atual.ContainsKey($parte)) {
            $andado += $parte
            throw "project.yaml nao declara '$Caminho' (parou em '$($andado -join '.')'). Declare o campo antes de assertar contra ele."
        }
        $andado += $parte
        $atual = $atual[$parte]
    }

    if ($atual -is [pscustomobject] -and $atual.PSObject.Properties.Name -contains 'NaoLegivel') {
        throw "project.yaml declara '$Caminho' como $($atual.NaoLegivel), que este leitor nao le. Escreva o valor numa linha so, entre aspas."
    }
    if ($atual -is [System.Collections.Hashtable]) {
        $vazio = ''
        if ($atual.Count -eq 0) { $vazio = ' vazio' }
        throw "project.yaml declara '$Caminho' como bloco$vazio, nao como valor."
    }
    $v = ("" + $atual)
    # IsNullOrWhiteSpace, nao '-not $v'. String de tres espacos e TRUTHY no
    # PowerShell, entao 'criterio_de_pronto: "   "' passava por criterio
    # declarado aqui e era RECUSADO pelo gemeo Python, que testa
    # atual.strip() == "". Oitava divergencia entre os dois, achada pelo
    # qa-reviewer - e fail-open justamente do lado que aceita.
    if ([string]::IsNullOrWhiteSpace($v)) {
        throw "project.yaml declara '$Caminho' VAZIO (ou so com espacos). Campo declarado e vazio nao e criterio declarado."
    }
    if ($v.StartsWith('{{')) {
        throw "project.yaml ainda tem placeholder em '$Caminho': a instanciacao nao terminou."
    }
    return $v
}

function Get-LimiteDoManifesto {
    <#
      Get-LimiteDoManifesto 'erro_maximo_m' -> [double], de verificacao.limites.
      Valor que nao converte para numero lanca: comparar string com numero
      produz erro longe da causa.
    #>
    param([Parameter(Mandatory = $true)][string]$Nome)
    $bruto = Get-CampoDoManifesto ("verificacao.limites." + $Nome)
    $n = 0.0
    # InvariantCulture, e isto NAO e detalhe. Esta maquina roda em pt-BR, onde
    # o separador decimal e a virgula: [double]::TryParse('1.0') pela cultura
    # atual le o ponto como separador de MILHAR e devolve 10. Uma tolerancia
    # de 1 metro declarada no manifesto passava a valer 10 metros, e o teste
    # continuava verde - ele so comparava contra o numero errado. Achado pelo
    # proprio teste desta subfase.
    $ok = [double]::TryParse(
        $bruto,
        [System.Globalization.NumberStyles]::Float,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref]$n)
    if (-not $ok) {
        throw "verificacao.limites.$Nome = '$bruto' nao e numero (use ponto decimal, formato invariante)."
    }
    return $n
}
