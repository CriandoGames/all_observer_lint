# avoid_observable_write_during_observer_build

- **Categoria:** reactive-cycle
- **Severidade:** warning (candidata a uma variante `error` mais restrita, ainda não promovida — ver abaixo)
- **Bloqueante:** não
- **Preset:** `recommended`, `all`
- **Quick fix:** não
- **Versão do `all_observer`:** todas as versões em que o callback de `Observer` é reexecutado a cada notificação

## O que a regra faz

Sinaliza uma escrita reativa direta — `x.value = ...`, `x.value++`/`--`,
ou uma atribuição composta em `.value` — dentro de um callback de
renderização de `Observer(...)`.

## Motivo

O callback de `Observer` deve ser uma função de renderização somente
leitura. Uma escrita ali, especialmente em uma dependência que o próprio
callback lê, arrisca um loop de re-renderização imediato.

## Por que (ainda) não foi dividida em uma regra `error` mais restrita

Pela política de evidências deste projeto, apenas uma escrita que seja
*comprovadamente* cíclica de forma determinística — por exemplo, uma
escrita incondicional em uma dependência que o mesmo callback lê de forma
incondicional — poderia se tornar um diagnóstico mais restrito, em nível
`error`, chamado
`unconditional_reactive_write_during_observer_build`. Uma escrita
condicional, ou uma escrita em um observável que o callback não lê, é
arquiteturalmente questionável mas não comprovadamente causa pane em toda
versão do `all_observer`. Agrupar todos os casos em uma única regra
`error` violaria a política "regras bloqueantes exigem prova" descrita na
seção 26.3 do briefing deste projeto. Ver `documentation/backlog.md`.

## Exemplo incorreto

```dart
Observer(() {
  if (counter.value < 0) {
    counter.value = 0;
  }
  return Text('${counter.value}');
});
```

```dart
Observer(() {
  counter.value++;
  return Text('${counter.value}');
});
```

## Exemplo correto

```dart
Observer(() => Text('${counter.value}'));

// Faça o clamp onde o valor é produzido, em vez de durante a renderização:
void increment() => counter.value = (counter.value + 1).clamp(0, 100);
```

## Exceções

Uma escrita dentro de um closure aninhado que não é, ele mesmo, o callback
do `Observer` (por exemplo, um `onPressed` de botão declarado dentro da
árvore de widgets retornada pelo `Observer`) não é sinalizada — ele só
executa em resposta à interação, não enquanto o `Observer` está
construindo.

## Limitações

Escritas em coleções reativas não são detectadas nesta versão; apenas
atribuição/incremento/decremento de `.value`.

## Como desativar

```yaml
custom_lint:
  rules:
    - avoid_observable_write_during_observer_build: false
```

## Evidência

Severidade `warning`; sem alegação de bloqueio, sem documento de evidência
exigido nesta severidade. Ver `documentation/backlog.md` para o caminho de
promoção de uma futura variante `error` mais restrita.
