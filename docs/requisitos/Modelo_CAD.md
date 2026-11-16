# Modelo de dados: bloco CAD (proposta)

Conversa "03 – Modelo de dados", 16/11/2026. Base: decisões do Celso de 16/11/2026, plano de contas aprovado (`Plano_Contas.md`) e o Access (`EmpMaster` 35, `EmpVinculada` 57, `Parceiros` 1.437).

> **Situação: proposta aguardando aprovação do Celso.** Nada foi criado no banco.

## 1. Decisões que orientam o desenho (Celso, 16/11/2026)

- **`CAD.Empresa` é livre**: o administrador cadastra quantas empresas quiser (Construtora, SPEs, Holding), cada uma com seu CNPJ. A licença tem **um só CNPJ**, que serve apenas para registrar o software e impedir a cópia; não limita as empresas do cadastro.
- **Obra por administração para terceiros continua**; a taxa de administração é receita da CMJ.
- **Conta bancária vinculada**: escolha no cadastro (da empresa e da obra/centro de custo).

## 2. O que muda em relação ao Access

| Access | Sistema novo |
|---|---|
| `EmpMaster` mistura empresas do grupo, clientes de obra por administração e imóveis | empresas do grupo em `CAD.Empresa`; cliente de obra por administração em `CAD.Pessoa`; imóvel próprio e área administrativa em `CAD.Centro_Custo` |
| `EmpVinculada` (obra/empreendimento) | `CAD.Centro_Custo` do tipo `OBRA` (os dados próprios da obra e das unidades ficam em `OBRA` e `IMOB`, propostos depois) |
| `Parceiros` com três marcas (cliente, fornecedor, funcionário) e um campo de e-mail | `CAD.Pessoa` com papéis + contatos em tabela própria (vários e-mails e telefones, marcando qual recebe cobrança) + vínculos (cônjuge, sócio, representante) |
| Registros `sistema`, `N/A`, `Escolha a Empresa`, `TESTE` | não migram |

## 3. Tabelas propostas

### 3.1 `CAD.Empresa` (empresas do grupo)
`ID_EMPRESA`, `RAZAO_SOCIAL`, `NOME_FANTASIA`, `CNPJ` (VARCHAR 14, aceita o CNPJ alfanumérico, único), `TIPO` (`CONSTRUTORA` / `SPE` / `HOLDING` / `OUTRA`), `INSCRICAO_ESTADUAL`, `INSCRICAO_MUNICIPAL`, `REGIME_TRIBUTARIO` (ex.: `RET`, `LUCRO_PRESUMIDO`, `SIMPLES`), endereço (CEP, logradouro, número, complemento, bairro, cidade, UF), `EMAIL`, `TELEFONE`, `ID_CONTA_BANCARIA_PADRAO` (FK para `BANCO.Conta`, ligada depois que o `BANCO` existir), `ATIVO`, colunas de auditoria (regra 34). Logomarca da empresa como anexo `LOGOMARCA` (mesma solução da obra).

### 3.2 `CAD.Pessoa` (clientes, fornecedores, funcionários, corretores, clientes de obra por administração)
- Identificação: `ID_PESSOA`, `TIPO_PESSOA` (`F`/`J`), `NOME` (razão social na PJ), `NOME_FANTASIA`, `CPF_CNPJ` (VARCHAR 14, só dígitos/letras; **único quando preenchido**, índice filtrado), `RG`, `ORGAO_EMISSOR`, `INSCRICAO_ESTADUAL`, `INSCRICAO_MUNICIPAL`.
- Dados para contrato de venda (PF): `DT_NASCIMENTO`, `NACIONALIDADE`, `PROFISSAO`, `ESTADO_CIVIL`, `REGIME_BENS`.
- Endereço principal (mesmos campos da empresa).
- Papéis (BIT): `CLIENTE`, `FORNECEDOR`, `FUNCIONARIO`, `CORRETOR` (uma pessoa pode ter vários).
- Pagamento a fornecedor: `PIX_TIPO`, `PIX_CHAVE`, `BANCO_CODIGO`, `AGENCIA`, `CONTA`.
- `OBSERVACAO`, `ATIVO`, `CODIGO_ACCESS` (migração), auditoria.
- Busca por parte do nome (pedido 3.1): índice em `NOME`; a busca geral também procura em `NOME_FANTASIA` e no documento.

