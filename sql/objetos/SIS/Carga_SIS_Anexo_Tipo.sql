/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Anexo_Tipo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tipos de anexo e extensões aceitas. Só insere o que falta
                (regra 39). LOGOMARCA: logomarca de cada obra (pedido do Celso,
                15/11/2026), anexada no cadastro da obra (etapa 03).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Anexo_Tipo (CODIGO, NOME, EXTENSOES)
SELECT v.CODIGO, v.NOME, v.EXTENSOES
FROM (VALUES
        (CAST('CONTRATO' AS VARCHAR(30)), CAST(N'Contrato' AS NVARCHAR(60)), CAST('pdf,doc,docx,jpg,jpeg,png' AS VARCHAR(200))),
        ('NOTA_FISCAL',  N'Nota fiscal',                'pdf,xml,jpg,jpeg,png'),
        ('COMPROVANTE',  N'Comprovante de pagamento',   'pdf,jpg,jpeg,png'),
        ('ACORDO',       N'Acordo / renegociação',      'pdf,doc,docx,jpg,jpeg,png'),
        ('BOLETO',       N'Boleto',                     'pdf'),
        ('MEDICAO',      N'Boletim de medição',         'pdf,xlsx,xls,jpg,jpeg,png'),
        ('DOCUMENTO',    N'Documento pessoal / da empresa', 'pdf,jpg,jpeg,png'),
        ('LOGOMARCA',    N'Logomarca',                  'png,jpg,jpeg,svg'),
        ('OUTRO',        N'Outro',                      'pdf,doc,docx,xls,xlsx,jpg,jpeg,png,txt,zip')
     ) v (CODIGO, NOME, EXTENSOES)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Anexo_Tipo t WHERE t.CODIGO = v.CODIGO);
GO
