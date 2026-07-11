# avoid_worker_creation_in_computed

- **Categoria:** purity / resource-management
- **Severidade:** warning
- **Bloqueante:** não
- **Preset:** `recommended`, `all`
- **Quick fix:** não
- **Versão do `all_observer`:** todas as versões que expõem `effect`, `ever`, `once`, `debounce`, `interval`

## O que a regra faz

Sinaliza `effect(...)`, `ever(...)`, `once(...)`, `debounce(...)` ou
`interval(...)` registrados dentro de um callback de derivação de
`Computed`.

## Motivo

`Computed` pode ser recomputado múltiplas vezes — inclusive de forma
especulativa pelo rastreador de dependências — então cada recomputação
registraria uma nova subscription, nunca descartada.

## Exemplo incorreto

```dart
late final withWorker = Computed(() {
  ever(counter, (value) {});
  return counter.value;
});
```

## Exemplo correto

```dart
late final derived = Computed(() => counter.value * 2);

// Registre o worker uma única vez, fora do Computed:
late final _tracker = ever(counter, (value) {});
```

## Exceções

Nenhuma além da identificação semântica padrão (apenas `effect`/`ever`/
`once`/`debounce`/`interval` resolvidos para o `all_observer` são
considerados).

## Limitações

Registro por meio de uma função auxiliar chamada dentro do callback de
`Computed` não é detectado nesta versão.

## Como desativar

```yaml
all_observer:
  rules:
    - avoid_worker_creation_in_computed: false
```

## Evidência

Severidade `warning`; sem alegação de bloqueio, sem documento de evidência
exigido.
