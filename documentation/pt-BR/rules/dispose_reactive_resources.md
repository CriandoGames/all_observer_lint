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
verificados. Posse por helper/factory e classes sem `dispose()` próprio ficam
silenciosas. Uma chamada em fluxo condicional é aceita; não há prova sensível a
caminhos. Delegar descarte a helper pode gerar falso positivo.

## Quando ignorar

Ignore quando o descarte for delegado intencionalmente por uma abstração de
ownership que a regra local não consegue seguir.

## Fix ou assist

O quick fix insere a chamada correta para o tipo antes de `super.dispose()`.
Ele não cria lifecycle para classes arbitrárias. Não há assist associado.
