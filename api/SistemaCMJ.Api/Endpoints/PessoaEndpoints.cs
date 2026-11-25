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
//              Desde a 04b2 (23/11/2026): "excluir" = Desativar/Reativar
//              (ação DESATIVAR); o Excluir (lixeira) e a aba Histórico usam
//              os endpoints gerais de HistoricoEndpoints.
//              Desde a 04d2 (25/11/2026): tipos de parceiro (Tipos = JSON
//              [ids]), conta/centro padrão (NULL = não mexe, 0 = limpa),
//              filtros idParceiroTipo e pendenciaCobranca na lista.
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
    JsonElement? DadosBancarios,
    JsonElement? Tipos = null,
    int? IdPlanoContaPadrao = null,
    int? IdCentroCustoPadrao = null);

public sealed record ExcluirPedido(bool Reativar);

public static class PessoaEndpoints
{
    private const string Item = "CAD_PESSOA";

    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/cad/pessoas", Listar);
        app.MapGet("/api/cad/pessoas/{id:int}", Obter);
        app.MapPost("/api/cad/pessoas", Gravar);
        app.MapPost("/api/cad/pessoas/{id:int}/excluir", Excluir);
    }

    private static Task<IResult> Listar(string? busca, string? papel, string? situacao, int? idParceiroTipo, bool? pendenciaCobranca, HttpContext http, Banco banco, ILogger<Program> logger) =>
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
                ["Limite"] = 500,
                ["IdParceiroTipo"] = idParceiroTipo is > 0 ? idParceiroTipo : null,
                ["PendenciaCobranca"] = pendenciaCobranca == true
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
            foreach (var coluna in new[] { "CONTATOS", "VINCULOS", "DADOS_BANCARIOS", "TIPOS" })
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
                ["DadosBancarios"] = ListaJson(p.DadosBancarios),
                ["Tipos"] = ListaJson(p.Tipos),
                ["IdPlanoContaPadrao"] = p.IdPlanoContaPadrao,
                ["IdCentroCustoPadrao"] = p.IdCentroCustoPadrao
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
