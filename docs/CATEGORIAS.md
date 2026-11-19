# Categorias e organização da biblioteca

Regra decidida no [ADR-0002](decisions/ADR-0002-biblioteca-markdown-por-tema.md). Este arquivo diz **como** aplicar.

## Onde mora cada análise

```
biblioteca/<tema>/[<subtema>/]vkl-NNNN-<slug-do-titulo>.md
```

- **ID estável:** `vkl-NNNN`, sequencial, nunca reaproveitado e nunca alterado — nem quando o arquivo muda de tema.
- **Nome do arquivo:** o ID, seguido de um slug descritivo em kebab-case, sem acento (`vkl-0003-hooks-no-claude-code.md`).
- **`tema` no frontmatter = caminho da pasta**, a partir de `biblioteca/`. A suíte de testes confere isso.
- **No máximo 2 níveis:** `tema/subtema`. Não existe terceiro nível.

## Temas

- Os temas **não são criados antes do uso**. A pasta nasce junto com o primeiro conteúdo dela.
- Slug em kebab-case, sem acento, no plural só quando for natural (`saude`, `programacao`, `inteligencia-artificial`).
- **Antes de criar um tema, reaproveite.** Liste as pastas de `biblioteca/` e procure uma equivalente. `ia`, `ai` e `inteligencia-artificial` são o mesmo tema; `claude` e `claude-code` também, salvo se houver motivo claro.
- Para criar um **tema novo de primeiro nível**, proponha à Emmily e espere o "sim". Um **subtema** dentro de um tema existente pode ser criado direto, mas isso deve ser dito no relatório da análise.
- **Nomes que a Emmily usa → tema.** Temas já aprovados por ela, mesmo que a pasta ainda não exista (ela nasce com o primeiro conteúdo, sem precisar perguntar de novo):

  | Ela diz | Tema (pasta) | Aprovado em |
  |---|---|---|
  | "Claude Code" | `inteligencia-artificial/claude-code` | 2026-11-06 |

  Ao criar um tema novo com a aprovação dela, acrescente a linha aqui.
- `outros/` é o tema provisório para conteúdos que ainda não se encaixam em nenhum. Quando três ou mais conteúdos dele tiverem algo em comum, proponha um tema novo.

## Tema da sessão

- Se a Emmily disser "hoje vamos analisar X", X vira o **tema padrão da sessão**: as análises vão para ele, salvo se o conteúdo obviamente não tiver relação com X. Nesse caso, avise e sugira o tema certo.
- Se não houver tema da sessão, ou se ela pedir "salva onde achar melhor", escolha um tema existente e diga qual foi e por quê, em uma linha.
- Uma sessão não cria pasta. Uma pasta reúne conteúdos de várias sessões.

## Um conteúdo, vários assuntos

- O arquivo fica em **um** tema só, o principal.
- Os outros temas vão em `temas_relacionados` no frontmatter e na coluna "Também em" do índice.
- **Nunca duplique o arquivo.** Quando precisar ligar uma análise a outra, use um link relativo na seção "Referências".

## Mudar o tema de um conteúdo

1. Mover o arquivo para a pasta nova. O ID e o resto do nome continuam iguais.
2. Atualizar `tema` (e `temas_relacionados`, se for o caso) no frontmatter.
3. Atualizar a linha no `indice.md` e os links internos que apontavam para o caminho antigo.
4. Rodar `.\tests\run-tests.ps1`.

O conteúdo da análise **não muda** quando a classificação muda.

## Duplicatas

Antes de analisar, procure a URL em `indice.md` e em `biblioteca/`. Se ela já tiver sido analisada, avise e pergunte se é para reanalisar. Uma reanálise **atualiza o arquivo existente**, mantendo o ID, em vez de criar um novo. A suíte reprova URLs repetidas.
