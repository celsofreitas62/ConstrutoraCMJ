/*******************************************************************************
  Objeto      : [CAD].[CAD_Cep_Cache_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Guarda (ou renova) o endereço de um CEP consultado na internet
                pela API. Dado público dos Correios. Só grava com cidade e UF.
                Permissão: a mesma do CAD_Consulta_Config_Obter.

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Cep_Cache_Gravar]
    @IdUsuario   INT,
    @Cep         VARCHAR(10),
    @Logradouro  NVARCHAR(150) = NULL,
    @Complemento NVARCHAR(60)  = NULL,
    @Bairro      NVARCHAR(60)  = NULL,
    @Cidade      NVARCHAR(60),
    @Uf          CHAR(2),
    @CodigoIbge  VARCHAR(7)    = NULL,
    @Fonte       VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Cep = CAD.fn_CAD_Somente_Digitos(@Cep);
    SET @Uf  = UPPER(LTRIM(RTRIM(ISNULL(@Uf, ''))));

    IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', 'INCLUIR') = 0 AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', 'ALTERAR') = 0
       AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', 'INCLUIR') = 0 AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', 'ALTERAR') = 0
        RETURN;
    IF LEN(@Cep) <> 8 OR LTRIM(RTRIM(ISNULL(@Cidade, N''))) = N'' OR LEN(@Uf) <> 2
        RETURN;

    MERGE CAD.Cep_Cache AS d
    USING (SELECT @Cep AS CEP) s ON d.CEP = s.CEP
    WHEN MATCHED THEN UPDATE SET LOGRADOURO = LEFT(ISNULL(@Logradouro, N''), 150), COMPLEMENTO = LEFT(ISNULL(@Complemento, N''), 60),
                                 BAIRRO = LEFT(ISNULL(@Bairro, N''), 60), CIDADE = LEFT(@Cidade, 60), UF = @Uf,
                                 CODIGO_IBGE = LEFT(ISNULL(@CodigoIbge, ''), 7), FONTE = LEFT(@Fonte, 20), DT_CONSULTA = SYSDATETIME()
    WHEN NOT MATCHED THEN INSERT (CEP, LOGRADOURO, COMPLEMENTO, BAIRRO, CIDADE, UF, CODIGO_IBGE, FONTE)
                          VALUES (@Cep, LEFT(ISNULL(@Logradouro, N''), 150), LEFT(ISNULL(@Complemento, N''), 60), LEFT(ISNULL(@Bairro, N''), 60),
                                  LEFT(@Cidade, 60), @Uf, LEFT(ISNULL(@CodigoIbge, ''), 7), LEFT(@Fonte, 20));
END;
GO
