# avoid_reactive_write_in_computed

- **Categoria:** purity
- **Severidade:** warning (candidata a `error`, ainda não promovida — ver abaixo)
- **Bloqueante:** não
- **Preset:** `recommended`, `all`
- **Quick fix:** não
- **Versão do `all_observer`:** todas as versões em que callbacks de `Computed` são reexecutados quando uma dependência muda

## O que a regra faz

Sinaliza uma escrita direta em um valor reativo — `x.value = ...`,
`x.value++`, `x.value--`, ou uma atribuição composta em `.value` — dentro
de um callback de derivação de `Computed`.

## Motivo

`Computed` deve derivar um valor sem efeitos colaterais. Uma escrita ali
pode invalidar o próprio grafo de dependências que está sendo avaliado, e é
imprevisível sob a estratégia de memoização/reavaliação do `all_observer`.

## Por que ainda não é `error`

A seção 23 do guia de contribuição deste projeto ("regras bloqueantes
exigem prova") exige uma falha reproduzível demonstrada contra o próprio
engine do `all_observer`, além de um teste de regressão de runtime naquele
repositório, antes que uma regra possa bloquear o CI por padrão. Essa
evidência ainda não foi coletada para todas as formas de escrita que esta
regra detecta (em particular, se o runtime do all_observer intercepta a
escrita, lança uma exceção, ou produz silenciosamente um valor obsoleto
depende do padrão exato de escrita — ver `documentation/backlog.md`,
"observable_write_during_computed"). Até lá, a regra permanece `warning`.

## Exemplo incorreto

```dart
final normalized = Computed(() {
  if (name.value.isEmpty) {
    name.value = 'Unknown';
  }
  return name.value.trim();
});
```

## Exemplo correto

```dart
final normalized = Computed(
  () => name.value.isEmpty ? 'Unknown' : name.value.trim(),
);
```

## Exceções

- Closures aninhados puros e sem efeitos colaterais (`.map`, `.where`,
  `.fold` e similares) não são sinalizados — apenas uma escrita real em
  `.value` é.
- Um campo chamado `value` em um tipo não reativo não relacionado nunca é
  confundido com um `.value` reativo — a identificação exige que o tipo
  estático do alvo seja `Observable`/`Computed`.

## Limitações

- Escritas em coleções reativas (`list.add(...)`) não são detectadas nesta
  versão; apenas atribuição/incremento/decremento de `.value`.
- Uma escrita dentro de um closure aninhado genuinamente adiado (por
  exemplo, `Future(...).then((_) { x.value = 1; })`) ainda é sinalizada
  mesmo não executando de forma síncrona como parte da derivação — ver
  `documentation/backlog.md`.

## Como desativar

```yaml
all_observer:
  rules:
    - avoid_reactive_write_in_computed: false
```

## Evidência

Nenhuma alegação de `error` é feita; nenhum documento em
`documentation/evidence/` é exigido nesta severidade. Ver
`documentation/backlog.md` para o caminho de promoção.
