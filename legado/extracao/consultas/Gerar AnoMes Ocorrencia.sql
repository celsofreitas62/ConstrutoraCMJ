-- Consulta: Gerar AnoMes Ocorrencia
-- Tipo: Acréscimo (64)
-- Parâmetros: Formulários![F Gerar Ocorrencias Mensais]!AnoOcorrencia (Texto), Formulários![F Gerar Ocorrencias Mensais]!ProximoMes (Texto)
-- Descrição: 

INSERT INTO [AnoMes Ocorrencias Mensais] ( UltimoAnoGerado, UltimoMesGerado )
SELECT Formulários![F Gerar Ocorrencias Mensais]!AnoOcorrencia AS AnoOcorrencia, Formulários![F Gerar Ocorrencias Mensais]!ProximoMes AS MesOcorrencia;
