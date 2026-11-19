# Sanitização desta versão pública

Cópia sanitizada de um projeto em uso real. Nada aqui é dado de cliente ou de terceiro: o que aparece como exemplo é inventado. Detalhe completo da sanitização: relatório interno da autora.

## O que foi removido

Análise de um vídeo de terceiro (criador, URL e legenda); arquivos de proveniência com remoto privado e caminho de nuvem.

## O que foi trocado

Remoto privado e caminhos de nuvem em STATE/HANDOFF/ADR → texto neutro. O teste do `.gitignore` cria um repositório Git temporário próprio.

## O que é fictício

`examples/synthetic/` (análise sintética `vkl-9999`).

## Como verificar

```bat
powershell -File tests\run-tests.ps1    :: 14 casos
```

Varreduras (2026-11-19): gitleaks `dir` só com falsos positivos justificados; busca por caminho local, e-mail, nomes do cliente e links privados sem ocorrências reais.
