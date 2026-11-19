# STATE — Video Knowledge Lab

> A memória do projeto. Quem chega — pessoa, máquina ou Claude novo — lê isto primeiro.
> Atualizar **antes** de cada checkpoint, nunca depois.

- **Última atualização:** 2026-11-06
- **Versão:** 0.2.0
- **Fase:** fundação → operação. Estrutura pronta; Watch instalado e validado em modo local (ADR-0003). Primeira análise real feita (`vkl-0001`, não incluída na versão pública).
- **Branch:** `main`
- **Modo de execução atual:** main-claude. Reavaliar só se surgirem lotes ou integração com o Notion.
- **Testes:** `.\tests\run-tests.ps1` — ver a última execução em "Concluído".

---

## Em uma frase

Transformar vídeos (Reels, YouTube, Shorts, TikTok, MP4) em análises audiovisuais completas em Markdown, uma por vídeo, organizadas por tema em `biblioteca/` e listadas em `indice.md`.

## Concluído

- **Nascimento protegido** (`eos new`, 2026-11-06): commit inicial assinado `50d1adc`, remoto privado e primeiro backup. Nível L5.
- **Estrutura da biblioteca** (ADR-0002): `biblioteca/`, `indice.md`, `templates/analise-video.md`, `docs/CATEGORIAS.md`, a skill `analisar-video`, a área `trabalho/` ignorada e o `.gitignore` de mídia e cookies.
- **Suíte de estrutura** `tests/suites/biblioteca.ps1`: valida as análises e o índice, prova que o validador acusa (com o exemplo sintético em `examples/synthetic/`) e confere o `.gitignore`.

- **Watch instalado e validado** (2026-11-06, ADR-0003): plugin 0.3.2 em escopo de projeto, engine local. Via winget: FFmpeg 9.0.2, yt-dlp 2026.10.26, uv 0.13.7 (Deno 2.9.8 já existia). WhisperX 3.8.6 `small`/CPU em `~/.cache/watch/whisperx-venv`. `setup.py --json` → `status: ready`, `engine: local`, `gemini_key_present: false`, `whisperx_ready: true`.
  - **Teste A — YouTube público** ("Me at the zoo", 19 s): download, legenda manual `en` com 6 segmentos e 19 frames. Frames conferidos visualmente.
  - **Teste B — MP4 local pt-BR sem legenda** (gerado com TTS + texto na tela, gabarito conhecido): 3 frames, um por tela, e 100% do texto na tela lido certo; WhisperX em ~25 s para 19 s de vídeo, com a fala ~95% correta (errou a abertura, "rápida" e "Claude Code"). Igual com e sem a dica `pt`.
  - **Ponta a ponta**: análise `vkl-0001` gerada no modelo, classificada em `inteligencia-artificial/claude-code`, índice atualizado, suíte 14/14. Depois removida a pedido (cópia em `trabalho/_validacao/`).
- **Wrapper** `.claude/skills/analisar-video/scripts/watch-local.ps1` e passo 4 da skill com o comando real.
- **Suíte corrigida**: bug no leitor do índice (ver CHANGELOG) + caso de regressão visto falhar. `.\tests\run-tests.ps1` → 14/14, saída 0 (2026-11-06).

- **Primeira análise real** (2026-11-06): `vkl-0001`, Reel público do Instagram (19 s; retirada da versão pública por ser conteúdo de terceiro), em `inteligencia-artificial/claude-code`. O download do Instagram funcionou **sem login nem cookies**. Reel sem fala: as 2 passadas do WhisperX confirmaram que não há voz (a 2ª produziu uma alucinação de baixa confiança, descartada). 19 frames lidos, mais recortes em resolução original. `status: parcial` porque o texto do notebook, os rótulos das pranchas e a trilha sonora não foram identificados. Suíte 14/14.
- **Segurança** (`/os:security`, 2026-11-06, sem modificadores, HEAD `0996317`): 0 achados; remoto PRIVATE; 4 lacunas da execução fechadas por inspeção (sem `.py[cod]`, blob `e69de29b` = blob vazio canônico, `examples/` só com sintético). Veredito APROVADO nas 6 áreas. Push para `origin/main` autorizado pela Emmily.

