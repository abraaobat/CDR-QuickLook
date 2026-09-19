# Como contribuir

Issues e pull requests são bem-vindos, especialmente quando incluem um caso
reproduzível de compatibilidade com CDR.

## Antes de abrir uma issue

Informe:

- versão do macOS e arquitetura do Mac;
- versão do CDR QuickLook;
- versão aproximada do CorelDRAW que salvou o arquivo;
- resultado de miniatura e de barra de espaço;
- se o problema ocorre depois de `qlmanage -r cache` e `killall Finder`.

Não anexe documentos confidenciais. Se o arquivo puder ser redistribuído,
explique a licença e remova dados pessoais antes de compartilhá-lo.

## Pull requests

1. crie uma branch curta e focada;
2. mantenha o processamento local e os limites documentados em
   `docs/ARCHITECTURE.md`;
3. compile com `./build.sh`;
4. execute as verificações de `docs/DEVELOPMENT.md`;
5. descreva quais amostras e versões do macOS foram validadas;
6. atualize documentação, roadmap e `project-status.json` quando houver mudança
   material de capacidade ou fase.

Mudanças no parser devem tratar todo offset, tamanho e contagem do documento
como entrada não confiável. Não remova limites de segurança apenas para fazer
uma amostra funcionar.

Ao contribuir, você concorda que sua contribuição será licenciada sob a
[licença MIT](LICENSE).
