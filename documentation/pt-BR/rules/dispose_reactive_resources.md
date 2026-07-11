# dispose_reactive_resources

- **Categoria:** resource-management
- **Severidade:** warning
- **Bloqueante:** não
- **Preset:** `recommended`, `strict`, `all`
- **Quick fix:** sim — insere `<campo>.dispose();` como a primeira instrução de `dispose()`
- **Versão do `all_observer`:** versões em que `effect`/`ever`/`once`/`debounce`/`interval` retornam um handle descartável, e `ObservableStream` expõe `dispose()`

## O que a regra faz

Sinaliza um campo que guarda um effect/worker ou um `ObservableStream` que
nunca é descartado dentro do método `dispose()` da classe proprietária.

## Motivo

Workers não descartados continuam ouvindo depois que seu proprietário já
não existe: callbacks obsoletos, efeitos colaterais duplicados em ciclos de
hot reload/rebuild, e memória que nunca é liberada.

## Exemplo incorreto

```dart
class _SearchPageState extends State<SearchPage> {
  late final worker = debounce(query, onSearch, time: const Duration(milliseconds: 400));

  @override
  void dispose() {
    super.dispose(); // worker nunca é descartado
  }
}
```

## Exemplo correto

```dart
class _SearchPageState extends State<SearchPage> {
  late final worker = debounce(query, onSearch, time: const Duration(milliseconds: 400));

  @override
  void dispose() {
    worker.dispose();
    super.dispose();
  }
}
```

## Exceções

Uma classe sem seu próprio método `dispose()` não é sinalizada: sem um
método de ciclo de vida para verificar, a propriedade do recurso é
ambígua, e esta regra prefere ficar em silêncio a arriscar um chute.

## Limitações (primeira versão)

- Apenas campos são verificados, não variáveis locais.
- O inicializador do campo precisa ser uma expressão direta de
  `effect`/`ever`/`once`/`debounce`/`interval`/`ObservableStream(...)`;
  transferência de propriedade do descarte por meio de um método auxiliar
  ainda não é rastreada.
- O descarte é reconhecido como qualquer chamada `<campo>.dispose()` em
  qualquer parte de `dispose()`, independentemente do fluxo de controle
  (por exemplo, dentro de um `if`) — uma versão futura pode restringir isso
  conforme falsos negativos reais forem coletados.

## Como desativar

```yaml
custom_lint:
  rules:
    - dispose_reactive_resources: false
```

## Evidência

Severidade `warning`; sem alegação de bloqueio, sem documento de evidência
exigido.