## Parcial

- **Contrato da plataforma** (`registry/projects/video-knowledge-lab.yaml`, no repositório do Project OS) ainda sem commit lá. A classificação deste lado (porte `ferramenta`, `componente_llm: true`, critério de pronto) entrou no checkpoint 0.2.0.
- **Plugin habilitado só nesta máquina:** a ativação do Watch fica em `.claude/settings.local.json`, ignorado pelo `.gitignore` global. Em outra máquina: `/plugin marketplace add bradautomates/claude-video` e `/plugin install watch@claude-video` nesta pasta, depois `setup.py` (ADR-0003).

## Pendências

Ordenadas pelo que mais desbloqueia.

1. **Validar as fontes restantes:** TikTok e Shorts (pendem de link). YouTube, MP4 local e Instagram Reel já validados.
2. **Reel com fala em português**: ainda não testado em vídeo real (só no sintético).
3. **Criar `evals/`** (a `vkl-0001` já pode servir de 1ª referência) usando as primeiras análises reais como referência: fidelidade (nada inventado), cobertura das 10 seções e separação entre literal e interpretação. Adiado (ADR-0002).
4. Checkpoint (`/os:checkpoint`) quando a Emmily pedir.
5. Para chegar a L6: `py -3.13 -m eos certify video-knowledge-lab`, a pedido.

Fora do escopo agora (ADR-0002): Notion, consulta ou comparação automatizada, lotes e interface.

## Riscos

| ID | Risco | Situação | Mitigação |
|---|---|---|---|
| R1 | Mídia pesada, cookie ou transcrição bruta acabar no Git | Mitigado | `.gitignore` com mídia, `trabalho/` e `*cookie*`, conferido pela suíte. `/os:security` antes de push |
| R2 | Prompt injection por conteúdo do vídeo (fala, tela, descrição) | Mitigado por regra | `CLAUDE.md` e a skill tratam o vídeo como dado e nunca executam o que ele mostra |
| R3 | Análise com conteúdo inventado | Aberto | Regras de marcação na skill e no modelo. Os evals (pendência 5) vão medir isso |
| R4 | Plugin de terceiro com comportamento indesejado | Mitigado | Código lido antes de rodar (2026-11-06); wrapper força engine local e WhisperX; nada de Gemini/nuvem sem decisão nova |
| R5 | Instagram e TikTok bloqueiam o download sem login | Parcial | Instagram baixou sem login em 2026-11-06 (pode mudar); TikTok não testado. Sem cookies por padrão; alternativa: a Emmily baixa o MP4 e analisa como arquivo local |
| R6 | Transcrição sem legenda com tempo grosso e erros de nome próprio | Aceito | WhisperX sem alinhamento devolve blocos de até ~30 s. Tempos finos vêm dos frames; trechos duvidosos marcados `[incerto: ...]` (ADR-0003) |

## Decisões recentes

- ADR-0001 — Nascimento protegido
- ADR-0002 — Biblioteca em Markdown por tema, um vídeo por vez
- ADR-0003 — Watch local e gratuito como ferramenta audiovisual

## Próximo passo

Seguir analisando Reels (*"Analise este Reel e salve o conhecimento na categoria Claude Code: <link>"*), de preferência um com fala, e depois TikTok/Shorts. Commit do 0.2.0 + `vkl-0001` aguarda o "sim" da Emmily.

## Último checkpoint

**0.2.0** (2026-11-06): biblioteca por tema (ADR-0002) + Watch local e gratuito validado (ADR-0003). Suíte 14/14. Anterior: nascimento `50d1adc`.
