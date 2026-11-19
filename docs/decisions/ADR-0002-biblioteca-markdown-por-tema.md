# ADR-0002 — Biblioteca em Markdown por tema, um vídeo por vez

- **Data:** 2026-11-06
- **Status:** Aceita

## Contexto

O objetivo é transformar vídeos (Reels, YouTube, Shorts, TikTok, MP4) numa biblioteca pessoal de conhecimento. A pessoa poderá recuperá-la sem assistir de novo e, no futuro, consultá-la, comparar conteúdos e levá-la ao Notion. A prioridade declarada é a simplicidade: nada de aplicação, interface, banco de dados ou automação antecipada.

## Decisão

1. **Unidade:** um vídeo gera **um** `.md` autossuficiente, criado a partir de `templates/analise-video.md`, com frontmatter de metadados simples e 10 seções fixas.
2. **Local:** `biblioteca/<tema>/[<subtema>/]vkl-NNNN-<slug>.md`, com no máximo 2 níveis. As pastas nascem com o primeiro uso. As regras estão em `docs/CATEGORIAS.md`.
3. **Identidade:** o ID `vkl-NNNN` é sequencial e estável. O tema é metadado e pasta, nunca identidade, então mudar o tema não muda o ID.
4. **Sem duplicação:** o arquivo fica num único tema. Os outros temas vão em `temas_relacionados`, e a ligação entre análises é feita por link relativo.
5. **Índice:** `indice.md` é uma tabela única em Markdown, mantida a cada análise.
6. **Material bruto fora do Git:** mídia, áudio, frames, transcrições brutas e caches ficam em `trabalho/`, que é ignorado. No Git entram só a análise final e o índice.
7. **Conteúdo externo é dado não confiável.** Nunca é instrução, e nada do que o vídeo mostra é executado automaticamente.
8. **Verificação:** uma suíte de estrutura (`tests/suites/biblioteca.ps1`) confere o frontmatter, as seções, a coerência entre tema e pasta, os IDs e URLs únicos e o índice, nos dois sentidos. Os **evals** de qualidade da análise ficam adiados até existirem as primeiras análises reais, que vão servir de referência.

## Fica de fora agora (decidido, não esquecido)

- **Notion:** os campos do frontmatter já são planos para virar propriedades de banco do Notion. A integração só acontece quando for pedida.
- **Busca e comparação:** por enquanto, `indice.md` mais a leitura dos arquivos pelo Claude bastam. Um índice gerado ou uma busca semântica só se a biblioteca crescer a ponto de isso doer.
- **Lotes:** um vídeo por vez.
- **Ferramenta audiovisual:** o plugin Watch é instalado e validado numa sessão própria, dentro deste projeto e não na plataforma.

## Consequências

- O formato é fácil de ler, de versionar e de migrar. O custo é manter o índice à mão, o que a skill `analisar-video` faz e a suíte confere.
- Se o modelo de análise mudar, as análises antigas continuam válidas enquanto as seções obrigatórias da suíte forem as mesmas.
