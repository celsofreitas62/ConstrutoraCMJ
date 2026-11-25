/*******************************************************************************
  Objeto      : [CAD].[CAD_Consulta_Config_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Configuração das consultas de CEP e CNPJ na internet (lidas
                pela API antes de consultar) e, quando @Cep é informado, o
                endereço guardado em CAD.Cep_Cache se ainda estiver no prazo
                (CEP_CACHE_DIAS). Permissão: INCLUIR ou ALTERAR em CAD_PESSOA
                ou em CAD_EMPRESA (quem preenche cadastros).

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Consulta_Config_Obter]
    @IdUsuario INT,
    @Cep       VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Pode BIT = CASE WHEN SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', 'INCLUIR') = 1
                               OR SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', 'ALTERAR') = 1
                               OR SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', 'INCLUIR') = 1
                               OR SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', 'ALTERAR') = 1 THEN 1 ELSE 0 END;
    SET @Cep = CAD.fn_CAD_Somente_Digitos(@Cep);

    SELECT @Pode AS PODE,
           SIS.fn_SIS_Parametro_SN('CEP_CONSULTA_ATIVA')  AS CEP_ATIVA,
           SIS.fn_SIS_Parametro('CEP_URL_PRINCIPAL')      AS CEP_URL_PRINCIPAL,
           SIS.fn_SIS_Parametro('CEP_URL_RESERVA')        AS CEP_URL_RESERVA,
           SIS.fn_SIS_Parametro_SN('CNPJ_CONSULTA_ATIVA') AS CNPJ_ATIVA,
           SIS.fn_SIS_Parametro('CNPJ_URL')               AS CNPJ_URL,
           ISNULL(SIS.fn_SIS_Parametro_Inteiro('CONSULTA_TEMPO_LIMITE_SEG'), 8) AS TEMPO_LIMITE_SEG,
           c.LOGRADOURO, c.COMPLEMENTO, c.BAIRRO, c.CIDADE, c.UF, c.CODIGO_IBGE, c.FONTE,
           CAST(CASE WHEN c.CEP IS NULL THEN 0 ELSE 1 END AS BIT) AS CEP_EM_CACHE
    FROM (SELECT 1 AS X) x
    LEFT JOIN CAD.Cep_Cache c
           ON @Pode = 1 AND c.CEP = @Cep
          AND c.DT_CONSULTA >= DATEADD(DAY, -ISNULL(SIS.fn_SIS_Parametro_Inteiro('CEP_CACHE_DIAS'), 180), SYSDATETIME());
END;
GO
