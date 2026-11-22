/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Parametro]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Parâmetros de fábrica da base SIS. Só insere o que falta
                (PADRAO_SQL regra 39): valor já alterado pelo administrador
                nunca é sobrescrito. VALOR_PADRAO recebe o mesmo valor de
                fábrica. Cada etapa seguinte acrescenta os seus parâmetros
                (multa, juros, régua de cobrança...) neste arquivo.
                EDITAVEL_ADMIN = 0: só o instalador muda, por script.
                Depende de Carga_SIS_Modulo.sql.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
    v1.1 (15/11/2026) - Etapa 02b: SENHA_PBKDF2_ITERACOES.
    v1.2 (15/11/2026) - Identidade visual por cliente: pasta, logomarcas e
                        cores (valores de fábrica = CMJ).
    v1.3 (16/11/2026) - Etapa 02d: e-mail (domínio interno, minutos preso),
                        pastas de backup e de atualizações.
    v1.4 (17/11/2026) - Etapa 03c: EMAIL_LOCAL_LIBERADOS (exceção controlada do
                        banco de teste, pedido do Celso) e SISTEMA_NOME
                        (nome do sistema por cliente, pedido do Celso: SisCMJ);
                        EMAIL_LOGO_MODO, EMAIL_LOGO_ENDERECO e
                        EMAIL_LOGO_NOME_ARQUIVO (como a logomarca vai no e-mail).
    v1.5 (20/11/2026) - Etapa 03d: EMAIL_RODAPE_CNPJ (CNPJ no rodapé dos e-mails
                        a clientes e terceiros; fábrica N, pedido do Celso).
    v1.6 (20/11/2026) - Etapa 03d: LOGIN_COMPUTADOR_TENTATIVAS e
                        LOGIN_COMPUTADOR_MINUTOS (limite de tentativas por computador).
    v1.7 (20/11/2026) - Etapa 03d: BACKUP_DIAS_MANTER, BACKUP_NUVEM_MANTER e os
                        avisos de atraso (BACKUP_HORAS_ALERTA_COMPLETO/_LOG,
                        BACKUP_DIAS_ALERTA_TESTE).
    v1.8 (20/11/2026) - Etapa 03d2: BACKUP_RESTAURACAO_MOTIVO_MINIMO (restauração
                        pela tela).
    v1.9 (22/11/2026) - Etapa 04a: SENHA_PROVISORIA_PADRAO e SENHA_PROVISORIA_HORAS
                        (botão Reiniciar senha da tela de Usuários; decisão do
                        Celso de 16/11/2026, PADRAO_TELAS regra 13).
    v2.0 (22/11/2026) - Etapa 04b (P20): LIXEIRA_ATIVA, LIXEIRA_DIAS_GUARDA (90),
                        LIXEIRA_AVISO_DIAS, LIXEIRA_AVISO_GRUPO e
                        LIXEIRA_LIMPEZA_ATIVA.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Parametro (CHAVE, VALOR, VALOR_PADRAO, TIPO, DESCRICAO, ID_MODULO, EDITAVEL_ADMIN)
