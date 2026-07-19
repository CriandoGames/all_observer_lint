# async_inside_batch

## Objetivo

Avisa quando o callback passado diretamente a `Observable.batch` é
estaticamente `async`. O batch é síncrono e não atravessa um `await`.

## Código incorreto

```dart
Observable.batch(() async {
  await save();
});
```

## Código correto

```dart
await save();
Observable.batch(() {
  first.value = 1;
  second.value = 2;
});
```

## Severidade

`warning`; disponível em `recommended`, `strict` e `all`.

## Limitações e falsos positivos possíveis

A regra exige o `batch` resolvido de `all_observer` e evidência direta de
closure assíncrona. Não infere assincronicidade das funções chamadas; falsos
negativos são possíveis, mas avisos especulativos são evitados.

## Quando ignorar

Ignore somente se um fork do runtime suportar batches assíncronos.

## Fix ou assist

Não há fix, pois mover `await` pode mudar ordem e tratamento de erros.
