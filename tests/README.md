# Testes deste projeto

**Como rodar:**

```powershell
.\tests\run-tests.ps1
```

Um comando só, igual em todo projeto governado pelo Emmily AI Project OS, qualquer que seja a linguagem. Ele é o valor de `verificacao.comando` no `project.yaml` — se um dia mudar, muda ali e em nenhum outro lugar.

Códigos de saída, mesma convenção do ADR-0009 da plataforma:

| Saída | Significa |
|---|---|
| `0` | a suíte rodou e passou |
| `1` | a suíte rodou e falhou |
| `2` | **a suíte não rodou** — sem suíte, sem `.venv`, sem `pytest`, ou nenhum caso executado |

**`2` não é uma variação de `1`.** "Não verificado" é um terceiro estado, e apagar a diferença entre ele e "passou" é a violação descrita em `docs/VERIFICATION-POLICY.md` seção 4.5 da plataforma. Um runner que não acha suíte nenhuma e sai com `0` está dizendo "passou" sobre nada.

## As duas trilhas — apague a que este projeto não usa

O template vem com as duas. O `/os:new-project` remove a que não se aplica, como já faz com o `requirements.txt`. Se as duas sobreviverem, o runner **recusa rodar** (saída `2`), porque escolher em silêncio esconderia metade dos testes.

| Trilha | Arquivos | Quando |
|---|---|---|
| **Python** | `conftest.py`, `test_*.py` | o projeto tem código Python em `scripts/` |
| **PowerShell** | `_harness.ps1`, `suites/*.ps1` | o projeto é PowerShell, ou `ambiente.python: nao-usa` |

Para apagar a trilha Python: remova `conftest.py` e todo `test_*.py`.
Para apagar a trilha PowerShell: remova `_harness.ps1` e a pasta `suites/`.

## O que você ganha de graça

### O critério de aceite vem do manifesto, não da asserção

Este é o ponto mais importante do arquivo, e nasceu de um defeito real. No `conversor-utm`, o critério "dentro de 1 metro" existia em três lugares — a prosa do `README.md`, a docstring do teste, e um `1.0` cravado na asserção — e em nenhum deles era fonte de verdade. Número repetido envelhece.

Declare no `project.yaml`:

```yaml
verificacao:
  criterio_de_pronto: "a saida fecha com o caso de referencia dentro de 1 metro"
  limites:
    erro_maximo_m: 1.0
```

E use:

```python
def test_fecha_no_criterio(limite):
    assert erro_medido < limite("erro_maximo_m")
```

```powershell
Test-Caso "fecha no criterio" {
    Assert-True ($erroMedido -lt (Get-LimiteDoManifesto 'erro_maximo_m')) "..."
}
```

**Limite ausente faz o teste falhar, nunca passar.** Não existe valor padrão em nenhuma das duas trilhas: critério que não está no manifesto não é critério, e um padrão silencioso transformaria "o projeto não declarou" em "passou".

### Fixtures e funções prontas

**Trilha Python** (`conftest.py`):

| | |
|---|---|
| `projeto_raiz` | a raiz do projeto como `Path` |
| `manifesto` | o `project.yaml` lido como dicionário |
| `criterio_de_pronto` | a frase do manifesto |
| `limite("nome")` | um número de `verificacao.limites` |
| `csv_com_bom("A,B\n1,2\n")` | cria um CSV com BOM, como o Excel e o PowerShell salvam |

`scripts/` já está no caminho de import: escreva `from meu_modulo import x`, sem `sys.path.insert`.

**Trilha PowerShell** (`_harness.ps1`):

| | |
|---|---|
| `Test-Caso "nome" { }` | um caso isolado; exceção é falha e não derruba os outros |
| `Assert-True $cond "mensagem"` | asserção. Parâmetro `[bool]` **não** aceita string |
| `Get-Texto <caminho>` | lê como UTF-8 e **lança** se o arquivo tiver byte inválido — não substitui em silêncio. `Get-Content -Raw` sem `-Encoding` corrompe acento no 5.1 |
| `Get-RaizDoProjeto` | a raiz do projeto |
| `Get-CampoDoManifesto 'a.b.c'` | um campo do `project.yaml`; **lança** se não existir |
| `Get-LimiteDoManifesto 'nome'` | um número de `verificacao.limites` |

## O que estes testes NÃO cobrem

Escrito aqui porque a política 4.7 exige que o não coberto esteja escrito — e porque ler isto **antes** dos resultados é o que impede achar que o escopo era completo:

- **Comportamento que depende de julgamento de modelo.** Isso é assunto de `evals/`, não de `tests/`. Se este projeto tiver `componente_llm: true` e nenhum `evals/`, a lacuna é real.
- **Contrato com serviço externo** (SharePoint, Excel via COM, n8n, qualquer API). Precisa de teste de integração com mock, e ele não nasce do template.
- **Dado sensível.** Quem responde por isso é o `/os:security` da plataforma, com varredura do histórico do Git — não um teste local.
- **Portabilidade real.** Só se prova em clone limpo em outra máquina (política 4.2). Suíte verde aqui não diz nada sobre isso.
- **Correção absoluta quando o teste é de consistência.** Round-trip prova que ida e volta fecham; não prova que o valor está certo. Se as duas direções compartilharem o mesmo erro, ele passa. Onde isso se aplica, o caso de referência externo é pendência declarada, não detalhe.

## Convenções que valem a pena manter

**Todo detector precisa provar que acusa** (política 4.1). Teste que só verifica o caminho felizardo não é detector: escreva o par negativo, e confira que ele **falha** com o detector desligado. Verde sobre ramo não exercitado é o defeito mais caro desta plataforma — ele já apareceu quatro vezes.

**Bug achado vira teste de regressão, com a história.** Não só a asserção: a docstring conta o que quebrou e como o erro aparecia. O melhor exemplo é o do BOM — o sintoma era `coluna ausente` com o arquivo aparentemente correto, e quem lê a asserção nua nunca adivinharia isso.

**Nome de caso é frase, não rótulo.** `test_csv_sem_as_colunas_obrigatorias_falha_claro` diz o que se espera. `test_csv_2` não diz nada, e é o primeiro a ser apagado por engano.
