# CDR QuickLook

Preview e miniaturas de documentos CorelDRAW (`.cdr`) diretamente no Finder do
macOS — sem abrir o CorelDRAW.

## Recursos

- Miniaturas de arquivos CDR no Finder.
- Quick Look pela barra de espaço.
- Documentos com várias páginas em uma visualização rolável.
- Janela inicial ampla, semelhante ao preview de PDFs.
- Processamento totalmente local e offline.
- Aplicativo universal para Apple Silicon e Macs Intel.

## Requisitos

- macOS 12.4 ou posterior.
- Um CDR que contenha a imagem de preview incorporada pelo CorelDRAW.

O CorelDRAW não precisa estar aberto. Ele continua sendo o aplicativo padrão
para editar os documentos.

## Instalação

1. Baixe o DMG na página de
   [Releases](https://github.com/abraaobat/CDR-QuickLook/releases/latest).
2. Abra o DMG e arraste **CDR QuickLook.app** para **Applications**.
3. Abra o aplicativo uma vez para registrar as extensões.
4. Selecione um `.cdr` no Finder e pressione a barra de espaço.

### Aviso do Gatekeeper

A compilação pública é assinada ad-hoc, mas ainda não é notarizada pela Apple.
Se o macOS bloquear a primeira abertura, clique com o botão direito em
**CDR QuickLook.app**, escolha **Abrir** e confirme.

## Como funciona

Arquivos CDR modernos são contêineres ZIP que normalmente incluem
`previews/thumbnail.png` e `previews/pageN.png`. O aplicativo lê apenas essas
imagens incorporadas; o conteúdo do documento nunca é alterado.

O macOS também usa `.cdr` para imagens de disco CD/DVD e classifica essa
extensão como `com.apple.disk-image-cdr`. As extensões verificam a estrutura do
arquivo antes de gerar qualquer preview, distinguindo documentos CorelDRAW de
imagens de disco.

## Compilar

Não é necessário instalar o Xcode completo. As Command Line Tools bastam:

```sh
git clone https://github.com/abraaobat/CDR-QuickLook.git
cd CDR-QuickLook
./build.sh
```

Os artefatos universais são gerados em `dist/`:

- `CDR QuickLook.app`
- `CDR-QuickLook-<versão>.dmg`
- `CDR-QuickLook-<versão>.zip`

## Limitações

- A resolução é a da imagem incorporada pelo CorelDRAW.
- Arquivos antigos sem PNG ou JPEG incorporado não podem ser renderizados sem
  um interpretador completo do formato CDR.
- A prévia multipágina é limitada a 512 páginas para manter o Finder responsivo.

## Licença

[MIT](LICENSE)

---

## English

CDR QuickLook adds Finder thumbnails and spacebar previews for CorelDRAW
documents on macOS. It supports multipage files, works offline, and ships as a
universal Apple Silicon/Intel app. Download the DMG from
[Releases](https://github.com/abraaobat/CDR-QuickLook/releases/latest), drag the
app to Applications, and launch it once to register the extensions.
