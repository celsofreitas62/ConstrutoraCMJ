// =============================================================================
//  SistemaCMJ.Api - Endpoints/PessoaEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 16/11/2026 (fase 3b)
//  Descrição : Tela "Pessoas" (CAD_PESSOA). A API só repassa: permissão,
//              validação e gravação (tudo ou nada) estão nas procedures
//              CAD_Pessoa_Listar / _Obter / _Gravar / _Excluir.
//              Contatos, vínculos e dados bancários vão como JSON, no formato
//              que o CAD_Pessoa_Obter devolve e o CAD_Pessoa_Gravar recebe.
// =============================================================================
using System.Globalization;
using System.Text.Json;
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public sealed record PessoaPedido(
    int? IdPessoa,
    string? TipoPessoa,
    string? Nome,
    string? NomeFantasia,
    string? CpfCnpj,
    string? Rg,
    string? OrgaoEmissor,
    string? InscricaoEstadual,
    string? InscricaoMunicipal,
    string? DtNascimento,
    string? Nacionalidade,
    string? Profissao,
    string? EstadoCivil,
    string? RegimeBens,
    string? Cep,
    string? Logradouro,
    string? Numero,
    string? Complemento,
    string? Bairro,
    string? Cidade,
    string? Uf,
    bool Cliente,
    bool Fornecedor,
    bool Funcionario,
    bool Corretor,
    string? Observacao,
    JsonElement? Contatos,
    JsonElement? Vinculos,
    JsonElement? DadosBancarios);

public sealed record ExcluirPedido(bool Reativar);

public static class PessoaEndpoints
{
    private const string Item = "CAD_PESSOA";

