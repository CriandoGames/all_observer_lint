# unobserved_reactive_read_in_build

Reporta leituras de `.value` reativo renderizadas diretamente dentro de um
metodo `build`, sem um contexto observado.

Esta regra faz parte dos presets `strict.yaml` e `all.yaml`. Ela ainda nao faz
parte do `recommended.yaml` porque uma leitura direta de `.value` pode ser um
snapshot intencional em alguns casos, mas em UI renderizada normalmente indica
que o widget nao vai atualizar quando o valor reativo mudar.

## Ruim

```dart
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return Text(controller.name.value);
  }
}
```

## Bom

```dart
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return Observer(() => Text(controller.name.value));
  }
}
```

Ou:

```dart
Widget build(BuildContext context) {
  return Text(controller.name.watch(context));
}
```

## O que ela verifica

A regra reporta apenas leituras de `.value` cujo alvo foi resolvido como um
tipo reativo do `all_observer` e cujo escopo de rebuild mais proximo e um
metodo Flutter `build(BuildContext context)`.

Ela ignora de proposito:

- leituras dentro de `Observer`;
- leituras feitas com `watch(context)`;
- leituras dentro de event handlers ou outros callbacks aninhados no `build`;
- campos nao reativos como `bool isLoading = false`.
