# prefer_batch_for_multiple_related_writes

- **Categoria:** performance
- **Severidade:** info
- **Bloqueante:** não
- **Preset:** `strict`, `all` (não está em `recommended`)
- **Quick fix:** sim - envolve as escritas consecutivas em `Observable.batch`
- **Versão do `all_observer`:** qualquer versão que exponha `Observable.batch`
- **Status:** experimental

## O que a regra faz

Sinaliza três ou mais atribuições simples e consecutivas a `.value` em
observáveis diferentes dentro do mesmo bloco, ainda não envolvidas em
`Observable.batch(...)`.

## Motivo

O `all_observer` já coalesce notificações síncronas por conta própria, então
esta não é uma alegação de correção. É uma sugestão para os casos em que
listeners externos/manuais, ou código fora do batching próprio do
`all_observer`, poderiam observar um estado intermediário inconsistente no
meio de uma atualização de múltiplos campos.

## Exemplo incorreto

```dart
void reset() {
  name.value = '';
  email.value = '';
  age.value = 0;
}
```

## Exemplo sugerido

```dart
void reset() {
  Observable.batch(() {
    name.value = '';
    email.value = '';
    age.value = 0;
  });
}
```

## Quick fix

O quick fix envolve as escritas consecutivas detectadas em
`Observable.batch`.

## Exceções

Duas escritas consecutivas não são sinalizadas. O limiar foi deliberadamente
definido em três para evitar empurrar todo par de escritas relacionadas para
dentro de `Observable.batch`.

## Limitações

Esta regra não tenta avaliar se algum listener de fato observa um estado
intermediário inconsistente; ela apenas conta escritas simples consecutivas.
Não está incluída em `recommended` porque o coalescimento próprio do
`all_observer` já cobre o caso comum, e sugestões indiscriminadas de
`Observable.batch` foram explicitamente descartadas pelo briefing deste
projeto.

## Como desativar

```yaml
custom_lint:
  rules:
    - prefer_batch_for_multiple_related_writes: false
```

## Evidência

Severidade `info`; uma sugestão, não uma alegação de bug. Nenhum documento
de evidência é exigido.
