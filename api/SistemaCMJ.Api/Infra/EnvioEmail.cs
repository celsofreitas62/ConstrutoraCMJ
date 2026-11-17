// =============================================================================
//  SistemaCMJ.Api - Infra/EnvioEmail.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 17/11/2026 (fase 3c)
//  Descrição : Processador da fila de e-mails (PADRAO_EMAIL seção 1). O SQL
//              monta e enfileira; aqui só se envia:
//                1) SIS_Email_Capturar pega até 20 e-mails pendentes;
//                2) envia cada um por SMTP (MailKit, UTF-8), com os anexos e a
//                   logomarca embutida (cid:logo_empresa);
//                3) SIS_Email_Resultado_Gravar registra ENVIADO, ERRO_TEMPORARIO
//                   (volta para a fila e tenta de novo) ou ERRO_PERMANENTE.
//              Um e-mail com problema não impede os outros (laço isolado).
//              Conta SMTP pela coluna CONTA da fila: seção "Smtp:Interna" ou
//              "Smtp:Externa" da configuração; Externa vazia usa a Interna.
//              A SENHA nunca fica no appsettings nem no banco: vem da variável
//              de ambiente Smtp__Interna__Senha (gravada pelo configurar_email.cmd).
//              Sem servidor ou senha configurados, não captura nada: os e-mails
//              continuam PENDENTES até a configuração existir.
//              17/11/2026: logomarca embutida no corpo (inline, sem nome de
//              arquivo: não aparece como anexo), versão em texto simples junto
//              com o HTML (menos chance de spam) e nome do remetente pelo
//              parâmetro SISTEMA_NOME quando a configuração não tiver um.
// =============================================================================
using System.Text.Json;
using MailKit;
using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace SistemaCMJ.Api.Infra;

public sealed class EnvioEmail(Banco banco, IConfiguration configuracao, ILogger<EnvioEmail> logger)
{
    private bool avisouSemConfiguracao;

    private sealed record ContaSmtp(string Servidor, int Porta, string Usuario, string Senha, string Remetente, string NomeRemetente)
    {
        public bool Completa => Servidor.Length > 0 && Usuario.Length > 0 && Senha.Length > 0 && Remetente.Length > 0;
    }

    private ContaSmtp LerConta(string conta)
    {
        var secao = configuracao.GetSection("Smtp:" + (conta.Equals("EXTERNA", StringComparison.OrdinalIgnoreCase) ? "Externa" : "Interna"));
        var c = new ContaSmtp(
            secao["Servidor"] ?? "", int.TryParse(secao["Porta"], out var porta) ? porta : 587,
            secao["Usuario"] ?? "", secao["Senha"] ?? "", secao["Remetente"] ?? "", secao["NomeRemetente"] ?? "");
        return c.Completa || conta.Equals("INTERNA", StringComparison.OrdinalIgnoreCase) ? c : LerConta("INTERNA");
    }

    /// <summary>Envia os e-mails pendentes. Devolve quantos foram tentados.</summary>
    public async Task<int> ProcessarAsync(string servidor, CancellationToken ct)
    {
        if (!LerConta("INTERNA").Completa)
        {
            if (!avisouSemConfiguracao)
                logger.LogWarning("Envio de e-mail desligado: falta configurar Smtp:Interna (servidor, usuário, remetente e a senha em Smtp__Interna__Senha). Os e-mails ficam na fila.");
            avisouSemConfiguracao = true;
            return 0;
        }
        avisouSemConfiguracao = false;

        var emails = await banco.ExecutarAsync("SIS.SIS_Email_Capturar",
            new Dictionary<string, object?> { ["Servidor"] = servidor, ["Quantidade"] = 20 }, null, ct);

        foreach (var email in emails)
        {
            var id = email.Long("ID_EMAIL") ?? 0;
            string resultado;
            string mensagem = "";
            try
            {
                await EnviarAsync(email, ct);
                resultado = "ENVIADO";
            }
            catch (FileNotFoundException erro)
            {
                resultado = "ERRO_PERMANENTE";
                mensagem = erro.Message;
            }
            catch (SmtpCommandException erro) when ((int)erro.StatusCode >= 500 && erro.ErrorCode != SmtpErrorCode.UnexpectedStatusCode)
            {
                resultado = "ERRO_PERMANENTE";
                mensagem = $"Recusado pelo servidor de e-mail ({(int)erro.StatusCode}): {erro.Message}";
            }
            catch (Exception erro) when (erro is not OperationCanceledException)
            {
                resultado = "ERRO_TEMPORARIO";
                mensagem = erro.GetType().Name + ": " + erro.Message;
                logger.LogWarning("E-mail {Id} não saiu: {Mensagem}", id, mensagem);
            }

            await banco.ExecutarAsync("SIS.SIS_Email_Resultado_Gravar", new Dictionary<string, object?>
            {
                ["IdEmail"] = id,
                ["Resultado"] = resultado,
                ["Mensagem"] = Banco.Cortar(mensagem, 1000),
                ["Servidor"] = servidor
            }, null, CancellationToken.None);
        }
        return emails.Count;
    }

