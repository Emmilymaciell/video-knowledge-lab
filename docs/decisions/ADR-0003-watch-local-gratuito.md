# ADR-0003 — Watch local e gratuito como ferramenta audiovisual

- **Data:** 2026-11-06
- **Status:** Aceita

## Contexto

O ADR-0002 deixou a ferramenta audiovisual para uma sessão própria. A escolhida é o plugin Watch (`bradautomates/claude-video`, v0.3.2, MIT). Ele tem dois engines: **gemini** (manda o vídeo para o Google) e **local** (frames com FFmpeg, legendas com yt-dlp, fala com WhisperX ou nuvem Groq/OpenAI). A Emmily exigiu: análise visual **e** de áudio, gratuita, local, sem API paga, sem Gemini e sem cookies sem autorização. A máquina é um Dell Latitude 3540 (i5-1235U, 16 GB, sem GPU dedicada), Windows 11.

O código do plugin foi lido antes de rodar: o runtime base usa só a biblioteca padrão do Python; o `setup.py`, no Windows, só **sugere** comandos `winget` para as ferramentas de mídia e instalaria o `uv` via `irm https://astral.sh/uv/install.ps1 | iex` se ele faltasse. O hook `SessionStart` só roda `setup.py --check` (silencioso, não usa rede).

## Decisão

1. **Instalação do plugin:** escopo de projeto (`.claude/settings.local.json` → `enabledPlugins`), não na plataforma.
2. **Engine local, sempre.** Config do Watch `WATCH_ENGINE=local` e, além disso, o wrapper `.claude/skills/analisar-video/scripts/watch-local.ps1` passa `--engine local` em toda execução. Gemini só com pedido explícito da Emmily, numa decisão nova.
3. **Fala: WhisperX local** (`--whisper whisperx` no wrapper; nunca Groq/OpenAI). Modelo `small`, CPU, `int8` — cabe com folga em 16 GB (~2,4 GB de pico) e roda um Reel curto em segundos. `large-v3` (~6 GB de RAM, bem mais lento) fica como opção por vídeo se o `small` falhar.
4. **Ordem das fontes de fala:** legenda nativa primeiro (comportamento do Watch); WhisperX só quando não há legenda.
5. **Frames:** detalhe `balanced` (cenas, até 100 frames), largura **1024 px** para ler texto e código na tela.
6. **Material bruto em `trabalho/<id>/`** via `--out-dir`, incluindo o relatório do Watch (`relatorio-watch.md`). Nada disso entra no Git.
7. **Cookies:** nunca por padrão. Só com `-Cookies <arquivo fora do repositório>` depois do "sim" da Emmily; o wrapper recusa arquivo dentro do projeto. Sem autorização, a alternativa é a Emmily baixar o MP4 e analisá-lo como arquivo local.
8. **Instalação das dependências por `winget`** (as recomendações oficiais do Watch para Windows), inclusive o `uv` (`astral-sh.uv`), para evitar o `irm | iex`.
9. **Python fixo `py -3.13`** para o Watch. O WhisperX usa seu próprio Python 3.12 isolado, gerenciado pelo `uv` em `~/.cache/watch/whisperx-venv`.
10. **Tema "Claude Code"** = `inteligencia-artificial/claude-code` (aprovado pela Emmily nesta sessão; ver `docs/CATEGORIAS.md`).

## Fica de fora

- Gemini, Groq e OpenAI — exigem nova decisão.
- Alinhamento de palavras e diarização do WhisperX: o Watch roda sem eles (`--no_align`). Ver "Consequências".
- OCR dedicado: o texto na tela é lido pelo próprio Claude a partir dos frames.

## Consequências

- **Custo zero por vídeo**, e áudio e vídeo nunca saem da máquina (exceto o download da própria plataforma).
- **Tempo da fala sem legenda é grosso:** sem alinhamento, o WhisperX devolve blocos de até ~30 s, não frases. Num vídeo curto pode vir **um só bloco** com tempo `00:00`. Os tempos finos da análise vêm dos frames e das legendas, quando existem. Validado em 2026-11-06.
- **WhisperX `small` erra** nomes próprios e trechos curtos (na validação: "Claude Code" → "CloudCode", "Olá! Esta é" → "ou AN? Esta AN Copyright"). A skill marca esses trechos como `[incerto: ...]`; a transcrição precisa ser conferida contra a tela.
- O suporte do Watch a Windows/Intel é declarado **não testado** pelo autor; aqui foi testado e funcionou (ver `docs/STATE.md`).
- Atualizações: `/plugin update watch@claude-video` e `winget upgrade --id yt-dlp.yt-dlp --exact` (o Watch só suporta o yt-dlp mais recente).
