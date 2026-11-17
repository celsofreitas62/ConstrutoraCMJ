/*******************************************************************************
  Objeto      : [SIS].[SIS_Comunicado_Edicao_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Uma edição com o HTML, para a tela mostrar exatamente o que será
                (ou foi) enviado. Permissão: VER em SIS_COMUNICADO.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comunicado_Edicao_Obter]
    @IdUsuario  INT,
    @IdEdicao   BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_COMUNICADO', 'VER') = 0
        THROW 50001, N'Você não tem permissão para ver os comunicados.', 1;

    SELECT e.ID_COMUNICADO_EDICAO, e.ID_COMUNICADO, e.DT_INICIO, e.DT_FIM, e.ASSUNTO, e.CORPO_HTML, e.SITUACAO,
           e.DT_APROVACAO, e.USUARIO_APROVACAO, e.DT_CRIACAO, e.USUARIO_CRIACAO
    FROM SIS.Comunicado_Edicao e WITH (NOLOCK)
    WHERE e.ID_COMUNICADO_EDICAO = @IdEdicao;
END;
GO