    private async Task EnviarAsync(Linha email, CancellationToken ct)
    {
        var conta = LerConta(email.Texto("CONTA"));
        var mensagem = new MimeMessage();
        var nomeRemetente = conta.NomeRemetente.Length > 0 ? conta.NomeRemetente
            : await banco.ParametroAsync("SISTEMA_NOME", ct) is { Length: > 0 } nomeSistema ? nomeSistema : "SistemaCMJ";
        mensagem.From.Add(new MailboxAddress(nomeRemetente, conta.Remetente));
        AdicionarEnderecos(mensagem.To, email.Texto("PARA"));
        AdicionarEnderecos(mensagem.Cc, email.Texto("CC"));
        AdicionarEnderecos(mensagem.Bcc, email.Texto("CCO"));
        if (mensagem.To.Count + mensagem.Cc.Count + mensagem.Bcc.Count == 0)
            throw new FileNotFoundException("E-mail sem destinatário válido.");
        mensagem.Subject = email.Texto("ASSUNTO");

        var corpo = new BodyBuilder { HtmlBody = email.Texto("CORPO_HTML") };
        corpo.TextBody = TextoSimples(corpo.HtmlBody);

        if (corpo.HtmlBody.Contains("cid:logo_empresa", StringComparison.OrdinalIgnoreCase))
        {
            var logo = await CaminhoLogoAsync(ct);
            if (logo is not null)
            {
                var imagem = corpo.LinkedResources.Add("logo" + Path.GetExtension(logo), await File.ReadAllBytesAsync(logo, ct));
                imagem.ContentId = "logo_empresa";
                // Imagem do corpo, não anexo: inline e sem nome de arquivo.
                imagem.ContentDisposition = new ContentDisposition(ContentDisposition.Inline);
                imagem.ContentType.Name = null;
            }
            else
                corpo.HtmlBody = corpo.HtmlBody.Replace("<img src=\"cid:logo_empresa\"", "<img hidden src=\"\"", StringComparison.OrdinalIgnoreCase);
        }

        var anexos = email.Texto("ANEXOS_JSON");
        if (anexos.Length > 2)
            foreach (var a in JsonDocument.Parse(anexos).RootElement.EnumerateArray())
            {
                var caminho = a.TryGetProperty("CAMINHO", out var c) ? c.GetString() ?? "" : "";
                if (!File.Exists(caminho))
                    throw new FileNotFoundException("Anexo não encontrado: " + caminho);
                var nome = a.TryGetProperty("NOME_EXIBICAO", out var n) && n.GetString() is { Length: > 0 } texto ? texto : Path.GetFileName(caminho);
                var cid = a.TryGetProperty("CID", out var ci) ? ci.GetString() ?? "" : "";
                if (cid.Length > 0)
                    corpo.LinkedResources.Add(caminho).ContentId = cid;
                else
                    corpo.Attachments.Add(nome, await File.ReadAllBytesAsync(caminho, ct));
            }

        mensagem.Body = corpo.ToMessageBody();

        using var cliente = new SmtpClient();
        cliente.Timeout = 60_000;
        await cliente.ConnectAsync(conta.Servidor, conta.Porta, conta.Porta == 465 ? SecureSocketOptions.SslOnConnect : SecureSocketOptions.StartTls, ct);
        await cliente.AuthenticateAsync(conta.Usuario, conta.Senha, ct);
        await cliente.SendAsync(mensagem, ct);
        await cliente.DisconnectAsync(true, ct);
    }

    /// <summary>Versão em texto do HTML (parte "text/plain" do e-mail).</summary>
    private static string TextoSimples(string html)
    {
        var t = System.Text.RegularExpressions.Regex.Replace(html, @"<(head|style|script)[^>]*>.*?</\1>", "", System.Text.RegularExpressions.RegexOptions.Singleline | System.Text.RegularExpressions.RegexOptions.IgnoreCase);
        t = System.Text.RegularExpressions.Regex.Replace(t, @"<li[^>]*>", "\n - ", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
        t = System.Text.RegularExpressions.Regex.Replace(t, @"<(br|/p|/div|/tr|/h\d|/ul)[^>]*>", "\n", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
        t = System.Text.RegularExpressions.Regex.Replace(t, @"<[^>]+>", "");
        t = System.Net.WebUtility.HtmlDecode(t);
        t = System.Text.RegularExpressions.Regex.Replace(t, @"[ \t]+", " ");
        t = System.Text.RegularExpressions.Regex.Replace(t, @"\s*\n\s*(\n\s*)+", "\n\n");
        return t.Trim();
    }

    private static void AdicionarEnderecos(InternetAddressList lista, string texto)
    {
        foreach (var parte in texto.Split([';', ','], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            if (MailboxAddress.TryParse(parte, out var endereco))
                lista.Add(endereco);
    }

    /// <summary>Arquivo da logomarca dos e-mails (parâmetro EMPRESA_LOGO_EMAIL), na pasta
    /// IDENTIDADE_PASTA ou na pasta reserva da configuração. Null se não achar.</summary>
    public async Task<string?> CaminhoLogoAsync(CancellationToken ct)
    {
        var arquivo = await banco.ParametroAsync("EMPRESA_LOGO_EMAIL", ct);
        if (arquivo.Length == 0 || Path.GetFileName(arquivo) != arquivo) return null;
        foreach (var pasta in new[] { await banco.ParametroAsync("IDENTIDADE_PASTA", ct), configuracao["Identidade:PastaReserva"] ?? "" })
            if (pasta.Length > 0 && File.Exists(Path.Combine(pasta, arquivo)))
                return Path.Combine(pasta, arquivo);
        return null;
    }
}
