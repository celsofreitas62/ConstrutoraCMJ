// =============================================================================
//  SistemaCMJ.Api - Endpoints/BackupEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 20/11/2026 (etapa 03d2)
//  Descrição : Tela Sistema > Backups e restauração (SIS_BACKUP).
//              A API só lista e registra pedidos: quem restaura é a tarefa do
//              Windows "Restauração (pedidos)" (backup_servidor.ps1, como
//              SYSTEM); o login da API não tem permissão para restaurar.
//              Pedido de restauração: a API confere a senha do usuário
//              (PBKDF2, mesmo caminho da troca de senha) e passa só o
//              resultado (SenhaConferida) para a procedure, que confere a
//              permissão RESTAURAR, a palavra RESTAURAR, o motivo e o plano.
//              Permissões, validações e gravação ficam nas procedures
//              SIS_Backup_*; a API só repassa.
// =============================================================================
using System.Globalization;
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public sealed record RestauracaoPedido(string? TipoPonto, long? IdBackup, string? DtPonto, string? Motivo, string? Confirmacao, string? Senha);
public sealed record RestauracaoCancelarPedido(int? IdRestauracao);

public static class BackupEndpoints
{
    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/sis/backups", Listar);
        app.MapPost("/api/sis/backups/restaurar", Restaurar);
        app.MapPost("/api/sis/backups/cancelar", Cancelar);
    }

    /// <summary>Situação (topo), lista dos backups e pedidos de restauração, numa chamada só.</summary>
    private static Task<IResult> Listar(int? dias, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var parametros = new Dictionary<string, object?> { ["IdUsuario"] = usuario.IdUsuario };
            var situacao = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Backup_Situacao_Obter", parametros, usuario, http.RequestAborted);
            var backups = await banco.ExecutarAsync("SIS.SIS_Backup_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Dias"] = dias is > 0 and <= 3650 ? dias : null
            }, usuario, http.RequestAborted);
            var pedidos = await banco.ExecutarAsync("SIS.SIS_Backup_Restauracao_Listar", parametros, usuario, http.RequestAborted);
            return Resposta.Ok(new { situacao, backups, pedidos });
        });

    private static Task<IResult> Restaurar(RestauracaoPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var tipo = (p.TipoPonto ?? "").Trim().ToUpperInvariant();
            var senha = p.Senha ?? "";
            DateTime? ponto = null;

            if (tipo == "DATA_HORA")
            {
                if (!DateTime.TryParseExact((p.DtPonto ?? "").Trim(), new[] { "yyyy-MM-ddTHH:mm", "yyyy-MM-ddTHH:mm:ss", "yyyy-MM-dd HH:mm" },
                        CultureInfo.InvariantCulture, DateTimeStyles.None, out var lido))
                    return Resposta.Atencao("Informe o dia e a hora para voltar.");
                ponto = lido;
            }
            if (senha.Length == 0)
                return Resposta.Atencao("Digite a sua senha para confirmar.");

            var conferida = false;
            if (senha.Length <= 128)
            {
                var dados = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Usuario_Login_Obter",
                    new Dictionary<string, object?> { ["Login"] = usuario.Login }, null, http.RequestAborted);
                var hash = dados.Bytes("SENHA_HASH");
                var salt = dados.Bytes("SENHA_SALT");
                var iteracoes = dados.Int("SENHA_ITERACOES") ?? 0;
                if (hash is { Length: 32 } && salt is { Length: >= 16 } && iteracoes >= Seguranca.IteracoesMinimas
                    && dados.Texto("SENHA_ALGORITMO") == Seguranca.Algoritmo)
                    conferida = Seguranca.SenhaConfere(senha, salt, iteracoes, hash);
                else
                    Seguranca.SimularConferencia(senha, Seguranca.IteracoesMinimas);
            }

            var resultado = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Backup_Restauracao_Solicitar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["TipoPonto"] = Banco.Cortar(tipo, 10),
                ["IdBackup"] = tipo == "BACKUP" ? p.IdBackup : null,
                ["DtPonto"] = ponto,
                ["Motivo"] = Banco.Cortar(p.Motivo?.Trim(), 400),
                ["Confirmacao"] = Banco.Cortar(p.Confirmacao?.Trim(), 20),
                ["SenhaConferida"] = conferida
            }, usuario, http.RequestAborted);
            if (!resultado.Bool("SUCESSO"))
                return Resposta.Atencao(resultado.Texto("MENSAGEM"));
            logger.LogWarning("Pedido de restauração {Id} registrado por {Login}", resultado.Int("ID_RESTAURACAO"), usuario.Login);
            return Resposta.Ok(new { id = resultado.Int("ID_RESTAURACAO") }, resultado.Texto("MENSAGEM"));
        });

    private static Task<IResult> Cancelar(RestauracaoCancelarPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            if (p.IdRestauracao is not > 0)
                return Resposta.Atencao("Escolha o pedido para cancelar.");
            var resultado = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Backup_Restauracao_Cancelar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdRestauracao"] = p.IdRestauracao
            }, usuario, http.RequestAborted);
            if (!resultado.Bool("SUCESSO"))
                return Resposta.Atencao(resultado.Texto("MENSAGEM"));
            return Resposta.Ok(new { id = resultado.Int("ID_RESTAURACAO") }, resultado.Texto("MENSAGEM"));
        });
}
