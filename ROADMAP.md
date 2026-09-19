# Roadmap

O roadmap é orientado por evidência: compatibilidade só é marcada como concluída
depois de validada com arquivos reais e regressões automatizadas. Datas não são
prometidas; cada fase termina com um critério verificável.

## F0 — Pesquisa e prova de formato — concluída

- confirmar que CDR modernos carregam previews raster no contêiner;
- distinguir documentos CorelDRAW de imagens de disco `.cdr`;
- provar extração local sem CorelDRAW.

## F1 — Núcleo de extração segura — concluída

- leitura limitada do diretório central ZIP;
- suporte stored/deflate e fallback raster;
- validação de offsets, tamanhos e corrupção;
- limites de memória e de páginas.

## F2 — Integração com o Finder — concluída

- extensão de miniaturas;
- extensão Quick Look;
- registro automático via aplicativo host;
- build universal Apple Silicon/Intel.

## F3 — Experiência multipágina e distribuição inicial — concluída

- visualização vertical com PDFKit;
- preparação assíncrona;
- janela inicial 1000 × 760 e redimensionável;
- DMG/ZIP, GitHub Release e CI.

## F4 — Qualidade de distribuição — ativa

- montar corpus público ou redistribuível de compatibilidade por versão do CDR;
- adicionar testes determinísticos do parser, corrupção e limites;
- validar instalação limpa nas versões suportadas do macOS;
- assinar com Developer ID e notarizar o DMG;
- documentar matriz de compatibilidade e regressões conhecidas.

Critério de saída: release notarizada, suíte de regressão no CI e matriz de
compatibilidade baseada em arquivos reais.

## F5 — Cobertura e desempenho — futura

- medir prevalência e valor de ZIP64 antes de implementá-lo;
- ampliar nomes/localizações de previews somente com casos reais reproduzíveis;
- avaliar metadados úteis como páginas, dimensões e versão do documento;
- reduzir tempo e memória em documentos grandes;
- investigar CDR legados sem preview, mantendo um parser completo fora de
  escopo até existir uma estratégia sustentável e segura.

Critério de saída: novos formatos cobertos sem regredir imagens de disco,
arquivos inválidos nem responsividade do Finder.

## Princípios para futuras melhorias

- preservar funcionamento offline e privacidade local;
- preferir APIs nativas e zero dependências baixadas em runtime;
- recusar formatos incertos com segurança;
- não transformar o provider do Quick Look em editor ou renderizador vetorial;
- acompanhar o estado machine-readable em `project-status.json`.