SELECT v.CHAVE, v.VALOR, v.VALOR, v.TIPO, v.DESCRICAO, m.ID_MODULO, v.EDITAVEL_ADMIN
FROM (VALUES
        (CAST('EMAIL_TESTE' AS VARCHAR(60)), CAST(N'celsofreitas62@gmail.com' AS NVARCHAR(4000)), CAST('EMAIL' AS VARCHAR(10)),
         CAST(N'Endereço que recebe TODOS os e-mails quando o sistema roda em modo teste (banco _LOCAL).' AS NVARCHAR(400)), CAST('SIS' AS VARCHAR(10)), CAST(0 AS BIT)),
        ('EMAIL_ADMIN_ALERTA', N'', 'EMAIL',
         N'Endereço que recebe os alertas técnicos (falha no envio de e-mail, rotina com erro). Vazio = sem alerta.', 'SIS', 1),
        ('EMAIL_TENTATIVAS_MAX', N'5', 'INTEIRO',
         N'Quantas vezes o serviço tenta reenviar um e-mail com falha temporária antes de desistir.', 'SIS', 1),
        ('SENHA_TAMANHO_MINIMO', N'8', 'INTEIRO',
         N'Quantidade mínima de caracteres da senha dos usuários.', 'SIS', 1),
        ('SENHA_TENTATIVAS_BLOQUEIO', N'5', 'INTEIRO',
         N'Tentativas de senha errada seguidas até o usuário ser bloqueado.', 'SIS', 1),
        ('LOGIN_COMPUTADOR_TENTATIVAS', N'10', 'INTEIRO',
         N'Tentativas de login erradas seguidas, de um mesmo computador (com qualquer usuário), até ele ficar em espera. Mínimo 5.', 'SIS', 1),
        ('LOGIN_COMPUTADOR_MINUTOS', N'15', 'INTEIRO',
         N'Minutos que o computador fica em espera depois de errar o login demais, e janela de contagem das tentativas.', 'SIS', 1),
        ('SESSAO_MINUTOS_INATIVIDADE', N'30', 'INTEIRO',
         N'Minutos sem uso até a sessão expirar e pedir login de novo.', 'SIS', 1),
        ('ANEXO_PASTA_RAIZ', N'C:\SistemaCMJ_Arquivos\Anexos', 'TEXTO',
         N'Pasta do servidor onde os anexos são gravados (o banco guarda só a referência).', 'SIS', 0),
        ('ANEXO_TAMANHO_MAX_MB', N'20', 'INTEIRO',
         N'Tamanho máximo de cada anexo, em MB.', 'SIS', 1),
        ('LOG_PASSO_DIAS_RETENCAO', N'90', 'INTEIRO',
         N'Dias que o log passo a passo das rotinas é guardado (mínimo 7). O log de erros não é apagado.', 'SIS', 1),
        ('SENHA_PBKDF2_ITERACOES', N'600000', 'INTEIRO',
         N'Iterações do PBKDF2-SHA256 usadas pela API ao gravar senha (mínimo aceito: 100000).', 'SIS', 0),
        ('IDENTIDADE_PASTA', N'C:\SistemaCMJ_Arquivos\Identidade', 'TEXTO',
         N'Pasta do servidor com os arquivos de identidade visual do cliente (logomarcas).', 'SIS', 0),
        ('EMPRESA_LOGO', N'logo.png', 'ARQUIVO',
         N'Logomarca vertical completa (documentos, contratos, telas grandes). Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_LOGO_HORIZONTAL', N'logo_horizontal.png', 'ARQUIVO',
         N'Logomarca horizontal (cabeçalho do sistema e dos relatórios). Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_LOGO_EMAIL', N'logo_email.png', 'ARQUIVO',
         N'Logomarca pequena do cabeçalho dos e-mails. Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_LOGO_SIMBOLO', N'logo_simbolo.png', 'ARQUIVO',
         N'Só o símbolo da logomarca (menu recolhido, ícone). Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_COR_PRINCIPAL', N'#D43414', 'COR',
         N'Cor principal do cliente: cabeçalhos do sistema, dos relatórios e dos e-mails informativos.', 'SIS', 1),
        ('EMPRESA_COR_SECUNDARIA', N'#A8A8A8', 'COR',
         N'Cor secundária do cliente (detalhes, linhas, textos de apoio).', 'SIS', 1),
        ('EMAIL_COR_ALERTA', N'#E65100', 'COR',
         N'Cor dos avisos de alerta (vencido, falha, divergência). Diferente da cor principal.', 'SIS', 1),
        ('EMAIL_COR_SUCESSO', N'#2E7D32', 'COR',
         N'Cor das confirmações (pagamento recebido, envio concluído).', 'SIS', 1),
        ('EMAIL_DOMINIO_INTERNO', N'', 'TEXTO',
         N'Domínio(s) do e-mail da empresa (ex.: cmj.com.br), separados por vírgula. Esses endereços saem pela conta interna; os demais pela externa. Vazio = todos pela interna.', 'SIS', 1),
        ('SISTEMA_NOME', N'SisCMJ', 'TEXTO',
         N'Nome do sistema mostrado nas telas, nos e-mails (rodapé e remetente) e nos relatórios. Só o administrador geral altera.', 'SIS', 0),
        ('EMAIL_LOGO_MODO', N'EMBUTIDA', 'TEXTO',
         N'Logomarca nos e-mails: EMBUTIDA (vai dentro do e-mail), ENDERECO (puxada do endereço público EMAIL_LOGO_ENDERECO, não aparece como anexo) ou SEM_IMAGEM (só a faixa colorida).', 'SIS', 0),
        ('EMAIL_LOGO_ENDERECO', N'', 'TEXTO',
         N'Endereço público (https://...) da logomarca, usado quando EMAIL_LOGO_MODO = ENDERECO.', 'SIS', 0),
        ('EMAIL_LOGO_NOME_ARQUIVO', N'CMJ.png', 'TEXTO',
         N'Nome com que a logomarca embutida aparece para quem recebe o e-mail (ex.: CMJ.png).', 'SIS', 0),
        ('EMAIL_LOCAL_LIBERADOS', N'', 'TEXTO',
         N'Só no banco de teste (_LOCAL): tipos de e-mail que saem para os destinatários reais em vez de irem para o EMAIL_TESTE, separados por vírgula (ex.: COMUNICADO). Vazio = todos desviados. Não tem efeito em produção.', 'SIS', 0),
        ('EMAIL_MINUTOS_PRESO', N'15', 'INTEIRO',
         N'Minutos que um e-mail pode ficar "processando" antes de voltar para a fila (serviço parou no meio). Mínimo 5.', 'SIS', 1),
        ('BACKUP_PASTA', N'C:\SistemaCMJ_Arquivos\Backup', 'TEXTO',
         N'Pasta do servidor onde ficam os backups do banco.', 'SIS', 0),
        ('BACKUP_PASTA_EXTERNA', N'', 'TEXTO',
         N'Pasta fora do servidor (disco externo ou pasta sincronizada com a nuvem) para onde os backups são copiados. Vazio = não copia.', 'SIS', 0),
        ('BACKUP_DIAS_MANTER', N'7', 'INTEIRO',
         N'Dias de backup guardados na pasta do servidor (completos e do log); os mais antigos são apagados.', 'SIS', 0),
        ('BACKUP_NUVEM_MANTER', N'1', 'INTEIRO',
         N'Quantos backups completos ficam na pasta da nuvem (BACKUP_PASTA_EXTERNA). 0 = não copia.', 'SIS', 0),
        ('BACKUP_HORAS_ALERTA_COMPLETO', N'26', 'INTEIRO',
         N'Avisa por e-mail se o último backup completo sem erro tiver mais horas que isto.', 'SIS', 0),
        ('BACKUP_HORAS_ALERTA_LOG', N'3', 'INTEIRO',
         N'Avisa por e-mail se o último backup do log (de hora em hora) sem erro tiver mais horas que isto.', 'SIS', 0),
        ('BACKUP_DIAS_ALERTA_TESTE', N'8', 'INTEIRO',
         N'Avisa por e-mail se o último teste de restauração sem erro tiver mais dias que isto.', 'SIS', 0),
        ('BACKUP_RESTAURACAO_MOTIVO_MINIMO', N'10', 'INTEIRO',
         N'Quantidade mínima de letras do motivo obrigatório ao pedir uma restauração de backup pela tela.', 'SIS', 0),
        ('ATUALIZACAO_PASTA', N'C:\SistemaCMJ_Arquivos\Atualizacoes', 'TEXTO',
         N'Pasta do servidor onde ficam os pacotes de atualização e o certificado usados pela tela Instalação e manutenção.', 'SIS', 0),
        ('EMAIL_RODAPE_CNPJ', N'N', 'SN',
         N'Mostrar o CNPJ da empresa no rodapé dos e-mails enviados a clientes e terceiros (S/N).', 'SIS', 1),
        ('CIDADE_PADRAO', N'Poços de Caldas', 'TEXTO',
         N'Cidade sugerida nos cadastros e nos documentos.', 'CAD', 1),
        ('SENHA_PROVISORIA_PADRAO', N'@12345', 'TEXTO',
         N'Senha provisória dada pelo botão Reiniciar senha da tela de Usuários. O usuário é obrigado a trocá-la no primeiro acesso.', 'SIS', 0),
        ('SENHA_PROVISORIA_HORAS', N'24', 'INTEIRO',
         N'Horas que a senha provisória vale. Passado esse tempo sem o usuário trocar, o login recusa e é preciso reiniciar a senha de novo. 0 = não vence. Não vale para o administrador geral.', 'SIS', 1),
        ('LIXEIRA_ATIVA', N'S', 'SN',
         N'S = o botão Excluir das telas manda o registro para a lixeira (recuperável). N = a lixeira fica desligada e só é possível desativar.', 'SIS', 1),
        ('LIXEIRA_DIAS_GUARDA', N'90', 'INTEIRO',
         N'Dias que um registro excluído fica na lixeira antes de ser apagado de vez (mínimo 1). Cada tela pode ter prazo próprio na configuração das tabelas; vazio = vale este.', 'SIS', 1),
        ('LIXEIRA_AVISO_DIAS', N'1', 'INTEIRO',
         N'Com quantos dias de antecedência o e-mail avisa o que será apagado de vez da lixeira. 0 = sem aviso.', 'SIS', 1),
        ('LIXEIRA_AVISO_GRUPO', N'LIXEIRA_AVISO', 'TEXTO',
         N'Grupo de e-mail que recebe o aviso do que será apagado da lixeira (tela Grupos de e-mail).', 'SIS', 1),
        ('LIXEIRA_LIMPEZA_ATIVA', N'S', 'SN',
         N'S = a rotina diária apaga de vez o que passou do prazo da lixeira. N = nada é apagado (o aviso continua saindo).', 'SIS', 1)
     ) v (CHAVE, VALOR, TIPO, DESCRICAO, MODULO, EDITAVEL_ADMIN)
INNER JOIN SIS.Modulo m ON m.CODIGO = v.MODULO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Parametro p WHERE p.CHAVE = v.CHAVE);
GO
