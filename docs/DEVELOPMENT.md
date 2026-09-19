# Desenvolvimento e diagnóstico

## Ambiente

- macOS 12.4 ou posterior;
- Xcode Command Line Tools;
- ferramentas do sistema: `clang`, `codesign`, `hdiutil`, `ditto` e
  `PlistBuddy`;
- `zlib`, AppKit, PDFKit, ImageIO, QuickLookUI e QuickLookThumbnailing, todos
  fornecidos pelo macOS SDK.

O build não baixa dependências e produz binários universais `arm64` e `x86_64`.

## Compilar

```sh
./build.sh
```

Para escolher outro diretório de saída:

```sh
./build.sh /caminho/para/saida
```

O script recria `build/` e gera em `dist/`:

- `CDR QuickLook.app`;
- `CDR-QuickLook-<versão>.dmg`;
- `CDR-QuickLook-<versão>.zip`;
- `CDR-QuickLook.zip`, alias estável usado pela automação.

## Verificações antes de publicar

```sh
codesign --verify --deep --strict "dist/CDR QuickLook.app"
file "dist/CDR QuickLook.app/Contents/MacOS/CDRQuickLook"
plutil -lint Resources/*.plist
```

Faça ainda uma validação manual com um corpus que inclua:

1. CDR moderno de uma página;
2. CDR moderno multipágina;
3. CDR antigo com raster incorporado;
4. CDR sem preview compatível;
5. imagem de disco `.cdr`, que deve ser recusada;
6. arquivo truncado ou corrompido, que não pode encerrar a extensão.

No Finder, confira miniatura, barra de espaço, rolagem multipágina, tamanho
inicial da janela e redimensionamento.

## Instalação de desenvolvimento

Copie o aplicativo para `/Applications` e abra-o uma vez, ou execute o host em
modo não interativo:

```sh
"/Applications/CDR QuickLook.app/Contents/MacOS/CDRQuickLook" --headless-install
```

Consulte o registro das extensões:

```sh
pluginkit -m -i com.abraaobat.cdrquicklook.preview
pluginkit -m -i com.abraaobat.cdrquicklook.thumbnail
```

## Diagnóstico

Se miniaturas ou previews antigos persistirem:

```sh
qlmanage -r cache
killall Finder
```

Se a extensão não aparecer, abra novamente o aplicativo e confirme os dois
identificadores com `pluginkit`. Se apenas um arquivo falhar, verifique primeiro
se ele contém uma imagem de preview incorporada; a extensão não renderiza o
conteúdo vetorial do documento.

Logs dos processos de Quick Look podem ser vistos no Console.app filtrando por
`cdrquicklook`, ou temporariamente pelo Terminal:

```sh
log stream --predicate 'eventMessage CONTAINS[c] "cdrquicklook"'
```

## Versão e release

A versão pública vem de `CFBundleShortVersionString` em
`Resources/Host-Info.plist`. Antes de criar uma tag:

1. atualize a versão e as notas de release;
2. execute o build e todas as verificações acima;
3. instale o DMG gerado em uma cópia limpa de `/Applications`;
4. teste no Finder com arquivos válidos e inválidos;
5. publique tag e artefatos correspondentes à mesma revisão.

A distribuição atual usa assinatura ad-hoc. Uma release notarizada deverá usar
Developer ID, hardened runtime e o fluxo oficial de notarização da Apple.
