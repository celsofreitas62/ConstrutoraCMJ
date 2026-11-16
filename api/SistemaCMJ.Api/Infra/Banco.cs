// =============================================================================
//  SistemaCMJ.Api - Infra/Banco.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 16/11/2026 (fase 3b)
//  Descrição : Ponto ÚNICO de acesso ao SQL Server. Toda chamada de procedure
//              passa por aqui:
//                1) abre a conexão;
//                2) grava o contexto do usuário (SIS_Contexto_Gravar), para a
//                   auditoria, o log de erros e as colunas USUARIO_* saberem
//                   quem fez (não o login técnico da API);
//                3) executa a procedure e devolve as linhas.
//              A conexão volta ao pool limpa (sp_reset_connection): um usuário
//              nunca herda o contexto de outro.
// =============================================================================
using System.Data;
using Microsoft.Data.SqlClient;

namespace SistemaCMJ.Api.Infra;

/// <summary>Quem está usando o sistema nesta requisição.</summary>
public sealed record Contexto(int IdUsuario, string Login, string Nome, bool TrocarSenha, string Estacao, string Origem);

/// <summary>NULL com tipo definido (ex.: VARBINARY), quando o SQL não aceita
/// converter o NULL "sem tipo" (nvarchar) para o tipo do parâmetro.</summary>
public sealed record NuloTipado(SqlDbType Tipo)
{
    public static readonly NuloTipado Binario = new(SqlDbType.VarBinary);
}

/// <summary>Uma linha de resultado: nome da coluna (como vem do SQL) e valor.</summary>
public sealed class Linha : Dictionary<string, object?>
{
    public Linha() : base(StringComparer.OrdinalIgnoreCase) { }

    public bool Bool(string coluna) => this.TryGetValue(coluna, out var v) && v is bool b && b;
    public int? Int(string coluna) => this.TryGetValue(coluna, out var v) && v is not null ? Convert.ToInt32(v) : null;
    public long? Long(string coluna) => this.TryGetValue(coluna, out var v) && v is not null ? Convert.ToInt64(v) : null;
    public string Texto(string coluna) => this.TryGetValue(coluna, out var v) && v is not null ? Convert.ToString(v) ?? "" : "";
    public byte[]? Bytes(string coluna) => this.TryGetValue(coluna, out var v) ? v as byte[] : null;
}

public sealed class Banco(IConfiguration configuracao)
{
    private string TextoConexao =>
        configuracao.GetConnectionString("SistemaCMJ") is { Length: > 0 } texto
            ? texto
            : throw new InvalidOperationException("Falta a conexão 'SistemaCMJ' na configuração (appsettings ou variável de ambiente ConnectionStrings__SistemaCMJ).");

    /// <summary>Executa uma procedure e devolve as linhas do primeiro resultado.</summary>
    /// <param name="procedure">Nome completo, ex.: "CAD.CAD_Pessoa_Listar".</param>
    /// <param name="parametros">Parâmetros sem o @ (null vira NULL).</param>
    /// <param name="contexto">Usuário logado; null só antes do login.</param>
    public async Task<List<Linha>> ExecutarAsync(string procedure, IDictionary<string, object?>? parametros, Contexto? contexto, CancellationToken ct = default)
    {
        await using var conexao = new SqlConnection(TextoConexao);
        await conexao.OpenAsync(ct);

        if (contexto is not null)
            await GravarContextoAsync(conexao, contexto, ct);

        await using var comando = new SqlCommand(procedure, conexao)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 120
        };
        if (parametros is not null)
            foreach (var (nome, valor) in parametros)
                comando.Parameters.Add(CriarParametro(nome, valor));

