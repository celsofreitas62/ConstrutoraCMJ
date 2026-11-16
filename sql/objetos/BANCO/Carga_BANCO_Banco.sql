/*******************************************************************************
  Objeto      : carga inicial de [BANCO].[Banco]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Principais bancos (código COMPE e ISPB). Só insere o que falta
                (regra 39): banco já cadastrado não é alterado. O administrador
                acrescenta outros pela tela "Bancos" (conferir o ISPB antes de usar
                em PIX).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO BANCO.Banco (CODIGO, ISPB, NOME, USUARIO_CRIACAO)
SELECT v.CODIGO, v.ISPB, v.NOME, N'instalacao'
FROM (VALUES
        (CAST('001' AS CHAR(3)), CAST('00000000' AS VARCHAR(8)), CAST(N'Banco do Brasil' AS NVARCHAR(80))),
        ('033', '90400888', N'Santander'),
        ('041', '92702067', N'Banrisul'),
        ('077', '00416968', N'Banco Inter'),
        ('104', '00360305', N'Caixa Econômica Federal'),
        ('208', '30306294', N'BTG Pactual'),
        ('237', '60746948', N'Bradesco'),
        ('260', '18236120', N'Nubank'),
        ('290', '08561701', N'PagBank (PagSeguro)'),
        ('323', '10573521', N'Mercado Pago'),
        ('336', '31872495', N'C6 Bank'),
        ('341', '60701190', N'Itaú Unibanco'),
        ('422', '58160789', N'Safra'),
        ('748', '01181521', N'Sicredi'),
        ('756', '02038232', N'Sicoob')
     ) v (CODIGO, ISPB, NOME)
WHERE NOT EXISTS (SELECT 1 FROM BANCO.Banco b WHERE b.CODIGO = v.CODIGO);
GO
