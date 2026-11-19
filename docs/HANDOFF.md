# HANDOFF — Video Knowledge Lab

> Para outra pessoa, máquina ou conta assumir o projeto **sem acesso a nenhuma conversa**.

- **Projeto:** `video-knowledge-lab` (PERSONAL), nascido em 2026-11-06 por `py -3.13 -m eos new`.
- **Contrato canônico:** `registry/projects/video-knowledge-lab.yaml` no Emmily AI Project OS.
- **Local:** `${AI_WORKSPACE}\personal\video-knowledge-lab` (resolva com `py -3.13 -m eos resolve`).
- **Dado bruto:** armazenamento em nuvem pessoal — nunca no Git (ADR-0015 da plataforma).

## Como retomar

1. Ler `docs/STATE.md` (onde parou) e `docs/decisions/` (o que já foi decidido).
2. Rodar `.\bootstrap.ps1` para preparar a máquina.
3. Rodar `.\tests\run-tests.ps1` e conferir `exit 0`.
4. **Ferramenta audiovisual (fora do Git, refazer em cada máquina — ADR-0003):**
   - `winget install --id Gyan.FFmpeg --exact`, `yt-dlp.yt-dlp`, `DenoLand.Deno`, `astral-sh.uv` (mesmo formato) e reabrir o terminal.
   - No Claude Code, **nesta pasta**: `/plugin marketplace add bradautomates/claude-video` e `/plugin install watch@claude-video` (a ativação fica em `.claude/settings.local.json`, ignorado).
   - Setup local e gratuito: `py -3.13 "<plugin>\skills\watch\scripts\setup.py" --engine local --backend whisperx --detail balanced` (~1,5 GB; o plugin fica em `~\.claude\plugins\cache\claude-video\watch\<versão>`). Conferir com `setup.py --json` → `status: ready`, `engine: local`, `whisperx_ready: true`.
5. Analisar: *"Analise este Reel e salve o conhecimento na categoria Claude Code: <link>"* (skill `analisar-video`).

## Recuperar em outra máquina

Na plataforma: `py -3.13 -m eos restore video-knowledge-lab --para <diretório vazio>`.
