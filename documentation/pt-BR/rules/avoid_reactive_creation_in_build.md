# avoid_reactive_creation_in_build

- **Categoria:** lifecycle
- **Severidade:** warning
- **Bloqueante:** não
- **Preset:** `recommended`, `strict`, `all`
- **Quick fix:** não (o destino correto é ambíguo; ver "Limitações")
- **Versão do `all_observer`:** todas as versões compatíveis com a superfície de API descrita neste projeto (`Observable`, `.obs`, `Computed`, `ObservableFuture`, `ObservableStream`)

## O que a regra faz

Sinaliza `Observable`, `.obs`, `Computed`, `ObservableFuture` e
`ObservableStream` criados diretamente dentro do método `build(BuildContext)`
de um widget, ou dentro de um callback de `Observer(...)`.

## Motivo

Tanto `build` quanto o callback de `Observer` são reexecutados a cada
rebuild/notificação. Um recurso reativo criado ali é uma instância nova a
cada execução — qualquer estado que ele guardava, e qualquer listener
associado à instância anterior, é descartado silenciosamente.

## Exemplo incorreto

```dart
Widget build(BuildContext context) {
  final count = 0.obs;
  return Text('${count.value}');
}
```

```dart
Widget build(BuildContext context) {
  final total = Computed(() => price.value * quantity.value);
  return Observer(() => Text('${total.value}'));
}
```

## Exemplo correto

```dart
class _CounterState extends State<Counter> {
  final count = 0.obs;

  @override
  Widget build(BuildContext context) {
    return Observer(() => Text('${count.value}'));
  }
}
```

## Exceções conhecidas (sem falso positivo)

- Recursos reativos criados dentro de um closure aninhado que não é, ele
  mesmo, um escopo de rebuild (por exemplo, `onPressed` de um botão) não
  são sinalizados — esse closure só executa em resposta à interação, não a
  cada rebuild.
- Símbolos chamados `Observable`, `Computed` etc. vindos de outro pacote
  nunca são sinalizados (a identificação usa a URI da biblioteca resolvida,
  nunca apenas o nome textual).

## Limitações

- A detecção cobre apenas as formas diretas acima (chamadas de construtor
  e `.obs`); criação escondida atrás de uma função fábrica/auxiliar não é
  detectada nesta versão.
- A regra ainda não diferencia `StatelessWidget.build` de outros métodos
  com assinatura idêntica declarados fora do Flutter; ver
  `documentation/false_positives.md`.

## Como desativar

```yaml
custom_lint:
  rules:
    - avoid_reactive_creation_in_build: false
```

## Evidência

Nenhuma alegação de bloqueio é feita aqui (severidade `warning`), portanto
não é exigido um documento em `documentation/evidence/` pela política deste
projeto — ver `documentation/backlog.md` para os critérios de promoção
caso esta regra venha a ser proposta como `error`.
