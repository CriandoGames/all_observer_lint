# observer_without_reactive_read

## Objetivo

Informa quando um builder de `Observer` não possui leitura reativa rastreada
visível estaticamente.

## Código incorreto

```dart
Observer(() => const Text('Estático'));
```

## Código correto

```dart
Observer(() => Text('${count.value}'));
```

## Severidade

`info`; disponível somente em `strict` e `all`.

## Limitações e falsos positivos possíveis

É uma estimativa estática local. Builders não suportados, código não resolvido
e helpers que podem esconder leitura são suprimidos. Leituras indiretas por
metaprogramação avançada ainda podem não ser vistas.

## Quando ignorar

Ignore quando o rastreamento vier intencionalmente de comportamento invisível
à análise local e documente essa decisão.

## Fix ou assist

Sem fix. O assist separado `Wrap with Observer` atende Widgets não rastreados
que já contêm uma leitura reativa comprovada.
