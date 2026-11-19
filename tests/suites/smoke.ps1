<#
    Testes de fumaca da trilha PowerShell: o projeto declara a verdade sobre
    si mesmo?

    Este e o teste que a politica de verificacao exige que exista desde o
    primeiro dia (VERIFICATION-POLICY 4.4: pasta de verificacao vazia nao
    conta). Ele nao testa o programa - testa o CONTRATO do projeto, que e a
    unica coisa que ja existe quando o projeto acabou de nascer.

    Rode com: .\tests\run-tests.ps1

    Se este projeto usa Python, APAGUE tests\_harness.ps1 e tests\suites\.

    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

if (-not (Get-Command Test-Caso -ErrorAction SilentlyContinue)) {
    throw "Rode pelo tests\run-tests.ps1 - esta suite nao carrega o harness sozinha."
}

$Raiz = Get-RaizDoProjeto

Test-Caso "manifesto: o project.yaml e legivel e o projeto se identifica" {
    $nome = Get-CampoDoManifesto 'identidade.nome'
    Assert-True (-not [string]::IsNullOrWhiteSpace($nome)) `
        "project.yaml sem identidade.nome. /os:status e /os:handoff leem daqui."
}

Test-Caso "manifesto: nao sobrou placeholder da instanciacao" {
    $txt = Get-Texto (Join-Path $Raiz 'project.yaml')
    Assert-True ($txt -notmatch '\{\{') `
        "project.yaml ainda tem placeholder. Nao filtre por extensao ao substituir."
}

Test-Caso "manifesto: o comando de teste declarado aponta para arquivo que existe" {
    $cmd = Get-CampoDoManifesto 'verificacao.comando'
    $alvo = ($cmd -split '\s+')[0].TrimStart([char]'.', [char]'\', [char]'/')
    Assert-True (Test-Path (Join-Path $Raiz $alvo) -PathType Leaf) `
        "verificacao.comando aponta para '$alvo', que nao existe. Comando que aponta para nada e pior que comando ausente."
}

Test-Caso "manifesto: campo inexistente LANCA, em vez de devolver vazio" {
    # O par negativo do leitor. Sem este caso, um leitor que devolvesse $null
    # em silencio passaria por todos os outros - e criterio ausente viraria
    # criterio atendido (VERIFICATION-POLICY 4.5).
    $lancou = $false
    try { Get-CampoDoManifesto 'verificacao.campo_que_nao_existe' } catch { $lancou = $true }
    Assert-True $lancou "campo ausente devolveu valor em vez de lancar"
}

Test-Caso "trilha: este projeto tem UMA trilha de teste, nao duas" {
    $py = @(Get-ChildItem (Join-Path $Raiz 'tests') -Filter 'test_*.py' -File -ErrorAction SilentlyContinue)
    Assert-True ($py.Count -eq 0) `
        "existem tests\test_*.py e tests\suites\*.ps1 ao mesmo tempo. Apague a trilha que este projeto nao usa."
}

Test-Caso "politica 4.4: codigo em scripts\ sem suite propria REPROVA" {
    $dirScripts = Join-Path $Raiz 'scripts'
    $codigo = @()
    if (Test-Path $dirScripts -PathType Container) {
        $codigo = @(Get-ChildItem $dirScripts -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Extension -in @('.py', '.ps1', '.psm1', '.js', '.ts', '.sql', '.r') })
    }
    if ($codigo.Count -eq 0) { return }   # projeto novo: nada a exigir ainda

    $suites = @(Get-ChildItem (Join-Path $Raiz 'tests\suites') -Filter '*.ps1' -File -ErrorAction SilentlyContinue |
                Where-Object { $_.BaseName -ne 'smoke' })
    Assert-True ($suites.Count -gt 0) `
        ("existe codigo em scripts\ (" + (($codigo | Select-Object -First 5 | ForEach-Object { $_.Name }) -join ', ') + ") e nenhuma suite alem da de fumaca. VERIFICATION-POLICY 4.4.")
}
