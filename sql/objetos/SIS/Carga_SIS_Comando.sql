/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Comando]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Botões da tela "Instalação e manutenção" (pedidos 2 e 4 do
                Celso). Só insere o que falta; nome, descrição, grupo, ordem
                e as marcas PERIGOSO / ACEITA_PARAMETRO são acertados também
                em comando já existente (comandos só mudam por carga).
                O que cada CODIGO faz de verdade fica na lista fixa do
                serviço (fase 3, API/serviço); código sem tratamento no
                serviço termina em ERRO "comando não disponível nesta
                versão".
                A primeira instalação (SQL Server Express, .NET e o próprio
                serviço) é feita pelo instalador único, rodado uma vez como
                administrador do Windows; daí em diante, tudo por aqui.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaComando;

SELECT v.CODIGO, v.NOME, v.DESCRICAO, v.GRUPO, v.ORDEM, v.PERIGOSO, v.ACEITA, v.PARAM_DESC
INTO #CargaComando
FROM (VALUES
        (CAST('PASTAS_CRIAR' AS VARCHAR(40)), CAST(N'Criar as pastas do sistema' AS NVARCHAR(80)),
         CAST(N'Cria (se faltar) as pastas de anexos, identidade visual, backup e atualizações dos parâmetros, com as permissões do serviço.' AS NVARCHAR(1000)),
         CAST('INSTALACAO' AS VARCHAR(20)), CAST(10 AS SMALLINT), CAST(0 AS BIT), CAST(0 AS BIT), CAST(N'' AS NVARCHAR(200))),
        ('FIREWALL_LIBERAR', N'Liberar o sistema no firewall',
         N'Cria a regra do Firewall do Windows para a porta do sistema, só para a rede interna.', 'INSTALACAO', 20, 1, 0, N''),
        ('CERTIFICADO_HTTPS', N'Instalar ou renovar o certificado HTTPS',
         N'Instala o certificado (.pfx) usado pelo endereço seguro do sistema e reinicia o serviço.', 'INSTALACAO', 30, 1, 1,
         N'Nome do arquivo .pfx na pasta de atualizações'),
        ('SERVICO_INSTALAR', N'Reinstalar o serviço do sistema',
         N'Registra de novo o serviço do Windows do SistemaCMJ (início automático e recuperação em falha).', 'INSTALACAO', 40, 1, 0, N''),
        ('ATUALIZACAO_BANCO', N'Aplicar atualização do banco',
         N'Faz backup e depois roda o pacote de atualização do banco (.sql) que está na pasta de atualizações.', 'ATUALIZACAO', 10, 1, 1,
         N'Nome do arquivo .sql na pasta de atualizações'),
        ('ATUALIZACAO_SISTEMA', N'Atualizar o sistema (telas e API)',
         N'Para o serviço, troca os arquivos do sistema pelo pacote (.zip) da pasta de atualizações, guardando a versão anterior, e inicia o serviço.', 'ATUALIZACAO', 20, 1, 1,
         N'Nome do arquivo .zip na pasta de atualizações'),
        ('BACKUP_AGORA', N'Fazer backup agora',
         N'Backup completo do banco na pasta de backup, com conferência (RESTORE VERIFYONLY).', 'BACKUP', 10, 0, 0, N''),
        ('BACKUP_TESTAR', N'Testar a restauração do último backup',
         N'Restaura o último backup num banco de teste separado, confere e apaga o banco de teste. O banco em uso não é tocado.', 'BACKUP', 20, 0, 0, N''),
        ('BACKUP_COPIAR', N'Copiar backups para fora do servidor',
         N'Copia os backups para a pasta externa configurada (disco externo ou pasta sincronizada com a nuvem).', 'BACKUP', 30, 0, 0, N''),
        ('SERVICO_SITUACAO', N'Ver situação do serviço',
         N'Mostra se o serviço está rodando, desde quando, a versão e a última volta da fila de e-mails e das rotinas.', 'SERVICO', 10, 0, 0, N''),
        ('SERVICO_REINICIAR', N'Reiniciar o serviço do sistema',
         N'Reinicia o serviço do SistemaCMJ. Os usuários conectados perdem a tela aberta por alguns segundos.', 'SERVICO', 20, 1, 0, N''),
        ('BANCO_VERIFICAR', N'Verificar a integridade do banco',
         N'Roda o DBCC CHECKDB e mostra o resultado.', 'DIAGNOSTICO', 10, 0, 0, N''),
        ('DISCO_ESPACO', N'Espaço em disco do servidor',
         N'Mostra o espaço livre dos discos e o tamanho do banco, dos anexos e dos backups.', 'DIAGNOSTICO', 20, 0, 0, N''),
        ('LOG_SERVICO_VER', N'Ver o log do serviço',
         N'Mostra as últimas linhas do log do serviço do sistema (sem senhas).', 'DIAGNOSTICO', 30, 0, 0, N'')
     ) v (CODIGO, NOME, DESCRICAO, GRUPO, ORDEM, PERIGOSO, ACEITA, PARAM_DESC);

INSERT INTO SIS.Comando (CODIGO, NOME, DESCRICAO, GRUPO, ORDEM, PERIGOSO, ACEITA_PARAMETRO, PARAMETRO_DESCRICAO, USUARIO_CRIACAO)
SELECT c.CODIGO, c.NOME, c.DESCRICAO, c.GRUPO, c.ORDEM, c.PERIGOSO, c.ACEITA, c.PARAM_DESC, N'instalacao'
FROM #CargaComando c
WHERE NOT EXISTS (SELECT 1 FROM SIS.Comando x WHERE x.CODIGO = c.CODIGO);

UPDATE x
   SET x.NOME = c.NOME, x.DESCRICAO = c.DESCRICAO, x.GRUPO = c.GRUPO, x.ORDEM = c.ORDEM,
       x.PERIGOSO = c.PERIGOSO, x.ACEITA_PARAMETRO = c.ACEITA, x.PARAMETRO_DESCRICAO = c.PARAM_DESC,
       x.DT_ALTERACAO = SYSDATETIME(), x.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Comando x
INNER JOIN #CargaComando c ON c.CODIGO = x.CODIGO
WHERE x.NOME <> c.NOME COLLATE Latin1_General_BIN2 OR x.DESCRICAO <> c.DESCRICAO COLLATE Latin1_General_BIN2
   OR x.GRUPO <> c.GRUPO OR x.ORDEM <> c.ORDEM OR x.PERIGOSO <> c.PERIGOSO OR x.ACEITA_PARAMETRO <> c.ACEITA
   OR x.PARAMETRO_DESCRICAO <> c.PARAM_DESC COLLATE Latin1_General_BIN2;

DROP TABLE IF EXISTS #CargaComando;
GO