        var linhas = new List<Linha>();
        await using var leitor = await comando.ExecuteReaderAsync(ct);
        while (await leitor.ReadAsync(ct))
        {
            var linha = new Linha();
            for (var i = 0; i < leitor.FieldCount; i++)
                linha[leitor.GetName(i)] = leitor.IsDBNull(i) ? null : leitor.GetValue(i);
            linhas.Add(linha);
        }
        return linhas;
    }

    /// <summary>Procedure que devolve exatamente uma linha (SUCESSO, MENSAGEM...).</summary>
    public async Task<Linha> ExecutarUmaLinhaAsync(string procedure, IDictionary<string, object?>? parametros, Contexto? contexto, CancellationToken ct = default)
    {
        var linhas = await ExecutarAsync(procedure, parametros, contexto, ct);
        return linhas.Count > 0 ? linhas[0] : throw new InvalidOperationException($"A procedure {procedure} não devolveu linha.");
    }

    /// <summary>Lê um valor de function escalar (ex.: parâmetros do sistema).</summary>
    public async Task<object?> EscalarAsync(string sql, IDictionary<string, object?>? parametros, CancellationToken ct = default)
    {
        await using var conexao = new SqlConnection(TextoConexao);
        await conexao.OpenAsync(ct);
        await using var comando = new SqlCommand(sql, conexao) { CommandType = CommandType.Text, CommandTimeout = 30 };
        if (parametros is not null)
            foreach (var (nome, valor) in parametros)
                comando.Parameters.Add(CriarParametro(nome, valor));
        var valorLido = await comando.ExecuteScalarAsync(ct);
        return valorLido is DBNull ? null : valorLido;
    }

    /// <summary>Parâmetro texto do sistema (SIS.fn_SIS_Parametro).</summary>
    public async Task<string> ParametroAsync(string chave, CancellationToken ct = default) =>
        Convert.ToString(await EscalarAsync("SELECT SIS.fn_SIS_Parametro(@Chave);", new Dictionary<string, object?> { ["Chave"] = chave }, ct)) ?? "";

    /// <summary>Parâmetro inteiro do sistema (SIS.fn_SIS_Parametro_Inteiro).</summary>
    public async Task<int> ParametroInteiroAsync(string chave, CancellationToken ct = default) =>
        Convert.ToInt32(await EscalarAsync("SELECT SIS.fn_SIS_Parametro_Inteiro(@Chave);", new Dictionary<string, object?> { ["Chave"] = chave }, ct) ?? 0);

    /// <summary>Grava falha técnica da API em SIS.Log_Erro. Nunca lança erro.</summary>
    public async Task RegistrarErroAsync(string rotina, string etapa, Exception erro)
    {
        try
        {
            var numero = erro is SqlException sql ? sql.Number : (int?)null;
            await ExecutarAsync("SIS.SIS_Log_Erro_Gravar", new Dictionary<string, object?>
            {
                ["Rotina"] = Cortar(rotina, 256),
                ["Etapa"] = Cortar(etapa, 200),
                ["NumeroErro"] = numero,
                ["Mensagem"] = Cortar(erro.Message, 4000),
                ["Origem"] = "API",
                ["Detalhe"] = erro.ToString()
            }, null);
        }
        catch
        {
            // Se nem o log funciona (banco fora do ar), fica só o log do serviço.
        }
    }

    private static async Task GravarContextoAsync(SqlConnection conexao, Contexto contexto, CancellationToken ct)
    {
        await using var comando = new SqlCommand("SIS.SIS_Contexto_Gravar", conexao) { CommandType = CommandType.StoredProcedure };
        comando.Parameters.Add(CriarParametro("IdUsuario", contexto.IdUsuario));
        comando.Parameters.Add(CriarParametro("Estacao", Cortar(contexto.Estacao, 128)));
        comando.Parameters.Add(CriarParametro("Origem", Cortar(contexto.Origem, 256)));
        await comando.ExecuteNonQueryAsync(ct);
    }

    private static SqlParameter CriarParametro(string nome, object? valor)
    {
        var parametro = new SqlParameter("@" + nome.TrimStart('@'), valor ?? DBNull.Value);
        switch (valor)
        {
            case NuloTipado nulo: parametro.Value = DBNull.Value; parametro.SqlDbType = nulo.Tipo; break;
            case byte[]: parametro.SqlDbType = SqlDbType.VarBinary; break;
            case string texto: parametro.SqlDbType = SqlDbType.NVarChar; parametro.Size = texto.Length > 4000 ? -1 : 4000; break;
            case DateOnly data: parametro.SqlDbType = SqlDbType.Date; parametro.Value = data.ToDateTime(TimeOnly.MinValue); break;
            case bool: parametro.SqlDbType = SqlDbType.Bit; break;
        }
        return parametro;
    }

    public static string Cortar(string? texto, int tamanho) =>
        string.IsNullOrEmpty(texto) ? "" : texto.Length <= tamanho ? texto : texto[..tamanho];
}
