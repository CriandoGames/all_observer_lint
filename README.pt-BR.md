# all_observer_lint

Regras de lint oficiais e correções automáticas para um desenvolvimento
seguro, previsível e eficiente com o
[`all_observer`](https://github.com/CriandoGames/all_observer).

[Read in English](README.md)

O `all_observer_lint` não compete com regras genéricas de estilo do
Dart/Flutter (aspas, tamanho de linha, ordenação de imports, e assim por
diante). Toda regra aqui é específica do `all_observer`: ciclo de vida de
recursos reativos, pureza de `Computed`, correção de `Observer`/`watch`, e
descarte de recursos.

## Relação entre `all_observer` e `all_observer_lint`

O `all_observer_lint` é um pacote separado, usado apenas como
`dev_dependency`. Ele nunca adiciona uma dependência de runtime ao seu
aplicativo — apenas analisa seu código e reporta diagnósticos via `dart
analyze` / sua IDE. O próprio `all_observer` (a biblioteca reativa) não é
afetado de nenhuma forma.

## Instalação

```yaml
dev_dependencies:
  all_observer_lint: ^0.1.0
  custom_lint: ^0.7.0
```

## Configuração

No seu `analysis_options.yaml`:

```yaml
include: package:all_observer_lint/recommended.yaml
```

Essa única linha habilita o plugin `custom_lint` do analyzer e o conjunto
de regras recomendado. Para usar diagnósticos em português do Brasil em
vez de inglês:

```yaml
include: package:all_observer_lint/recommended.yaml

all_observer:
  language: pt-BR
```

Para desativar uma regra específica:

```yaml
include: package:all_observer_lint/recommended.yaml

all_observer:
  rules:
    - avoid_io_in_computed: false
```

Execute `dart run custom_lint` (ou deixe o analysis server da sua IDE
detectar automaticamente) para ver os diagnósticos.

## Presets

| Preset | Conteúdo |
|---|---|
| `recommended.yaml` | Regras de ciclo de vida e pureza com baixa taxa de falso positivo. Padrão seguro para qualquer projeto. |
| `strict.yaml` | `recommended.yaml` mais sugestões experimentais e opinativas em nível `info` (`prefer_computed_for_derived_state`, `prefer_batch_for_multiple_related_writes`). |
| `all.yaml` | Todas as regras do pacote, incluindo as experimentais. Útil principalmente para avaliar novas regras. |

## Regras

| Regra | Severidade | Preset |
|---|---|---|
| [`avoid_reactive_creation_in_build`](documentation/pt-BR/rules/avoid_reactive_creation_in_build.md) | warning | recommended |
| [`avoid_effect_creation_in_build`](documentation/pt-BR/rules/avoid_effect_creation_in_build.md) | warning | recommended |
| [`watch_only_inside_build`](documentation/pt-BR/rules/watch_only_inside_build.md) | warning | recommended |
| [`dispose_reactive_resources`](documentation/pt-BR/rules/dispose_reactive_resources.md) | warning | recommended |
| [`avoid_reactive_write_in_computed`](documentation/pt-BR/rules/avoid_reactive_write_in_computed.md) | warning | recommended |
| [`avoid_set_state_in_computed`](documentation/pt-BR/rules/avoid_set_state_in_computed.md) | warning | recommended |
| [`avoid_worker_creation_in_computed`](documentation/pt-BR/rules/avoid_worker_creation_in_computed.md) | warning | recommended |
| [`avoid_io_in_computed`](documentation/pt-BR/rules/avoid_io_in_computed.md) | warning | recommended |
| [`avoid_observable_write_during_observer_build`](documentation/pt-BR/rules/avoid_observable_write_during_observer_build.md) | warning | recommended |
| [`prefer_computed_for_derived_state`](documentation/pt-BR/rules/prefer_computed_for_derived_state.md) | info | strict |
| [`prefer_batch_for_multiple_related_writes`](documentation/pt-BR/rules/prefer_batch_for_multiple_related_writes.md) | info | strict |

Nenhuma regra é publicada como `error` nesta versão — ver
`documentation/backlog.md` para o caminho de promoção baseado em
evidências.

## Exemplo de diagnóstico

```dart
Widget build(BuildContext context) {
  final count = 0.obs; // avoid_reactive_creation_in_build
  return Text('${count.value}');
}
```

```
warning: Evite criar estado reativo dentro do build. Esse recurso será
recriado sempre que o widget for reconstruído. Mova-o para um campo do
State, para o initState, um controller, uma view model ou outro objeto
controlado pelo ciclo de vida.
  --> lib/counter.dart:3:17
```

## Exemplo de quick fix

A regra `dispose_reactive_resources` oferece um quick fix que insere a
chamada de descarte ausente:

```dart
// Antes (sinalizado)
class _SearchPageState extends State<SearchPage> {
  late final worker = debounce(query, onSearch);

  @override
  void dispose() {
    super.dispose();
  }
}

// Depois de aplicar o quick fix
class _SearchPageState extends State<SearchPage> {
  late final worker = debounce(query, onSearch);

  @override
  void dispose() {
    worker.dispose();
    super.dispose();
  }
}
```

Veja `example/` para um app Flutter executável com mais pares
sinalizado/corrigido.

## Compatibilidade

- Dart SDK: `>=3.3.0 <4.0.0`
- `analyzer`: `^7.0.0`
- `custom_lint_builder` / `custom_lint`: `^0.7.0`
- Flutter: exigido apenas pelas regras relacionadas ao ciclo de vida de
  widgets (`avoid_reactive_creation_in_build`,
  `avoid_effect_creation_in_build`, `watch_only_inside_build`,
  `avoid_observable_write_during_observer_build`,
  `avoid_set_state_in_computed`); o próprio pacote não tem dependência do
  Flutter SDK (ver `documentation/architecture.md`).

As restrições de versão aqui são intencionalmente não mais rígidas do que
o necessário; uma mudança incompatível a montante em
`analyzer`/`custom_lint` será tratada com um bump de versão major
documentado do pacote, nunca silenciosamente.

## Política de versionamento

O `all_observer_lint` segue semver para a própria versão do pacote. Dentro
disso:

- Adicionar uma nova regra em nível `info`, ou adicionar uma regra apenas
  ao `all.yaml`, é uma release **minor**.
- Adicionar uma regra ao `recommended.yaml` (que pode ativar novos
  diagnósticos em projetos existentes sem nenhuma ação do consumidor) é
  documentado no changelog como uma release minor notável, mesmo não
  sendo tecnicamente incompatível.
- Promover uma regra de `warning` para `error`, ou alterar o comportamento
  padrão do `recommended.yaml`, é destacado explicitamente no changelog
  como uma mudança potencialmente capaz de quebrar pipelines (ver
  `documentation/backlog.md` e a seção "Provas antes de bloquear o CI" do
  briefing do projeto).

## Como contribuir

Issues e pull requests são bem-vindos no repositório acima. Antes de
propor uma nova regra, leia `documentation/architecture.md` (como
funciona a identificação semântica) e `documentation/backlog.md` (o que já
foi considerado e por que ainda não foi publicado). Propostas de regras
devem seguir o mesmo template dos documentos existentes em
`documentation/pt-BR/rules/`.

## Licença

MIT, ver `LICENSE`.
