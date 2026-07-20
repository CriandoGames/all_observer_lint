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
  custom_lint: ^0.8.0
  all_observer_lint: ^0.5.1
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

custom_lint:
  rules:
    - all_observer:
      language: pt-BR
```

### Migrando da 0.3.x

O comando de instalação do pacote não mudou, mas opções customizadas agora
usam o formato `custom_lint.rules`. Se você configurava diagnósticos em
português com a chave top-level `all_observer:`, mova essa opção para
`custom_lint.rules`, como no exemplo acima.

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

Algumas regras oferecem quick fixes na IDE. `dispose_reactive_resources`
seleciona a chamada pelo tipo resolvido do campo. Em especial, o descarte de
`effect()` é invocado como callback:

```dart
class _SearchPageState extends State<SearchPage> {
  late final disposeEffect = effect(() => query.value);

  @override
  void dispose() {
    disposeEffect();
    super.dispose();
  }
}
```

## Assists

Selecione uma expressão Widget resolvida com leitura reativa imediata e escolha
**Wrap with Observer**. O assist gera `Observer(() => widget)`, reutiliza
imports prefixados e adiciona o import quando for seguro — caindo para um
import prefixado, gerado com um nome único (ex.: `allObserver.Observer`),
sempre que uma referência simples a `Observer` ficaria sombreada ou ambígua
(uma declaração de mesmo nome no arquivo, um parâmetro/variável local
sombreando, ou outro import sem prefixo que também exponha `Observer`). Ele
não aparece em callbacks, contextos já rastreados, `watch(context)`,
contextos constantes ou código não resolvido.

Selecionar uma leitura reativa `.value` (de um `Observable`/`Computed`)
também oferece **Wrap smallest reactive subtree with Observer** — uma ação
mais específica, que envolve apenas o menor Widget que contém essa leitura,
sem tocar nos irmãos ao redor, e que fica indisponível quando a leitura só
alcança um Widget através de uma closure de evento (ex.: `onPressed`) ou
quando o Widget já é exatamente a raiz de um builder `Observer` existente.

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
| [`self_referencing_computed`](documentation/pt-BR/rules/self_referencing_computed.md) | Um `Computed` lendo diretamente o próprio `.value`. |
| [`prefer_computed_for_derived_state`](documentation/pt-BR/rules/prefer_computed_for_derived_state.md) | Estado derivado manual que poderia ser um `Computed`. |
| [`prefer_batch_for_multiple_related_writes`](documentation/pt-BR/rules/prefer_batch_for_multiple_related_writes.md) | Escritas reativas relacionadas que podem se beneficiar de `batch`. |
| [`prefer_assign_all_for_reactive_list_replace`](documentation/pt-BR/rules/prefer_assign_all_for_reactive_list_replace.md) | `ObservableList.clear()` seguido de `add`/`addAll`; prefira `assign`/`assignAll`. |
| [`unused_reactive_state`](documentation/pt-BR/rules/unused_reactive_state.md) | Campos ou variaveis top-level reativas privadas que nunca sao usadas no mesmo arquivo. |
| [`unobserved_reactive_read_in_build`](documentation/pt-BR/rules/unobserved_reactive_read_in_build.md) | Leituras reativas de `.value` renderizadas no `build` sem `Observer` ou `watch(context)`. |
| [`invalid_history_limit`](documentation/pt-BR/rules/invalid_history_limit.md) | Limites conhecidos não positivos de `ObservableHistory`. |
| [`async_inside_batch`](documentation/pt-BR/rules/async_inside_batch.md) | Callbacks diretamente assíncronos passados a `Observable.batch`. |
| [`observer_without_reactive_read`](documentation/pt-BR/rules/observer_without_reactive_read.md) | Builders de `Observer` sem leitura rastreada comprovada (strict/all). |
| [`computed_without_reactive_read`](documentation/pt-BR/rules/computed_without_reactive_read.md) | Callbacks de `Computed` sem leitura rastreada comprovada (strict/all). |
| [`effect_without_reactive_read`](documentation/pt-BR/rules/effect_without_reactive_read.md) | Callbacks de `effect` sem leitura rastreada comprovada (strict/all). |
| [`copied_reactive_collection_outside_tracking`](documentation/pt-BR/rules/copied_reactive_collection_outside_tracking.md) | Uma coleção reativa copiada para um snapshot comum antes de um `Observer`/`Computed`/`effect` que só lê o snapshot (strict/all). |

## Mais Documentação

- [App de exemplo](example/)
- [Arquitetura e por que `custom_lint` é necessário](documentation/architecture.md)
- [Limitações conhecidas e próximas regras](documentation/backlog.md)
- [Política de falsos positivos](documentation/false_positives.md)

## Licença

MIT. Veja [LICENSE](LICENSE).
