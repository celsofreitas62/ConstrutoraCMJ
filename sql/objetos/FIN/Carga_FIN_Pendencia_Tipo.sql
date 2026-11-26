/*******************************************************************************
  Objeto      : carga dos tipos de pendência de fábrica em [FIN].[Pendencia_Tipo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : P27 (aprovado em 26/11/2026).
                MIGRACAO ("Veio da migração – conferir") é do sistema
                (SISTEMA = 1): sempre garantido e reativado.
                Os demais são sugestões e entram só quando a tabela nasce
                vazia (como os perfis de fábrica): se a CMJ alterar, desativar
                ou excluir um deles, uma atualização nunca o traz de volta.
                Idempotente.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF NOT EXISTS (SELECT 1 FROM FIN.Pendencia_Tipo)
BEGIN
    INSERT INTO FIN.Pendencia_Tipo (CODIGO, DESCRICAO, ORIENTACAO, APLICA_A, BLOQUEIA_BAIXA, SISTEMA, ORDEM, USUARIO_CRIACAO)
    SELECT v.CODIGO, v.DESCRICAO, v.ORIENTACAO, v.APLICA_A, v.BLOQUEIA, 0, v.ORDEM, N'instalacao'
    FROM (VALUES
            (CAST('AGUARDA_NF' AS VARCHAR(20)), CAST(N'Aguardando nota fiscal' AS NVARCHAR(60)),
             CAST(N'Anexar a nota fiscal ao lançamento e resolver a pendência. Enquanto estiver aberta, o lançamento não pode ser pago.' AS NVARCHAR(400)),
             CAST('P' AS CHAR(1)), CAST(1 AS BIT), CAST(10 AS INT)),
            ('AGUARDA_CONTRATO', N'Aguardando contrato', N'Anexar o contrato assinado e resolver a pendência.', 'A', 0, 20),
            ('CONFERIR_VALOR', N'Conferir valor', N'Conferir o valor com o documento ou com o parceiro e corrigir o lançamento, se for o caso.', 'A', 0, 30),
            ('CONFERIR_CONTADOR', N'Conferir com o contador', N'Confirmar com o contador a forma de lançar (conta, retenções, competência).', 'A', 0, 40)
         ) v (CODIGO, DESCRICAO, ORIENTACAO, APLICA_A, BLOQUEIA, ORDEM);
END;
GO

INSERT INTO FIN.Pendencia_Tipo (CODIGO, DESCRICAO, ORIENTACAO, APLICA_A, BLOQUEIA_BAIXA, SISTEMA, ORDEM, USUARIO_CRIACAO)
SELECT 'MIGRACAO', N'Veio da migração – conferir',
       N'Lançamento que veio do Access com algum caso a conferir (o motivo está na observação). Conferir com o Access, corrigir o que for preciso e resolver a pendência.',
       'A', 0, 1, 90, N'instalacao'
WHERE NOT EXISTS (SELECT 1 FROM FIN.Pendencia_Tipo t WHERE t.CODIGO = 'MIGRACAO');

UPDATE FIN.Pendencia_Tipo
   SET SISTEMA = 1, ATIVO = 1, DT_EXCLUSAO = NULL, USUARIO_EXCLUSAO = NULL, DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = N'instalacao'
WHERE CODIGO = 'MIGRACAO' AND (SISTEMA = 0 OR ATIVO = 0 OR DT_EXCLUSAO IS NOT NULL);
GO
