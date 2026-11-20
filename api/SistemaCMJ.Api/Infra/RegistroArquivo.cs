// =============================================================================
//  SistemaCMJ.Api - Infra/RegistroArquivo.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 20/11/2026 (fase 3d)
//  Descrição : Registro da API em arquivo texto, um por dia
//              (siscmj-AAAAMMDD.log), sem biblioteca de terceiros.
//              Pasta e dias guardados vêm da configuração:
//                Registro:Pasta       (vazio = %ProgramData%\SisCMJ\logs)
//                Registro:DiasManter  (padrão 30; arquivos mais velhos são apagados)
//              Grava Information para cima do sistema e Warning para cima do
//              ASP.NET (filtros de "Logging" no appsettings). Nunca grava corpo
//              de requisição: senha, CPF e outros dados pessoais não vão para o
//              arquivo. Os erros de negócio continuam em SIS.Log_Erro.
// =============================================================================
using System.Collections.Concurrent;
using System.Text;

namespace SistemaCMJ.Api.Infra;

public sealed class RegistroArquivoProvider : ILoggerProvider
{
    private readonly string pasta;
    private readonly int diasManter;
    private readonly object trava = new();
    private readonly ConcurrentDictionary<string, RegistroArquivo> registros = new();
    private string diaAtual = "";

    public RegistroArquivoProvider(IConfiguration configuracao)
    {
        var configurada = configuracao["Registro:Pasta"];
        pasta = string.IsNullOrWhiteSpace(configurada)
            ? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "SisCMJ", "logs")
            : Environment.ExpandEnvironmentVariables(configurada);
        diasManter = int.TryParse(configuracao["Registro:DiasManter"], out var d) && d > 0 ? d : 30;
    }

    public string Pasta => pasta;

    public ILogger CreateLogger(string categoria) => registros.GetOrAdd(categoria, c => new RegistroArquivo(c, this));

    internal void Gravar(string texto)
    {
        try
        {
            lock (trava)
            {
                var hoje = DateTime.Now.ToString("yyyyMMdd");
                if (hoje != diaAtual)
                {
                    Directory.CreateDirectory(pasta);
                    diaAtual = hoje;
                    Limpar();
                }
                File.AppendAllText(Path.Combine(pasta, "siscmj-" + hoje + ".log"), texto, Encoding.UTF8);
            }
        }
        catch
        {
            // O registro nunca derruba o sistema (disco cheio, pasta sem permissão...).
        }
    }

    private void Limpar()
    {
        var limite = DateTime.Now.Date.AddDays(-diasManter);
        foreach (var arquivo in Directory.EnumerateFiles(pasta, "siscmj-*.log"))
            if (File.GetLastWriteTime(arquivo) < limite)
                File.Delete(arquivo);
    }

    public void Dispose() { }
}

internal sealed class RegistroArquivo(string categoria, RegistroArquivoProvider provider) : ILogger
{
    public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;

    public bool IsEnabled(LogLevel nivel) => nivel >= LogLevel.Information && nivel != LogLevel.None;

    public void Log<TState>(LogLevel nivel, EventId evento, TState estado, Exception? erro, Func<TState, Exception?, string> formatar)
    {
        if (!IsEnabled(nivel)) return;
        var nome = nivel switch
        {
            LogLevel.Information => "INFO ",
            LogLevel.Warning => "AVISO",
            LogLevel.Error => "ERRO ",
            LogLevel.Critical => "CRITICO",
            _ => nivel.ToString().ToUpperInvariant()
        };
        var sb = new StringBuilder();
        sb.Append(DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff")).Append(" [").Append(nome).Append("] ")
          .Append(categoria).Append(": ").Append(formatar(estado, erro)).AppendLine();
        if (erro is not null) sb.AppendLine("    " + erro.ToString().Replace(Environment.NewLine, Environment.NewLine + "    "));
        provider.Gravar(sb.ToString());
    }
}
