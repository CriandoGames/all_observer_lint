# effect_without_reactive_read

## Objetivo

Informa quando um callback de `effect` não possui leitura reativa rastreada
visível estaticamente e, portanto, não tem dependência que agende nova execução.

## Código incorreto

```dart
effect(() => log('iniciado'));
```

## Código correto

```dart
effect(() => log('${session.value}'));
```

## Severidade

`info`; disponível somente em `strict` e `all`.

## Limitações e falsos positivos possíveis

É uma estimativa estática local. Código não resolvido, callbacks não suportados
e helpers que podem esconder leitura são suprimidos. Dependências indiretas não
são seguidas entre funções.

## Quando ignorar

Ignore quando um callback deliberadamente executado uma vez precisar manter um
ciclo de vida tipado como `effect` por razões arquiteturais externas.

## Fix ou assist

Não há fix ou assist automático.
