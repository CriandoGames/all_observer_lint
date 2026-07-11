# unused_reactive_state

Reporta estado reativo privado que foi criado, mas nunca foi referenciado no
mesmo arquivo Dart.

Esta regra faz parte dos presets `strict.yaml` e `all.yaml`. Ela nao faz parte
do `recommended.yaml` porque estado privado sem uso normalmente e um sinal de
limpeza/design, nao um bug de runtime garantido.

## Ruim

```dart
class CounterController {
  final _count = 0.obs;

  void increment() {}
}
```

## Bom

```dart
class CounterController {
  final _count = 0.obs;

  void increment() {
    _count.value++;
  }
}
```

## O que ela verifica

A regra comeca estreita de proposito. Ela reporta apenas:

- campos privados, como `_count`;
- variaveis privadas top-level, como `_currentUser`;
- inicializadores criados com `.obs`, `Observable`, `Computed`,
  `ObservableFuture`, `ObservableStream` ou outro tipo reativo reconhecido;
- simbolos que nao possuem nenhuma referencia resolvida no mesmo arquivo Dart.

Variaveis locais sao ignoradas porque o Dart ja tem diagnosticos gerais para
locais sem uso e porque valores reativos locais aparecem com frequencia em
exemplos curtos ou testes.
