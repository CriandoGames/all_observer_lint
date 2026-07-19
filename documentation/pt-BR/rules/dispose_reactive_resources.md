# dispose_reactive_resources

- **Categoria:** gerenciamento de recursos
- **Severidade:** warning
- **Preset:** `recommended`, `strict`, `all`
- **Quick fix:** sim, baseado no tipo estático resolvido

## Objetivo

Sinaliza campos de recursos reativos diretamente possuídos que não são
liberados no método `dispose()` com bloco da classe proprietária.

Contratos verificados:

| Tipo | Chamada gerada/reconhecida |
|---|---|
| `Disposer` | `campo()` |
| `Worker`, `Workers`, `ObservableHistory`, `ReactiveScope` | `campo.dispose()` |
| `Computed`, `ObservableFuture`, `ObservableStream` | `campo.close()` |
| `ObservableSubscription` | `campo.cancel()` |

Um `Observable` simples não é fechado automaticamente por esta regra.

## Código incorreto

```dart
late final Disposer disposeEffect = effect(() => count.value);

void dispose() {
  super.dispose();
}
```

## Código correto

```dart
void dispose() {
  disposeEffect();
  super.dispose();
}
```

## Limitações e falsos positivos possíveis

Somente campos com inicializador direto, resolvido e de posse comprovada são
verificados. Classes sem `dispose()` próprio ficam silenciosas. Uma chamada em
fluxo condicional é aceita; não há prova sensível a caminhos.

Descarte delegado a um método helper *é* seguido, mas de forma restrita: um
método da mesma classe, sem parâmetros, chamado sem alvo ou via `this.`
(`_disposeResources()`, `this._disposeResources()`), diretamente ou
encadeado por outros helpers assim. Um helper que recebe parâmetro (ex.:
`_disposeWith(worker)`), que vive em outra classe/mixin, ou só é alcançado
via tear-off, não é seguido — o campo continua sendo sinalizado nesses
casos.

## Quando ignorar

Ignore quando o descarte for delegado intencionalmente por uma abstração de
ownership que a regra local não consegue seguir.

## Fix ou assist

O quick fix insere a chamada correta para o tipo antes de `super.dispose()`.
Ele não cria lifecycle para classes arbitrárias. Não há assist associado.
