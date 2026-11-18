/*******************************************************************************
  Objeto      : [MIG].[fn_MIG_Hash_Unidade]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Impressão digital de um documento do Access (unidade): SHA-256
                das impressões das linhas dele (MIG.Movimento.HASH_CONTEUDO),
                em ordem. Muda se qualquer linha do documento for alterada,
                incluída ou apagada no Access. NULL se o documento não existe.
                Usada pela tela "Casos da migração" para avisar quando o Access
                mudou depois de uma decisão (ignorar / arquivo morto).
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, aviso de mudança no Access).

  Homologação (LOCAL):
    -- SELECT MIG.fn_MIG_Hash_Unidade('L:123');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [MIG].[fn_MIG_Hash_Unidade] (@Unidade VARCHAR(40))
RETURNS VARBINARY(32)
AS
BEGIN
    RETURN (SELECT CASE WHEN COUNT(*) = 0 THEN NULL
                        ELSE HASHBYTES('SHA2_256', STRING_AGG(CAST(CONVERT(VARCHAR(64), m.HASH_CONTEUDO, 2) AS VARCHAR(MAX)), '|')
                                                   WITHIN GROUP (ORDER BY m.ORIGEM, m.NUM)) END
            FROM MIG.Movimento m
            WHERE m.UNIDADE = @Unidade AND m.DESTINO = 'SISTEMA');
END;
GO
