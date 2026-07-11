# self_referencing_computed

- Categoria: reactive-cycle
- Severidade: error
- Preset: recommended
- Quick fix: não
- Aplica-se a: `Computed` do `all_observer`

## O Que Detecta

Um `Computed` lendo o próprio `.value` dentro do callback usado para derivar
esse mesmo `Computed`.

## Por Que

Callbacks de `Computed` devem derivar um valor a partir de outras entradas
reativas. Ler o próprio `Computed` enquanto ele está sendo derivado cria um
ciclo reativo direto: o valor depende dele mesmo e o grafo não consegue
estabilizar.

## Incorreto

```dart
class CounterState {
  late final Computed<int> total = Computed(() {
    return total.value + 1;
  });
}
```

## Correto

```dart
class CounterState {
  final count = 0.obs;

  late final Computed<int> total = Computed(() {
    return count.value + 1;
  });
}
```

Ler outro `Computed` também é válido:

```dart
class CounterState {
  final count = 0.obs;

  late final Computed<int> doubled = Computed(() => count.value * 2);
  late final Computed<int> quadrupled = Computed(() => doubled.value * 2);
}
```

## Limitações

Esta regra é intencionalmente estreita. Ela só reporta autorreferências diretas
quando o `Computed(...)` é atribuído diretamente a uma variável ou campo e o
callback lê `.value` desse mesmo símbolo resolvido.

Ela não tenta detectar ciclos maiores, como `a -> b -> a`.

## Evidência

Veja [self_referencing_computed.md](../../evidence/self_referencing_computed.md).

## Desativar

```yaml
include: package:all_observer_lint/recommended.yaml

all_observer:
  rules:
    self_referencing_computed: false
```