    // Partes da ficha que têm histórico próprio (TABELAS_DA_TELA de CAD_PESSOA).
    private static readonly (string Coluna, string Tabela, string Parte)[] Partes =
    [
        ("CONTATOS", "CAD.Pessoa_Contato", "Contato"),
        ("DADOS_BANCARIOS", "CAD.Pessoa_Dado_Bancario", "Dado bancário")
    ];

    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/cad/pessoas", Listar);
        app.MapGet("/api/cad/pessoas/{id:int}", Obter);
        app.MapPost("/api/cad/pessoas", Gravar);
        app.MapPost("/api/cad/pessoas/{id:int}/excluir", Excluir);
        app.MapGet("/api/cad/pessoas/{id:int}/historico", Historico);
    }

    private static Task<IResult> Listar(string? busca, string? papel, string? situacao, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            situacao = (situacao ?? "ATIVOS").ToUpperInvariant();
            var linhas = await banco.ExecutarAsync("CAD.CAD_Pessoa_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Busca"] = Banco.Cortar(busca?.Trim(), 100),
                ["Papel"] = Banco.Cortar(papel?.Trim(), 12),
                ["SomenteAtivos"] = situacao == "ATIVOS",
                ["Limite"] = 500
            }, usuario, http.RequestAborted);
            if (situacao == "INATIVOS")
                linhas = linhas.Where(l => !l.Bool("ATIVO")).ToList();
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> Obter(int id, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linha = await ObterLinhaAsync(id, usuario, banco, http.RequestAborted);
            foreach (var coluna in new[] { "CONTATOS", "VINCULOS", "DADOS_BANCARIOS" })
                linha[coluna] = ComoJson(linha.Texto(coluna));
            return Resposta.Ok(linha);
        });

    private static Task<IResult> Gravar(PessoaPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();

            DateOnly? nascimento = null;
            if (!string.IsNullOrWhiteSpace(p.DtNascimento))
            {
                if (!DateOnly.TryParseExact(p.DtNascimento.Trim(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var data))
                    return Resposta.Atencao("Data de nascimento inválida.");
                nascimento = data;
            }

            var resultado = await banco.ExecutarUmaLinhaAsync("CAD.CAD_Pessoa_Gravar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdPessoa"] = p.IdPessoa is > 0 ? p.IdPessoa : null,
                ["TipoPessoa"] = Banco.Cortar(p.TipoPessoa, 1),
                ["Nome"] = Texto(p.Nome),
                ["NomeFantasia"] = Texto(p.NomeFantasia),
                ["CpfCnpj"] = Texto(p.CpfCnpj),
                ["Rg"] = Texto(p.Rg),
                ["OrgaoEmissor"] = Texto(p.OrgaoEmissor),
                ["InscricaoEstadual"] = Texto(p.InscricaoEstadual),
                ["InscricaoMunicipal"] = Texto(p.InscricaoMunicipal),
                ["DtNascimento"] = nascimento,
                ["Nacionalidade"] = Texto(p.Nacionalidade),
                ["Profissao"] = Texto(p.Profissao),
                ["EstadoCivil"] = Texto(p.EstadoCivil),
                ["RegimeBens"] = Texto(p.RegimeBens),
                ["Cep"] = Texto(p.Cep),
                ["Logradouro"] = Texto(p.Logradouro),
                ["Numero"] = Texto(p.Numero),
                ["Complemento"] = Texto(p.Complemento),
                ["Bairro"] = Texto(p.Bairro),
                ["Cidade"] = Texto(p.Cidade),
                ["Uf"] = Texto(p.Uf),
                ["Cliente"] = p.Cliente,
                ["Fornecedor"] = p.Fornecedor,
                ["Funcionario"] = p.Funcionario,
                ["Corretor"] = p.Corretor,
                ["Observacao"] = Texto(p.Observacao),
                ["Contatos"] = ListaJson(p.Contatos),
                ["Vinculos"] = ListaJson(p.Vinculos),
                ["DadosBancarios"] = ListaJson(p.DadosBancarios)
            }, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });

    private static Task<IResult> Excluir(int id, ExcluirPedido pedido, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var resultado = await banco.ExecutarUmaLinhaAsync("CAD.CAD_Pessoa_Excluir", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdPessoa"] = id,
                ["Reativar"] = pedido.Reativar
            }, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });

    /// <summary>Aba "Histórico": a pessoa e as partes dela (contatos, dados bancários), mais recente primeiro.</summary>
    private static Task<IResult> Historico(int id, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var ficha = await ObterLinhaAsync(id, usuario, banco, http.RequestAborted);

            var alvos = new List<(string Tabela, long Id, string Parte)> { ("CAD.Pessoa", id, "Pessoa") };
            foreach (var (coluna, tabela, parte) in Partes)
                if (ComoJson(ficha.Texto(coluna)) is { ValueKind: JsonValueKind.Array } lista)
                    foreach (var item in lista.EnumerateArray())
                        if (item.TryGetProperty("id", out var idParte) && idParte.TryGetInt64(out var valor))
                            alvos.Add((tabela, valor, parte));

            var todas = new List<Linha>();
            foreach (var (tabela, idRegistro, parte) in alvos)
            {
                var linhas = await banco.ExecutarAsync("SIS.SIS_Auditoria_Registro_Listar", new Dictionary<string, object?>
                {
                    ["IdUsuario"] = usuario.IdUsuario,
                    ["Item"] = Item,
                    ["Tabela"] = tabela,
                    ["IdRegistro"] = idRegistro
                }, usuario, http.RequestAborted);
                foreach (var linha in linhas)
                    linha["PARTE"] = parte;
                todas.AddRange(linhas);
            }
            return Resposta.Ok(todas.OrderByDescending(l => l.Long("ID_AUDITORIA")).Take(500).ToList());
        });

    private static async Task<Linha> ObterLinhaAsync(int id, Contexto usuario, Banco banco, CancellationToken ct) =>
        await banco.ExecutarUmaLinhaAsync("CAD.CAD_Pessoa_Obter", new Dictionary<string, object?>
        {
            ["IdUsuario"] = usuario.IdUsuario,
            ["IdPessoa"] = id
        }, usuario, ct);

    private static string? Texto(string? valor) => valor?.Trim();

    /// <summary>Lista vinda da tela: só aceita array; ausente = NULL (a procedure não mexe).</summary>
    private static string? ListaJson(JsonElement? lista) =>
        lista is { ValueKind: JsonValueKind.Array } array ? array.GetRawText() : null;

    private static JsonElement? ComoJson(string texto)
    {
        if (string.IsNullOrWhiteSpace(texto))
            return null;
        using var documento = JsonDocument.Parse(texto);
        return documento.RootElement.Clone();
    }
}
