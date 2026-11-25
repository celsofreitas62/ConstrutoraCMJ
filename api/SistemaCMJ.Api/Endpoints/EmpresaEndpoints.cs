// =============================================================================
//  SistemaCMJ.Api - Endpoints/EmpresaEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 25/11/2026 (etapa 04e)
//  Descrição : Tela "Empresas" (CAD_EMPRESA). A API só repassa: permissão,
//              validação e gravação estão em CAD_Empresa_Listar / _Obter /
//              _Gravar / _Excluir (Desativar/Reativar). Excluir (lixeira),
//              Histórico e Anexos usam os endpoints gerais.
//              Rodapé dos e-mails (P11) e pasta do OFX: NULL = não mexe (a
//              pasta só é gravada para administrador, regra da procedure).
// =============================================================================
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public sealed record EmpresaPedido(
    int? IdEmpresa,
    string? RazaoSocial,
    string? NomeFantasia,
    string? Cnpj,
    string? CnpjCompras,
    string? Tipo,
    string? InscricaoEstadual,
    string? InscricaoMunicipal,
    string? RegimeTributario,
    string? Cep,
    string? Logradouro,
    string? Numero,
    string? Complemento,
    string? Bairro,
    string? Cidade,
    string? Uf,
    string? Email,
    string? Telefone,
    int? IdContaBancariaPadrao,
    string? RodapeEmail,
    string? PastaOfx);

public static class EmpresaEndpoints
{
    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/cad/empresas", Listar);
        app.MapGet("/api/cad/empresas/{id:int}", Obter);
        app.MapPost("/api/cad/empresas", Gravar);
        app.MapPost("/api/cad/empresas/{id:int}/excluir", Excluir);
    }

    private static Task<IResult> Listar(bool? somenteAtivos, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("CAD.CAD_Empresa_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["SomenteAtivos"] = somenteAtivos == true
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> Obter(int id, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linha = await banco.ExecutarUmaLinhaAsync("CAD.CAD_Empresa_Obter", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdEmpresa"] = id
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linha);
        });

    private static Task<IResult> Gravar(EmpresaPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var resultado = await banco.ExecutarUmaLinhaAsync("CAD.CAD_Empresa_Gravar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdEmpresa"] = p.IdEmpresa is > 0 ? p.IdEmpresa : null,
                ["RazaoSocial"] = Banco.Cortar(p.RazaoSocial?.Trim(), 150),
                ["NomeFantasia"] = Banco.Cortar(p.NomeFantasia?.Trim(), 100),
                ["Cnpj"] = Banco.Cortar(p.Cnpj?.Trim(), 20),
                ["CnpjCompras"] = p.CnpjCompras is null ? null : Banco.Cortar(p.CnpjCompras.Trim(), 20),
                ["Tipo"] = Banco.Cortar(p.Tipo?.Trim(), 12),
                ["InscricaoEstadual"] = Banco.Cortar(p.InscricaoEstadual?.Trim(), 20),
                ["InscricaoMunicipal"] = Banco.Cortar(p.InscricaoMunicipal?.Trim(), 20),
                ["RegimeTributario"] = Banco.Cortar(p.RegimeTributario?.Trim(), 20),
                ["Cep"] = Banco.Cortar(p.Cep?.Trim(), 10),
                ["Logradouro"] = Banco.Cortar(p.Logradouro?.Trim(), 150),
                ["Numero"] = Banco.Cortar(p.Numero?.Trim(), 20),
                ["Complemento"] = Banco.Cortar(p.Complemento?.Trim(), 60),
                ["Bairro"] = Banco.Cortar(p.Bairro?.Trim(), 60),
                ["Cidade"] = Banco.Cortar(p.Cidade?.Trim(), 60),
                ["Uf"] = Banco.Cortar(p.Uf?.Trim(), 2),
                ["Email"] = Banco.Cortar(p.Email?.Trim(), 256),
                ["Telefone"] = Banco.Cortar(p.Telefone?.Trim(), 30),
                ["IdContaBancariaPadrao"] = p.IdContaBancariaPadrao is > 0 ? p.IdContaBancariaPadrao : null,
                ["RodapeEmail"] = p.RodapeEmail is null ? null : Banco.Cortar(p.RodapeEmail, 1000),
                ["PastaOfx"] = p.PastaOfx is null ? null : Banco.Cortar(p.PastaOfx.Trim(), 260)
            }, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });

    private static Task<IResult> Excluir(int id, ExcluirPedido pedido, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var resultado = await banco.ExecutarUmaLinhaAsync("CAD.CAD_Empresa_Excluir", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdEmpresa"] = id,
                ["Reativar"] = pedido.Reativar
            }, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });
}
