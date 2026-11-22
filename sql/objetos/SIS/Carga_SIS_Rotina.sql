/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Rotina]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Rotinas automáticas da base SIS. Só insere o que falta
                (regra 39): agenda já mudada pela tela não é desfeita.
                Cada etapa seguinte acrescenta aqui as rotinas do seu módulo
                (ex.: avisos de vencimento, retorno do banco), com a
                procedure sem parâmetros que a rotina chama.
                A próxima execução é calculada na inclusão.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d): limpeza do log passo a passo e
                        liberação de e-mails presos.
    v1.1 (22/11/2026) - Etapa 04b (P20): LIXEIRA_LIMPEZA (limpeza e aviso da
                        lixeira, todo dia às 06:40).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Rotina (CODIGO, NOME, DESCRICAO, PROCEDIMENTO, ID_MODULO, FREQUENCIA, INTERVALO_MINUTOS, HORARIO, DIAS_SEMANA, DIA_MES,
                        TEMPO_LIMITE_MINUTOS, ATIVA, PROXIMA_EXECUCAO, USUARIO_CRIACAO)
SELECT v.CODIGO, v.NOME, v.DESCRICAO, v.PROCEDIMENTO, m.ID_MODULO, v.FREQUENCIA, v.INTERVALO, v.HORARIO, v.DIAS, v.DIA_MES,
       v.LIMITE, 1, SIS.fn_SIS_Rotina_Proxima(v.FREQUENCIA, v.INTERVALO, v.HORARIO, v.DIAS, v.DIA_MES, SYSDATETIME()), N'instalacao'
FROM (VALUES
        (CAST('LOG_LIMPEZA' AS VARCHAR(40)), CAST(N'Limpeza do log passo a passo' AS NVARCHAR(80)),
         CAST(N'Apaga o log passo a passo das rotinas mais antigo que o parâmetro LOG_PASSO_DIAS_RETENCAO. O log de erros não é apagado.' AS NVARCHAR(400)),
         CAST(N'SIS.SIS_Log_Limpar_Processar' AS NVARCHAR(256)), CAST('SIS' AS VARCHAR(10)), CAST('DIARIA' AS VARCHAR(10)),
         CAST(0 AS INT), CAST('03:10' AS TIME(0)), CAST('' AS VARCHAR(20)), CAST(0 AS TINYINT), CAST(60 AS INT)),
        ('EMAIL_PRESOS', N'Liberar e-mails presos',
         N'Devolve para a fila os e-mails que ficaram "processando" (o serviço parou no meio do envio), conforme o parâmetro EMAIL_MINUTOS_PRESO.',
         N'SIS.SIS_Email_Presos_Liberar', 'SIS', 'MINUTOS', 10, '00:00', '', 0, 10),
        ('LIXEIRA_LIMPEZA', N'Lixeira: limpeza e aviso',
         N'Apaga de vez o que passou do prazo da lixeira (LIXEIRA_DIAS_GUARDA ou o prazo da tela) e avisa por e-mail o que será apagado nos próximos LIXEIRA_AVISO_DIAS dia(s).',
         N'SIS.SIS_Lixeira_Processar', 'SIS', 'DIARIA', 0, '06:40', '', 0, 30)
     ) v (CODIGO, NOME, DESCRICAO, PROCEDIMENTO, MODULO, FREQUENCIA, INTERVALO, HORARIO, DIAS, DIA_MES, LIMITE)
INNER JOIN SIS.Modulo m ON m.CODIGO = v.MODULO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Rotina r WHERE r.CODIGO = v.CODIGO);
GO
