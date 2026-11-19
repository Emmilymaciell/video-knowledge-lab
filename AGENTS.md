# AGENTS.md — Video Knowledge Lab

Adaptador para agentes de código (Codex e outros). O estado canônico é **neutro de provedor**:

1. `docs/STATE.md` — onde o projeto está;
2. `docs/HANDOFF.md` — como assumir sem a conversa;
3. `docs/decisions/` — o que já foi decidido (não reabrir sem motivo técnico novo).

`CLAUDE.md` é o adaptador equivalente para o Claude. Nenhum dos dois é fonte de verdade.

## Regras

- Nunca `git add` / `git commit` / `git tag` por iniciativa própria; só a pedido explícito.
- Nunca `git add .` às cegas: status, diff, varredura de segredos, add seletivo.
- Nunca push, reset --hard, clean, rebase ou amend sem pedido explícito.
- Segredo e dado pessoal de terceiro nunca entram no Git; dado bruto vai para o Drive.
- Testes: `.\tests\run-tests.ps1`.
