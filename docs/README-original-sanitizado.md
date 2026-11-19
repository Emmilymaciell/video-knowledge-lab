# Video Knowledge Lab

Biblioteca pessoal de conhecimento extraído de conteúdos audiovisuais (Reels, YouTube, Shorts, TikTok, MP4), analisados **um vídeo por vez** e salvos em Markdown, organizados por tema.

## O problema

Muita coisa útil aparece em vídeos curtos e se perde. Aqui, cada vídeo vira uma análise audiovisual completa (fala, imagem e texto na tela), autossuficiente e pesquisável, para não ser preciso assistir de novo.

**Pronto quando:** cada vídeo analisado gera um único `.md`, no modelo, na pasta do seu tema, listado em `indice.md`, e a suíte de estrutura passa. A fonte de verdade é `project.yaml` → `verificacao.criterio_de_pronto`.

## Como usar

Abra o Claude Code nesta pasta e envie um link ou arquivo:

```
Hoje quero analisar alguns Reels sobre Claude Code.
<link>
```

ou então: `Analisa isso e salva na categoria que achar melhor: <link>`. O fluxo está em [.claude/skills/analisar-video/SKILL.md](.claude/skills/analisar-video/SKILL.md) e as regras de tema em [docs/CATEGORIAS.md](docs/CATEGORIAS.md).

> Ferramenta audiovisual: plugin Watch em modo local e gratuito (frames + legendas + WhisperX em CPU), ver [ADR-0003](docs/decisions/ADR-0003-watch-local-gratuito.md). Para analisar: abra o Claude Code nesta pasta e diga *"Analise este Reel e salve o conhecimento na categoria Claude Code: <link>"*.

## Como rodar os testes

```powershell
.\bootstrap.ps1
.\tests\run-tests.ps1
```

Saída `0` passou, `1` falhou, `2` **a suíte não rodou**. Ver [tests/README.md](tests/README.md).

## Estrutura

```
video-knowledge-lab/
├── biblioteca/                 análises: <tema>/[<subtema>/]vkl-NNNN-<slug>.md
├── indice.md                   índice único (tema, título, fonte, arquivo)
├── templates/analise-video.md  modelo de toda análise
├── trabalho/                   material bruto local — NUNCA vai para o Git
├── .claude/skills/analisar-video/
├── examples/synthetic/         análise inventada, usada pelos testes
├── docs/
│   ├── STATE.md                onde o projeto está  ← leia primeiro
│   ├── CATEGORIAS.md           regras de organização
│   └── decisions/              ADRs
├── tests/                      .\tests\run-tests.ps1
├── CLAUDE.md · AGENTS.md       instruções para agentes
└── project.yaml                cartão de identidade
```

## Assumir este projeto

Leia `docs/STATE.md`, `docs/decisions/` e este README. Nada essencial depende de histórico de conversa.
