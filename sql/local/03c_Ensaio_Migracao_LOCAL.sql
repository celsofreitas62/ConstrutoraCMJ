/*******************************************************************************
  Script      : ensaio da migração do movimento (somente SISTEMACMJ_LOCAL)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026 (etapa 03c)
  Descrição   : Roda o ensaio de ponta a ponta, na ordem:
                1) carga crua dos CSV do Access (MIG.MIG_Carga_Processar);
                2) classificação das linhas (MIG.MIG_Movimento_Preparar);
                3) arquivo morto (MIG.MIG_Arquivo_Morto_Processar);
                4) conferência (MIG.MIG_Conferencia_Listar).
                Repetível: cada passo apaga o resultado anterior.
                Pré-requisito: pacotes 03c e 03c_mig rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5. Leva alguns minutos.
*******************************************************************************/
USE [SISTEMACMJ_LOCAL];
GO

IF DB_NAME() <> N'SISTEMACMJ_LOCAL'
BEGIN
    RAISERROR(N'Este script só roda no SISTEMACMJ_LOCAL. Nada foi executado.', 16, 1);
    SET NOEXEC ON;
END;
GO

EXEC MIG.MIG_Carga_Processar @Pasta = N'C:\SistemaCMJ\legado\dados_brutos';
GO
EXEC MIG.MIG_Movimento_Preparar @Corte = '2022-01-01';   -- decisão do Celso, 17/11/2026
GO
EXEC MIG.MIG_Arquivo_Morto_Processar;
GO
EXEC MIG.MIG_Conferencia_Listar;
GO

SET NOEXEC OFF;
GO