### 3.3 `CAD.Pessoa_Contato`
`ID_PESSOA`, `TIPO` (`EMAIL` / `CELULAR` / `TELEFONE` / `WHATSAPP`), `VALOR`, `NOME_CONTATO` (ex.: "Maria, financeiro"), `PRINCIPAL`, `RECEBE_COBRANCA` (boleto, régua, extrato), `ATIVO`.

### 3.4 `CAD.Pessoa_Vinculo`
`ID_PESSOA`, `ID_PESSOA_VINCULADA`, `TIPO` (`CONJUGE` / `SOCIO` / `REPRESENTANTE` / `PROCURADOR`). O cônjuge/coobrigado é uma pessoa cadastrada, ligada aqui; a venda escolhe quem assina.

### 3.5 `CAD.Centro_Custo` (onde o dinheiro é aplicado ou gerado)
`ID_CENTRO_CUSTO`, `ID_EMPRESA` (dona), `CODIGO` (curto, ex.: `62`, `ESC`), `DESCRICAO`, `TIPO` (`OBRA` / `ADMINISTRATIVO` / `IMOVEL_PROPRIO` / `PARTICULAR`), `ID_CONTA_BANCARIA_PADRAO` (se vazio, usa a da empresa), `ATIVO`, `CODIGO_ACCESS`, auditoria.
- Todo lançamento leva **conta do plano + centro de custo**; a empresa do lançamento vem do centro de custo.
- Os dados de obra (endereço, CNO, datas, área, situação, controla custo, **administração para terceiro: cliente + taxa %**) ficam em `OBRA.Obra`, 1 para 1 com o centro de custo `OBRA`; empreendimento com unidades à venda em `IMOB.Empreendimento`. Propostos na sequência desta etapa.

### 3.6 Plano de contas (já aprovado)
`CAD.Plano_Grupo`, `CAD.Plano_Subgrupo`, `CAD.Plano_Conta` + `CAD.vw_CAD_Plano_Conta`, como em `Plano_Contas.md`.

## 4. Procedures (padrão da 02: `@IdUsuario`, permissão no início, 1 linha `SUCESSO`/`MENSAGEM`)

Para cada cadastro: `Listar`, `Obter`, `Gravar` (inclui/altera), `Excluir` (só desativa). Exemplo: `CAD.CAD_Pessoa_Listar/Obter/Gravar/Excluir`; contatos e vínculos gravados junto com a pessoa (JSON na entrada, tudo-ou-nada). Auditoria ligada em todas as tabelas pelo gerador da 02c. Telas novas no menu do módulo `CAD`: Empresas, Pessoas, Centros de custo, Plano de contas.

## 5. Migração (regras repetíveis)

- `Parceiros` → `CAD.Pessoa`: tipo F/J pelo documento (10 têm CPF e CNPJ: fica o CNPJ e o CPF vai para a observação), papéis pelas marcas (34 sem papel nenhum: ficam sem papel e inativos se nunca usados), `Inativo` → `ATIVO`, e-mail e telefones → `Pessoa_Contato`. Documento repetido (14): fica um registro só e o de-para guarda os códigos antigos.
- `EmpMaster`/`EmpVinculada` → empresa, pessoa ou centro de custo conforme uma tabela de classificação (`MIG`), que o Celso confere uma vez.

## 6. Decisões para o Celso

1. Aprovar a separação e as tabelas da seção 3.
2. Documento repetido na migração (14 pessoas): juntar num registro só, como proposto?
3. Dados bancários/PIX do fornecedor no cadastro da pessoa: quer agora?
4. O Access tem a marca `Contabil` na obra (`EmpVinculada`): existe obra que não vai para a contabilidade? Se sim, vira marca no centro de custo.
