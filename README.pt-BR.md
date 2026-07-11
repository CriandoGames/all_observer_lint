# all_observer_lint

![Banner do all_observer_lint](assets/all_observer_lint_banner.png)

Regras oficiais de lint para criar apps Flutter e Dart mais seguros com
[`all_observer`](https://github.com/CriandoGames/all_observer).

[Read in English](README.md)

O `all_observer_lint` ajuda a encontrar erros comuns de reatividade direto na
IDE: estado criado dentro do `build`, effects registrados a cada rebuild, uso
incorreto de `watch(context)`, callbacks de `Computed` com efeitos colaterais e
recursos reativos que não foram descartados.

Ele é usado apenas em desenvolvimento. O runtime do seu app não muda.

## Instalar

Adicione os dois pacotes como dependências de desenvolvimento:

```bash
dart pub add --dev custom_lint all_observer_lint
```

Em projetos Flutter:

```bash
flutter pub add --dev custom_lint all_observer_lint
```

Seu `pubspec.yaml` deve ficar assim:

```yaml
dev_dependencies:
  custom_lint: ^0.7.0
  all_observer_lint: ^0.1.0
```

O `custom_lint` é necessário porque ele é o runner do analyzer que carrega
plugins de lint customizados. O `all_observer_lint` fornece as regras.

## Configurar

No `analysis_options.yaml`, use o preset recomendado:

```yaml
include: package:all_observer_lint/recommended.yaml
```

Esse preset habilita o plugin `custom_lint` do analyzer e o conjunto de regras
recomendado.

Para exibir mensagens em português do Brasil:

```yaml
include: package:all_observer_lint/recommended.yaml

all_observer:
  language: pt-BR
```

## Executar

Use o fluxo normal do analyzer:

```bash
dart analyze
```

Ou rode o custom lint diretamente:

```bash
dart run custom_lint
```

Em projetos Flutter:

```bash
flutter analyze
dart run custom_lint
```

Depois do `pub get`, a maioria das IDEs mostra os diagnósticos
automaticamente.

## Exemplo

Este código cria estado reativo sempre que o widget reconstrói:

```dart
Widget build(BuildContext context) {
  final count = 0.obs;
  return Text('${count.value}');
}
```

O `all_observer_lint` reporta:

```text
warning: Evite criar estado reativo dentro do build. Esse recurso será
recriado sempre que o widget for reconstruído. Mova-o para um campo do State,
para o initState, um controller, uma view model ou outro objeto controlado pelo
ciclo de vida.
```

Mova o estado para um local controlado pelo ciclo de vida:

```dart
class _CounterPageState extends State<CounterPage> {
  final count = 0.obs;

  @override
  Widget build(BuildContext context) {
    return Observer(() => Text('${count.value}'));
  }
}
```

## Quick Fixes

Algumas regras oferecem quick fixes na IDE. Por exemplo,
`dispose_reactive_resources` pode adicionar uma chamada de `dispose()` ausente:

```dart
class _SearchPageState extends State<SearchPage> {
  late final worker = debounce(query, onSearch);

  @override
  void dispose() {
    worker.dispose();
    super.dispose();
  }
}
```

## Presets

| Preset | Quando usar |
|---|---|
| `recommended.yaml` | Você quer o conjunto padrão de regras para projetos do dia a dia. |
| `strict.yaml` | Você também quer sugestões experimentais para um design reativo mais limpo. |
| `all.yaml` | Você quer testar todas as regras disponíveis. |

## Regras

| Regra | O que detecta |
|---|---|
| [`avoid_reactive_creation_in_build`](documentation/pt-BR/rules/avoid_reactive_creation_in_build.md) | `Observable`, `.obs`, `Computed`, `ObservableFuture` ou `ObservableStream` criados dentro de escopos de rebuild. |
| [`avoid_effect_creation_in_build`](documentation/pt-BR/rules/avoid_effect_creation_in_build.md) | `effect`, `ever`, `once`, `debounce` ou `interval` registrados dentro de escopos de rebuild. |
| [`watch_only_inside_build`](documentation/pt-BR/rules/watch_only_inside_build.md) | `watch(context)` usado fora de contextos de build de widget. |
| [`dispose_reactive_resources`](documentation/pt-BR/rules/dispose_reactive_resources.md) | Workers/effects/streams guardados em campos, mas não descartados. |
| [`avoid_reactive_write_in_computed`](documentation/pt-BR/rules/avoid_reactive_write_in_computed.md) | Escritas reativas dentro de callbacks de `Computed`. |
| [`avoid_set_state_in_computed`](documentation/pt-BR/rules/avoid_set_state_in_computed.md) | `setState` dentro de callbacks de `Computed`. |
| [`avoid_worker_creation_in_computed`](documentation/pt-BR/rules/avoid_worker_creation_in_computed.md) | Workers/effects criados dentro de callbacks de `Computed`. |
| [`avoid_io_in_computed`](documentation/pt-BR/rules/avoid_io_in_computed.md) | `await` ou I/O evidente de `dart:io` dentro de callbacks de `Computed`. |
| [`avoid_observable_write_during_observer_build`](documentation/pt-BR/rules/avoid_observable_write_during_observer_build.md) | Escritas reativas enquanto um `Observer` esta construindo UI. |
| [`prefer_computed_for_derived_state`](documentation/pt-BR/rules/prefer_computed_for_derived_state.md) | Estado derivado manual que poderia ser um `Computed`. |
| [`prefer_batch_for_multiple_related_writes`](documentation/pt-BR/rules/prefer_batch_for_multiple_related_writes.md) | Escritas reativas relacionadas que podem se beneficiar de `batch`. |

## Mais Documentação

- [App de exemplo](example/)
- [Arquitetura e por que `custom_lint` é necessário](documentation/architecture.md)
- [Limitações conhecidas e próximas regras](documentation/backlog.md)
- [Política de falsos positivos](documentation/false_positives.md)

## Licença

MIT. Veja [LICENSE](LICENSE).
