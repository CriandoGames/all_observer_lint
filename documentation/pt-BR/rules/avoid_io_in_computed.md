# avoid_io_in_computed

- **Categoria:** purity / async
- **Severidade:** warning
- **Bloqueante:** não
- **Preset:** `recommended`, `all`
- **Quick fix:** não
- **Versão do `all_observer`:** qualquer versão

## O que a regra faz

Sinaliza I/O óbvio dentro de um callback de derivação de `Computed`:
expressões `await`, e chamadas/construtores resolvidos para `dart:io`
(`File`, `Socket`, `HttpClient` etc.).

## Motivo

`Computed` deve ser uma derivação síncrona, barata e repetível. I/O ali
dentro pode executar com muito mais frequência do que o pretendido (uma
vez por reavaliação de dependência) e bloqueia o grafo reativo enquanto
isso acontece.

## Exemplo incorreto

```dart
late final exists = Computed(() => File(path.value).existsSync());

late final data = Computed(() async {
  await Future<void>.delayed(Duration.zero);
  return path.value;
});
```

## Exemplo correto

Use `ObservableFuture`/`ObservableStream` para trabalho assíncrono, e
mantenha `Computed` limitado a derivar valores reativos já carregados.

## Exceções

Este é um detector best-effort e restrito, não um verificador geral de
pureza: ele deliberadamente não sinaliza chamadas para pacotes arbitrários
de terceiros de rede/banco de dados, para evitar falsos positivos de um
registro de "APIs de I/O conhecidas" que inevitavelmente estaria
incompleto ou incorreto para algum projeto.

## Limitações

- Apenas `dart:io` e `await` são reconhecidos; pacotes de cliente HTTP,
  platform channels e similares não são detectados nesta versão (ver
  `documentation/backlog.md`).
- Chamadas síncronas e bloqueantes que não sejam `dart:io` (por exemplo,
  trabalho pesado de CPU) estão fora do escopo desta regra.

## Como desativar

```yaml
custom_lint:
  rules:
    - avoid_io_in_computed: false
```

## Evidência

Severidade `warning`; sem alegação de bloqueio, sem documento de evidência
exigido.
