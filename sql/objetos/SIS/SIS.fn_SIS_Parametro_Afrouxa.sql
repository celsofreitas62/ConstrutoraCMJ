/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Parametro_Afrouxa]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : 1 quando a troca de valor de um parâmetro AFROUXA uma proteção
                (sugestão (c) da 04f2d): nessa hora a tela pede o motivo e o
                SIS_Parametro_Gravar recusa sem ele.
                  - parâmetro com opções AVISO/BLOQUEIO/NAO (regras FIN_REGRA_*
                    do P17): descer de nível (BLOQUEIO > AVISO > NAO);
                  - parâmetro SN que liga uma trava (FIN_TRAVA_DATAS_ATIVA):
                    passar de S para N.
                Valores comparados já no formato canônico (maiúsculas).
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2d).
  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Parametro_Afrouxa('FIN_REGRA_DUPLIC_VALOR', N'BLOQUEIO', N'AVISO');  -- 1
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Parametro_Afrouxa] (@Chave VARCHAR(60), @Atual NVARCHAR(4000), @Novo NVARCHAR(4000))
RETURNS BIT
AS
BEGIN
    DECLARE @Opcoes NVARCHAR(200) = (SELECT OPCOES FROM SIS.Parametro WHERE CHAVE = @Chave);
    DECLARE @A NVARCHAR(20) = UPPER(LTRIM(RTRIM(ISNULL(@Atual, N''))));
    DECLARE @N NVARCHAR(20) = UPPER(LTRIM(RTRIM(ISNULL(@Novo, N''))));

    IF @Chave IN ('FIN_TRAVA_DATAS_ATIVA')
        RETURN CASE WHEN @A = N'S' AND @N = N'N' THEN 1 ELSE 0 END;

    IF ISNULL(@Opcoes, N'') LIKE N'%BLOQUEIO%'
        RETURN CASE WHEN (CASE @A WHEN N'BLOQUEIO' THEN 3 WHEN N'AVISO' THEN 2 WHEN N'NAO' THEN 1 ELSE 0 END)
                       > (CASE @N WHEN N'BLOQUEIO' THEN 3 WHEN N'AVISO' THEN 2 WHEN N'NAO' THEN 1 ELSE 0 END)
                    THEN 1 ELSE 0 END;

    RETURN 0;
END;
GO
