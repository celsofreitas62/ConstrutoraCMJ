/*******************************************************************************
  Objeto      : finalização da carga da base SIS
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Última instrução da instalação: acerta os módulos liberados
                pela licença ativa (módulo recém-instalado que já constava na
                licença passa a valer na hora). No MASTER fica no fim da
                parte 9 (parâmetros e carga inicial).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

EXEC SIS.SIS_Licenca_Modulos_Aplicar @Usuario = N'instalacao';
GO
