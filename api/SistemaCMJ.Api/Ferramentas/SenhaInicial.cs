// =============================================================================
//  SistemaCMJ.Api - Ferramentas/SenhaInicial.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 16/11/2026 (fase 3b)
//  Descrição : Define a PRIMEIRA senha de um usuário que ainda não tem senha
//              (ex.: "celso" e "admin" criados na instalação, sem senha).
//              Roda só no próprio servidor/notebook, pela linha de comando:
//                  dotnet run -- senha-inicial celso
//              Recusa se o usuário já tem senha: depois disso, a troca é pela
//              tela (o próprio usuário) ou pelo administrador (senha provisória).
// =============================================================================
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Ferramentas;

public static class SenhaInicial
{
    public static async Task<int> RodarAsync(string[] argumentos, Banco banco)
    {
        if (argumentos.Length < 2 || string.IsNullOrWhiteSpace(argumentos[1]))
        {
            Console.WriteLine("Uso: dotnet run -- senha-inicial <login>");
            return 1;
        }

        var login = argumentos[1].Trim().ToLowerInvariant();
        var dados = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Usuario_Login_Obter",
            new Dictionary<string, object?> { ["Login"] = login }, null);

        if (!dados.Bool("ENCONTRADO"))
        {
            Console.WriteLine($"Usuário '{login}' não encontrado.");
            return 1;
        }
        if (dados.Bytes("SENHA_HASH") is not null)
        {
            Console.WriteLine($"O usuário '{login}' já tem senha. Troque pela tela do sistema ou peça ao administrador uma senha provisória.");
            return 1;
        }

        var tamanhoMinimo = await banco.ParametroInteiroAsync("SENHA_TAMANHO_MINIMO");
        string senha;
        while (true)
        {
            senha = LerSenha("Nova senha: ");
            var recusa = Seguranca.ConferirRegras(senha, tamanhoMinimo);
            if (recusa.Length > 0) { Console.WriteLine(recusa); continue; }
            if (LerSenha("Repita a senha: ") != senha) { Console.WriteLine("As duas senhas não estão iguais."); continue; }
            break;
        }

        var idUsuario = dados.Int("ID_USUARIO") ?? 0;
        var iteracoes = Math.Max(await banco.ParametroInteiroAsync("SENHA_PBKDF2_ITERACOES"), Seguranca.IteracoesMinimas);
        var (hash, salt) = Seguranca.NovaSenha(senha, iteracoes);
        var contexto = new Contexto(idUsuario, login, "", false, Environment.MachineName, "FERRAMENTA:SENHA_INICIAL");
        var resultado = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Usuario_Senha_Gravar", new Dictionary<string, object?>
        {
            ["IdUsuario"] = idUsuario,
            ["IdUsuarioAlvo"] = idUsuario,
            ["SenhaHash"] = hash,
            ["SenhaSalt"] = salt,
            ["Iteracoes"] = iteracoes,
            ["Algoritmo"] = Seguranca.Algoritmo
        }, contexto);

        Console.WriteLine(resultado.Texto("MENSAGEM"));
        return resultado.Bool("SUCESSO") ? 0 : 1;
    }

    private static string LerSenha(string pergunta)
    {
        Console.Write(pergunta);
        var texto = new System.Text.StringBuilder();
        while (true)
        {
            var tecla = Console.ReadKey(intercept: true);
            if (tecla.Key == ConsoleKey.Enter) break;
            if (tecla.Key == ConsoleKey.Backspace)
            {
                if (texto.Length > 0) { texto.Length--; Console.Write("\b \b"); }
                continue;
            }
            if (!char.IsControl(tecla.KeyChar)) { texto.Append(tecla.KeyChar); Console.Write('*'); }
        }
        Console.WriteLine();
        return texto.ToString();
    }
}
