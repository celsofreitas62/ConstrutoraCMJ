<!-- pagina: parametros | titulo: Parâmetros | resumo: Como os parâmetros funcionam e a lista completa, lida do banco na hora, com valor atual, padrão e descrição. | palavras: parametro sis.parametro configuracao valor padrao editavel backup senha email identidade cor logomarca -->

## Como funcionam

- Tudo o que muda de cliente para cliente, ou com o tempo, fica em **`SIS.Parametro`** (chave, valor, valor padrão, tipo, descrição, módulo). Nada de valor de negócio fixo no código (PADRAO_SQL, regra 33).
- As rotinas leem o parâmetro **a cada execução**: mudou o valor, vale na próxima vez, sem reiniciar.
- **Editável pelo administrador** (`EDITAVEL_ADMIN`): os marcados "não" são técnicos, só mudam pelo Celso ou por carga.
- O MASTER **só insere parâmetro que falta**: nunca sobrescreve o que foi ajustado no cliente.
- A tela de Parâmetros (Sistema › Configuração) vem na fase 4. Até lá, pelo SSMS, no banco certo:

```sql
-- Trocar CHAVE e o valor; conferir com o SELECT.
UPDATE SIS.Parametro SET VALOR = N'novo valor' WHERE CHAVE = 'CHAVE_DO_PARAMETRO';
SELECT CHAVE, VALOR, VALOR_PADRAO FROM SIS.Parametro WHERE CHAVE = 'CHAVE_DO_PARAMETRO';
```

## Lista atual (lida do banco agora)

<!-- dinamico: parametros -->
