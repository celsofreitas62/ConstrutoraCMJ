/*******************************************************************************
  Objeto      : carga do boletim semanal da implantação
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Grupos de e-mail, comunicado BOLETIM_IMPLANTACAO com os itens
                iniciais aprovados pelo Celso em 17/11/2026, tela Comunicados (menu
                Sistema > E-mails; administrador geral e administrador da CMJ) e a
                rotina COMUNICADO_PREVIA (sexta-feira, 9h). Só insere o que falta
                (regra 39): o que o Celso mudar pela tela não é sobrescrito.
                Destinatários oficiais (17/11/2026): escritório Construtora Marcílio
                Judice e Danielle M. Judice Daher. Aprovação: Celso.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Grupo_Email (CODIGO, NOME, DESCRICAO, USUARIO_CRIACAO)
SELECT v.CODIGO, v.NOME, v.DESCRICAO, N'instalacao'
FROM (VALUES
        (CAST('BOLETIM_IMPLANTACAO' AS VARCHAR(30)), CAST(N'Boletim da implantação' AS NVARCHAR(80)),
         CAST(N'Recebem o boletim semanal do andamento da implantação do SistemaCMJ.' AS NVARCHAR(400))),
        ('BOLETIM_APROVACAO', N'Aprovação do boletim', N'Recebem a prévia do boletim para aprovar antes do envio oficial.')
     ) v (CODIGO, NOME, DESCRICAO)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email g WHERE g.CODIGO = v.CODIGO);
GO

INSERT INTO SIS.Grupo_Email_Destinatario (ID_GRUPO_EMAIL, EMAIL, NOME, USUARIO_CRIACAO)
SELECT g.ID_GRUPO_EMAIL, v.EMAIL, v.NOME, N'instalacao'
FROM (VALUES
        (CAST('BOLETIM_IMPLANTACAO' AS VARCHAR(30)), CAST(N'construtora.m.judice@gmail.com' AS NVARCHAR(256)), CAST(N'Escritório Construtora Marcílio Judice' AS NVARCHAR(100))),
        ('BOLETIM_IMPLANTACAO', N'dmjdaher@gmail.com',       N'Danielle M. Judice Daher'),
        ('BOLETIM_APROVACAO',   N'celsofreitas62@gmail.com', N'Celso de Freitas')
     ) v (GRUPO, EMAIL, NOME)
INNER JOIN SIS.Grupo_Email g ON g.CODIGO = v.GRUPO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email_Destinatario d WHERE d.ID_GRUPO_EMAIL = g.ID_GRUPO_EMAIL AND d.EMAIL = v.EMAIL);
GO

INSERT INTO SIS.Comunicado (CODIGO, TITULO, INTRODUCAO, ID_GRUPO_EMAIL, ID_GRUPO_EMAIL_APROVACAO, EXIGE_APROVACAO, USUARIO_CRIACAO)
SELECT 'BOLETIM_IMPLANTACAO', N'Boletim da implantação do SistemaCMJ',
       N'Segue o resumo semanal do andamento da implantação do novo sistema de gestão da Construtora.',
       g.ID_GRUPO_EMAIL, ga.ID_GRUPO_EMAIL, 1, N'instalacao'
FROM SIS.Grupo_Email g
INNER JOIN SIS.Grupo_Email ga ON ga.CODIGO = 'BOLETIM_APROVACAO'
WHERE g.CODIGO = 'BOLETIM_IMPLANTACAO'
  AND NOT EXISTS (SELECT 1 FROM SIS.Comunicado c WHERE c.CODIGO = 'BOLETIM_IMPLANTACAO');
GO

IF NOT EXISTS (SELECT 1 FROM SIS.Comunicado_Item i INNER JOIN SIS.Comunicado c ON c.ID_COMUNICADO = i.ID_COMUNICADO WHERE c.CODIGO = 'BOLETIM_IMPLANTACAO')
    INSERT INTO SIS.Comunicado_Item (ID_COMUNICADO, SECAO, TEXTO, ORDEM, USUARIO_CRIACAO)
    SELECT c.ID_COMUNICADO, v.SECAO, v.TEXTO, v.ORDEM, N'instalacao'
    FROM (VALUES
            (CAST('IMPLANTADO' AS VARCHAR(15)), CAST(N'Nenhum módulo em uso na empresa ainda. A instalação no servidor da Construtora vem logo depois da fase atual.' AS NVARCHAR(300)), CAST(1 AS SMALLINT)),
            ('EM_TESTE',     N'Entrada no sistema com usuário e senha, e menu.', 1),
            ('EM_TESTE',     N'Cadastro de clientes e fornecedores.', 2),
            ('PROXIMA_FASE', N'Financeiro: contas a pagar e a receber.', 1),
            ('PROXIMA_FASE', N'Preparação da migração dos dados do sistema antigo.', 2)
         ) v (SECAO, TEXTO, ORDEM)
    CROSS JOIN SIS.Comunicado c
    WHERE c.CODIGO = 'BOLETIM_IMPLANTACAO';
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, p.ID_ITEM, 'SIS_COMUNICADO', N'Comunicados', 'TELA', 'sis/comunicados.html', 30, 0, 1,
       'SIS.Comunicado,SIS.Comunicado_Item'
FROM SIS.Modulo m
INNER JOIN SIS.Item p ON p.CODIGO = 'SIS_EMAILS'
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'SIS_COMUNICADO');
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('VER' AS VARCHAR(20))), ('ALTERAR'), ('ENVIAR'), ('APROVAR')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = 'SIS_COMUNICADO'
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

INSERT INTO SIS.Rotina (CODIGO, NOME, DESCRICAO, PROCEDIMENTO, ID_MODULO, FREQUENCIA, INTERVALO_MINUTOS, HORARIO, DIAS_SEMANA, DIA_MES,
                        TEMPO_LIMITE_MINUTOS, ATIVA, PROXIMA_EXECUCAO, USUARIO_CRIACAO)
SELECT 'COMUNICADO_PREVIA', N'Prévia dos comunicados semanais',
       N'Monta o comunicado da semana (boletim da implantação) e manda a prévia para aprovação. O envio oficial só sai depois de "Aprovar e enviar" na tela Comunicados.',
       N'SIS.SIS_Comunicado_Previa_Processar', m.ID_MODULO, 'SEMANAL', 0, '09:00', '6', 0, 30, 1,
       SIS.fn_SIS_Rotina_Proxima('SEMANAL', 0, '09:00', '6', 0, SYSDATETIME()), N'instalacao'
FROM SIS.Modulo m
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Rotina r WHERE r.CODIGO = 'COMUNICADO_PREVIA');
GO

EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Comunicado',      @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Comunicado_Item', @Criar = 1;
GO
