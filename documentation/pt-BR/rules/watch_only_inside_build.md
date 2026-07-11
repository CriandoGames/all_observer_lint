# watch_only_inside_build

- **Categoria:** widget-lifecycle
- **Severidade:** warning
- **Bloqueante:** não
- **Preset:** `recommended`, `strict`, `all`
- **Quick fix:** não
- **Versão do `all_observer`:** todas as versões que expõem `watch(context)`

## O que a regra faz

Sinaliza chamadas de `watch(context)` feitas fora de um contexto de build
de widget reconhecido (um método `build(BuildContext)` ou um callback de
`Observer`).

## Motivo

`watch(context)` vincula uma leitura reativa ao ciclo de rebuild do widget,
registrando-se na árvore de elementos. Chamá-lo fora de um contexto de
build não faz o que parece fazer — não existe rebuild ao qual vincular a
leitura.

## Exemplo incorreto

```dart
class _PageState extends State<Page> {
  void submit() {
    final value = counter.watch(context); // chamado fora do build
    print(value);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: submit, child: const Text('enviar'));
  }
}
```

## Exemplo correto

```dart
@override
Widget build(BuildContext context) {
  return Text('${counter.watch(context)}');
}
```

Se precisar do valor fora do build, leia `counter.value` diretamente, ou
use um `effect`/listener explícito em vez de `watch`.

## Exceções

Esta regra é deliberadamente conservadora. Ela permanece silenciosa sempre
que não consegue provar o escopo envolvente: um método auxiliar que também
aceita um parâmetro `BuildContext` é tratado como ambíguo (poderia
legitimamente só ser chamado a partir do build) e não é sinalizado.

## Limitações

Chamadas feitas a partir de funções/closures locais ou de nível superior
não são analisadas (também tratadas como ambíguas) nesta versão.

## Como desativar

```yaml
custom_lint:
  rules:
    - watch_only_inside_build: false
```

## Evidência

Severidade `warning`; sem alegação de bloqueio, sem documento de evidência
exigido.
