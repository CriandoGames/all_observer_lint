# computed_without_reactive_read

## Objetivo

Informa quando um callback de `Computed` não possui dependência reativa
rastreada visível estaticamente.

## Código incorreto

```dart
Computed(() => 42);
```

## Código correto

```dart
Computed(() => count.value * 2);
```

## Severidade

`info`; disponível somente em `strict` e `all`.

## Limitações e falsos positivos possíveis

É uma estimativa estática local. Código não resolvido, callbacks não suportados
e helpers que podem esconder leituras são suprimidos. Análise interprocedural
fica deliberadamente fora do escopo.

## Quando ignorar

Ignore para uma API derivada intencionalmente constante quando manter o tipo
`Computed` for importante para estabilidade pública.

## Fix ou assist

Não há fix ou assist automático.
