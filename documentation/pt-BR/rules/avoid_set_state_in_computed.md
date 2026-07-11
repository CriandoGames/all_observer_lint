# avoid_set_state_in_computed

- **Categoria:** purity
- **Severidade:** warning
- **Bloqueante:** não
- **Preset:** `recommended`, `all`
- **Quick fix:** não
- **Versão do `all_observer`:** qualquer versão, em combinação com `State.setState` do Flutter

## O que a regra faz

Sinaliza `setState(...)` chamado dentro de um callback de derivação de
`Computed`.

## Motivo

Callbacks de `Computed` podem executar fora do ciclo de vida do widget —
por exemplo, especulativamente, durante o rastreamento de dependências
disparado por um `Observer` não relacionado. Chamar `setState` a partir
dali toca o estado do widget fora de um contexto de build/evento, o que o
próprio Flutter não garante ser seguro.

## Exemplo incorreto

```dart
late final flag = Computed(() {
  setState(() {});
  return someObservable.value;
});
```

## Exemplo correto

```dart
late final flag = Computed(() => someObservable.value);

// Reaja à mudança explicitamente em vez disso:
late final _sync = ever(someObservable, (_) => setState(() {}));
```

## Exceções

Apenas `setState` resolvido para a classe `State` do Flutter é sinalizado;
um método de mesmo nome em uma classe não relacionada não é (a
identificação usa a biblioteca do elemento resolvido, não apenas o nome do
método).

## Limitações

`setState` chamado indiretamente por meio de um método auxiliar invocado
dentro do callback de `Computed` não é detectado nesta versão.

## Como desativar

```yaml
custom_lint:
  rules:
    - avoid_set_state_in_computed: false
```

## Evidência

Severidade `warning`; sem alegação de bloqueio, sem documento de evidência
exigido.
