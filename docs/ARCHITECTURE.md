# Arquitetura

## Objetivo

O CDR QuickLook fornece miniaturas e previews de documentos CorelDRAW no
Finder sem interpretar ou modificar o conteúdo vetorial. Ele reaproveita as
imagens de preview que o próprio CorelDRAW grava no arquivo.

## Fluxo de execução

```text
Finder
├── pedido de miniatura → CDRThumbnail.appex → ImageIO → imagem com badge CDR
└── barra de espaço    → CDRPreview.appex   → PDFKit → páginas roláveis
                                  ↓
                             CDRArchive
                 ZIP moderno ou busca raster limitada
                                  ↓
                previews/thumbnail.png e previews/pageN.png
```

O aplicativo host registra e habilita as extensões com `pluginkit`, limpa o
cache do Quick Look e reinicia o Finder. Depois disso, a renderização ocorre
nos processos isolados das extensões do macOS.

## Componentes

- `Sources/Common/CDRArchive.*`: valida o contêiner, localiza as imagens e
  descompacta entradas ZIP armazenadas ou deflate.
- `Sources/Thumbnail/ThumbnailProvider.m`: decodifica a miniatura com ImageIO,
  preserva a proporção e adiciona o badge `CDR`.
- `Sources/Preview/PreviewProvider.m`: converte as imagens incorporadas em um
  `PDFDocument` em memória, exibido verticalmente por PDFKit. A janela inicial
  preferida é 1000 × 760 pontos.
- `Sources/Host/main.m`: registra as duas extensões e oferece instalação
  interativa ou `--headless-install`.
- `Resources/*.plist`: declara os bundles, os identificadores e a associação
  com a extensão `.cdr`.

## Reconhecimento de arquivos

A extensão `.cdr` também é usada pelo macOS para imagens de disco de CD/DVD.
Por isso, a extensão não assume que todo arquivo com esse sufixo é CorelDRAW:
ela exige um contêiner reconhecido com uma imagem PNG/JPEG incorporada. Um
arquivo sem preview compatível é rejeitado em vez de ser exibido incorretamente.

Para CDR modernos, o leitor usa o diretório central ZIP e procura:

- `previews/thumbnail.png`;
- `previews/page1.png`, `previews/page2.png`, etc.

Quando essa estrutura não está presente, há uma busca limitada por uma imagem
raster incorporada. Essa compatibilidade de fallback não equivale a interpretar
as estruturas vetoriais proprietárias do CDR.

## Limites de segurança e desempenho

- leitura somente local; não há rede, telemetria ou alteração do documento;
- dados do arquivo são mapeados quando possível;
- offsets e tamanhos são validados antes de cada leitura;
- uma imagem incorporada pode ter no máximo 64 MiB descompactados;
- ZIP64 e métodos de compressão diferentes de stored/deflate são recusados;
- o preview renderiza no máximo 512 páginas;
- a preparação multipágina ocorre fora da thread principal;
- as extensões usam App Sandbox com acesso somente ao arquivo selecionado.

## Decisões de escopo

O projeto não pretende substituir o CorelDRAW, editar documentos ou reconstruir
vetores. Um renderizador completo exigiria cobrir muitas versões de um formato
proprietário e aumentaria bastante a superfície de segurança dentro do Quick
Look. O caminho preferido é ampliar a compatibilidade com previews incorporados
de forma mensurável e limitada.
