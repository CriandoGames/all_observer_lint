# avoid_effect_creation_in_build

- **Categoria:** lifecycle
- **Severidade:** warning
- **Bloqueante:** não
- **Preset:** `recommended`, `strict`, `all`
- **Quick fix:** não
- **Versão do `all_observer`:** todas as versões que expõem `effect`, `ever`, `once`, `debounce`, `interval`

## O que a regra faz

Sinaliza `effect(...)`, `ever(...)`, `once(...)`, `debounce(...)` e
`interval(...)` registrados diretamente dentro do método `build` de um
widget ou dentro de um callback de `Observer(...)`.

## Motivo

Cada rebuild registraria uma nova subscription. Nenhuma delas está
vinculada ao ciclo de vida do widget quando criada dessa forma, então elas
se acumulam — efeitos colaterais duplicados, eventos de analytics
duplicados, chamadas de rede duplicadas — enquanto o widget continuar
sendo reconstruído.

## Exemplo incorreto

```dart
Widget build(BuildContext context) {
  effect(() {
    analytics.track(counter.value);
  });
  return Text('${counter.value}');
}
```

## Exemplo correto

```dart
class _PageState extends State<Page> {
  late final Disposer _tracker = effect(() {
    analytics.track(counter.value);
  });

  @override
  void dispose() {
    _tracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('${counter.value}');
}
```

## Exceções

Registros dentro de um closure aninhado que não é, ele mesmo, um escopo de
rebuild (por exemplo, `onPressed: () { ever(...); }`) não são sinalizados.

## Limitações

Registro indireto por meio de uma função auxiliar chamada a partir do
`build` não é detectado nesta versão.

## Como desativar

```yaml
custom_lint:
  rules:
    - avoid_effect_creation_in_build: false
```

## Evidência

Severidade `warning`; sem alegação de bloqueio, sem documento de evidência
exigido.
