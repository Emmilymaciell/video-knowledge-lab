# CHANGELOG — Video Knowledge Lab

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).
Semantic Versioning (`MAJOR.MINOR.PATCH`). Tag só depois de validação ponta a ponta.

<!--
  Atualizado por /os:checkpoint, antes do commit — nunca depois.

  Uma entrada por versão, agrupada em: Adicionado · Alterado · Corrigido ·
  Removido · Segurança.

  Registre também o que foi TENTADO E REVERTIDO. É a informação que se perde
  primeiro, e a que mais economiza tempo de quem vier depois — inclusive você
  em três meses.

  Em "Corrigido", diga COMO o bug foi descoberto, não só o que era. Se um
  teste passava e o bug existia, isso é informação sobre a suíte.
-->

## [Não lançado]

## [0.2.0] — 2026-11-06

### Adicionado

- Estrutura inicial do projeto, criada por `/os:new-project`.
- Biblioteca temática (ADR-0002): `biblioteca/`, `indice.md`, `templates/analise-video.md`, `docs/CATEGORIAS.md` e a skill `analisar-video`.
- Suíte `tests/suites/biblioteca.ps1`, que valida as análises e o índice e confere o `.gitignore`.
- Plugin Watch 0.3.2 em modo local e gratuito (ADR-0003): FFmpeg 9.0.2, yt-dlp 2026.10.26, Deno 2.9.8, uv 0.13.7 (winget) e WhisperX 3.8.6 `small` em CPU.
- Wrapper `.claude/skills/analisar-video/scripts/watch-local.ps1`: força `--engine local` e `--whisper whisperx`, frames a 1024 px, saída em `trabalho/<id>/`, recusa cookies dentro do repositório.
- Passo 4 da skill `analisar-video` com o comando real; mapeamento "Claude Code" → `inteligencia-artificial/claude-code` em `docs/CATEGORIAS.md`.
- Caso de regressão na suíte para o leitor do índice.
- Primeira análise real: `vkl-0001` (Instagram Reel, `inteligencia-artificial/claude-code`).

### Corrigido

- **Leitor do índice da suíte** (`Get-LinhasIndice`): o segundo `-match` sobrescrevia `$Matches`, e o ID lido virava o caminho do link. Toda análise real aparecia como "fora do índice". Descoberto na primeira análise ponta a ponta (2026-11-06): a suíte passava porque o índice estava vazio — nunca tinha exercitado esse caminho. O novo caso foi visto falhar com o bug reintroduzido.
- Wrapper: no PowerShell 5.1, o stderr do Watch virava erro terminante com `ErrorActionPreference=Stop` e abortava a execução no primeiro aviso.

### Tentado e revertido

- Análise de teste `vkl-0001` (vídeo sintético pt-BR) gerada, validada pela suíte e removida a pedido da Emmily, para deixar o `vkl-0001` ao primeiro Reel real. Cópia em `trabalho/_validacao/` (fora do Git).

### Segurança

- `.gitignore` bloqueia mídia, legendas baixadas, frames e a área `trabalho/`. Cookies já eram bloqueados.
