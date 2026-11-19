# Pedidos para desenvolvimento futuro (lista viva)

Lista única dos pontos que o Celso vai passando para desenvolver mais adiante, em qualquer conversa. Toda conversa registra aqui o pedido (com data e as palavras do Celso), sem desenvolver na hora; quando chegar a fase certa, o item vira proposta, é aprovado e desenvolvido, e a situação muda aqui.

O resumo da tabela não substitui o texto do Celso: **cada leva fica guardada palavra por palavra** no fim deste arquivo ("Textos originais"), e a proposta de cada item parte do texto original.

Situação: **ANOTADO** (só registrado) → **PROPOSTO** (proposta feita, aguardando aprovação) → **APROVADO** → **FEITO** (com a referência do que foi feito) ou **DESCARTADO** (com o motivo).

## Diretrizes gerais do Celso (19/11/2026, valem para todos os pedidos)

- **Tudo o que puder é parâmetro.** Configurações de instalação, habilitar módulos inteiros ou tela por tela e outras já definidas: **só o Celso** (administrador geral). Parâmetros de uso do sistema: o Celso e o administrador da empresa.
- Os módulos e as coisas novas são **liberados pelo Celso** ao cliente quando ele achar conveniente (contrato de 1 ano de desenvolvimento). Por isso todo item novo nasce com **habilitar/desabilitar** (licença/módulo/tela), e o sistema serve para instalar em outra empresa depois.
- O Claude pode propor desenvolver qualquer pedido desta lista **quando achar oportuno** (continua valendo: propor e esperar a aprovação antes de construir).
- **A cada pedido novo, pesquisar no mercado** algo parecido para sugerir boas práticas e modelos atualizados (feito na hora da proposta).
- **Cores suaves** em todo o sistema, respeitando as preferências do usuário.
- **Manter sempre atualizados os guias de instalação e de controle do sistema** (`docs/GUIA_DO_CELSO.md`, requisitos de instalação): "você é meu guia".
- Desenvolver **em etapas**, cada uma bem feita, sem gastar os créditos da semana de uma vez.

## Lista

| Nº | Data | Pedido (resumo) | Módulo / fase sugerida | Situação | Observações |
|----|------|-----------------|------------------------|----------|-------------|
| P01 | 19/11/2026 | **Feriados e dias úteis**: função que diz se um dia é útil e qual o próximo dia útil, para vencimento de boletos e onde mais importar. Feriados nacionais (fixos e móveis, calculados pela Páscoa), mais uma tabela de feriados municipais do lugar da instalação (Poços de Caldas/MG: 13/05 padroeiro e 06/11 aniversário da cidade) e outras datas que o cliente quiser cadastrar. | Base `SIS`/`FIN`; antes da fase 6 (boletos). Pequeno: pode entrar já na fase 4 | ANOTADO | Sugestão: Carnaval (segunda e terça) e Quarta-feira de Cinzas como "dia sem expediente bancário" configurável; feriado com abrangência (nacional, estadual, municipal) e "repete todo ano"; vencimento que cai em dia não útil vai para o próximo dia útil (regra bancária), parâmetro por tipo de lançamento. |
| P02 | 19/11/2026 | **Ocorrências mensais** (lançamentos recorrentes: energia, internet, aluguel etc., débito ou crédito, com todos os campos do movimento). Gerar no automático ou não; quantos dias antes da virada do mês gera; quantos meses para frente. Quando o lançamento real mais recente gerado pela ocorrência é **confirmado**, o valor novo atualiza os lançamentos futuros **ainda em aberto** daquela ocorrência (parâmetro por ocorrência, já marcado "Sim"). Os lançamentos gerados no mês ficam num **lote do mês**. | `FIN`, fase 4 (telas do financeiro) ou logo depois | ANOTADO | O Access tem a tabela (135 ocorrências em `legado/dados_brutos/Ocorrencias Mensais.csv`, com DiaVencimento) e o controle do último mês gerado: **migrar** quando o módulo existir. Sugestões do mercado a confirmar na proposta: frequência além de mensal (semanal, bimestral, anual), data final ou número de vezes, dia fixo ou "dia útil", reajuste anual por índice (aluguel), valor fixo ou estimado, pausar/encerrar, aviso de ocorrência não gerada. Usa P01 (dia útil). |
| P03 | 19/11/2026 | **Tela inicial (o "xodó" do sistema)**, caprichar no visual e na usabilidade. Preferência do usuário: abrir em **lista** (ocorrências pendentes linha a linha) ou em **calendário**, e o período padrão. Barra superior com totais D/C/Saldo do que está na tela. Períodos: semana, quinzena, mês, bimestre, trimestre, quadrimestre, ano, N anos ou datas escolhidas; nos agrupados, um quadro por grupo com seus totais. No semanal/mensal, cada dia mostra D, C e S alinhados (D vermelho, C azul, S vermelho se negativo e azul se positivo, tons próximos e bonitos). Clique no dia/mês/quadro abre a lista dos lançamentos e, dela, o lançamento para manutenção; botão **Voltar** sempre devolve ao nível anterior. Setas anterior/próximo em cada tipo (menos lista e período livre). Período sem ocorrências mensais geradas entra nos totais com os valores da tabela de ocorrências (projeção); na lista aparecem como lançamento "fictício" do dia 1, bloqueado e com cor diferente. | Fase 4 (depois das telas do financeiro e de P02) | ANOTADO | Resposta à dúvida do registro fictício: **não gravar nada no banco**. A projeção é calculada na hora (a consulta devolve as linhas projetadas marcadas como PROJEÇÃO, só leitura, cor própria); não há o que apagar, nem conflito na rede. Agenda da semana (versão 1) vira parte desta tela. |
| P04 | 19/11/2026 | **Totais só para usuário gerencial**: permissão por usuário (dada pelo administrador geral e pelo administrador do sistema) para ver totais e dados sensíveis na tela inicial. Sem ela, a tela mostra os lançamentos dia a dia, mas sem os totais D/C/Saldo. Relatório que o usuário tem permissão de rodar mostra os totais normalmente. | Junto com P03 | ANOTADO | Vira uma ação de permissão ("ver totais") no perfil/usuário, no padrão da `SIS`. |
| P05 | 19/11/2026 | **Fluxo de caixa gerencial com gráficos** (pizza, barras e o que os programas modernos de análise financeira e de vendas de imóveis usam). **Simulações** que o cliente gosta de fazer: tipo ainda a definir; primeiro o fluxo com dados reais, depois se encaixam as simulações. | 1.x (painel com drill-down) | ANOTADO | Perguntar à CMJ que simulações fazem hoje (planilhas?) antes da proposta. |
| P06 | 19/11/2026 | **Tema do sistema**: seguir o Windows (claro/escuro) ou outro à escolha do usuário, nas preferências do usuário, se não for oneroso. | Fase 4 (preferências do usuário) | ANOTADO | Viável e barato: o navegador já informa o tema do Windows; as cores do sistema já estão em variáveis. Fazer junto com a tela de preferências (P03). |
| P07 | 19/11/2026 | **Agenda de compromissos**: pessoal ou corporativo; data; compromisso; aviso por e-mail com antecedência (N dias), aviso no dia, ou sem aviso. Pessoal só aparece para quem cadastrou; corporativo aparece para todos, com fundo levemente diferente. | Fase 4 ou 1.x (independente; pode entrar cedo) | ANOTADO | Reaproveita o envio de e-mail e o agendador de rotinas que já existem (boletim). Mostrar os compromissos também no calendário da tela inicial (P03). |

## Detalhes que o resumo da tabela não mostra (leva 1)

- P03: na tela de abertura, um **botão de preferências** (ou tela de preferências do sistema, para todos os usuários). No calendário anual, os quadros são os **meses** dentro do ano; no bimestral, os grupos de dois meses; e assim por diante, cada quadro com D/C/Saldo. Setas: exemplo do Celso, trimestre Nov/Dez/Jan → próximo → Fev/Mar/Abr. Formato de cada dia: "D - 1.000,00", embaixo alinhado "C - 2.500,00", embaixo "S - 1.500,00". O Voltar desce e sobe nível por nível: lançamento → lista → quadro (bimestral ou o que estava escolhido). A projeção usa os valores da tabela de ocorrências **naquele momento**.

## Textos originais

### Leva 1 (19/11/2026), recebida do documento "Pedidos Futuros" do Celso

> TUDO QUE PUDER DEVE SER PARAMETRIZADO NO SISTEMA
> o que for configurações de instalação, habilitar módulos inteiros ou tela por tela e outros já definidos por você somente por mim
> o que for de utilização do sistema: por mim e o admin do sistema
> feriado 
> criar função para detectar feriados nacionais e dias úteis para calculo da data de vencimento de boletos e etc, onde for importante saber se é dia útil
> vai precisar de uma tabela (ou algo parecido) para guardar os feriados municipais onde o sistema esta sendo utilizado por exemplo meu cliente deste desenvolvimento está em Poços de Caldas/mg (onde também moro) e temos feriados dia 13 de Maio - Padroeiro da Cidade e 6 de Novembro Aniversário da cidade, ou ser digitado alguma outra data que o cliente deseje
> Ocorrências Mensais
> não sei se você já viu no sistema do access tinhamos um módulo ou uma tela que gerava por responsabilidade do usuário vários lançamentos automáticos todo mês exemplo: energia elétrica, internet, aluguel, e assim por diante pode ser lançamento de qualquer tipo débito ou crédito e todos os campos que tem no movimento real tem nesta tabela ela evita digitar todo mês as mesmas coisas
> algumas idéias para este módulo:
> se o usuário quer deixar no automático a geração e com quantos dias de antecedência antes da virada do mês o sistema gera os lançamentos, e quantos meses para frente deve ser gerado
>
>
> o valor do lançamento real mais recente quando confirmado e que foi gerado a partir deste módulo atualiza os lançamentos futuros que já foram gerados com base no que esta lá na tabela (parâmetro para cada registro desta tabela) mas deixar pré marcado com “sim”
> então se foi confirmado sabemos que atualiza=’Sim” o valor dos meses gerados para frente desta ocorrência ficam com o valor novo se o documento estiver ainda em aberto
> os lançamentos gerados por este módulo também devem ter um lote para acesso a todos daquele mês gerado (lote do mês) ou algo assim
> aceito boas sugestões e algo que outros softwares tenham por ai no mercado com uma função igual ou similar a este módulo
> calendário: esta tela inicial será o xodó do sistema caprichar no visual e usabilidade
> na tela de abertura do sistema:
> um botão para escolher como preferências (ou uma tela de preferências do sistema para todos usuários)
> Tipo de abertura do Sistema:
> a relação de ocorrências ainda pendentes linha a linha ou
> em formato de calendário 
> e qual período padrão ver a seguir
> na barra superior mostrar totais deb/cred e saldo (apenas dos movimentos selecionados) opção para semanal, quinzenal, mensal, bimestral, trimestral, anual ou qtd de anos que quer ou período a escolher data inicial e datafinal conforme a escolha a relação ou o calendario são montados no caso de ser calendário montar como tabelas caso a escolha seja anual, bimestre, trimestre, quadrimestre, com os totais deb//cred/saldo de cada agrupamento dentro de cada período anual dentro dos meses, bimestre dentro de cada agrupamento de dois meses e assim por diante
> calendário: quando semanal ou mensal cada dia mostra seus totais de deb/cred/saldo no tipo D - 1.000,00 embaixo alinhado C - 2.500,00 embaixo alinhado S - 1.500,00 valores de D em vermelho C - azul S - vermelho se negativo ou azul se positivo os vermelhos e azuis de valores devem ter uma pequena diferença de tonalidade para ficar bonita a visulalização
> calendário: ao clicar em um dia ou mês ou quadro de bimestre etc o sistema abre a lista daquilo que foi relacionado (os lançamentos) para ser analisado linha a linha e clicando-se abre-se o movimento para manutenção caso o usuário deseje
> quando for assim sempre ter o botão “Voltar” para que se abrir até o nivel de alterar movimento eu retorne para onde estava ou seja, volta para a lista que foi aberta depois para o quadro bimestral ou outro que estava escolhido
> calendário: deve ter setinhas para próximo anterior para cada tipo de visualização escolhida menos para quando linha a linha ou período exemplo: se escolhi trimestre e estou visualizando Nov/dez/jan clico em próximo e ele me mostra fev/mar/abr e assim por diante com os outros modelos 
> ao escolher um período em que não tenha sido gerado ocorrências mensais os totais devem incluir a tabela de ocorrências mensais com os valores que estão lá naquela hora (não tem problema) para o cliente ter uma noção fiél ou bem próximo do valor real do que vai acontecer com D/C/Saldo
> caso ele clique para ver linha a linha ele verá um lançamento ficticio dentro de cada mês com data dia 1 por exemplo daquele valor classificado como ocorrência mensal (apenas para esta finanlidade) e que não deve ser editado quando retornar ao estado da tela anterior este registro ficticio deve desaparecer, acredito que você terá de bolar alguma segurança para que este registro sempre desapareça quando não estiver sendo visualizado ? ou quando sair do sistema ele existir tem de apagar para aquele usuário pois estarem em rede ou se você me sugerir algo a respeito será muito bem aceito, sempre bloquear este registro e diferencia-lo com alguma cor diferente dos demais
> configurar visualizar os totais na tela de abertura por usuário do tipo usuário gerencial (aquele que vê totais e dados sensíveis da empresa) a cargo do admin geral e admin do sistema, se for relatório e o usuário tiver acesso para executa-lo não suprimir totais será mostrado normalmente mas na tela de entrada por exemplo ele vê tudo D/C/Saldo dia a dia ou de acordo com a tela escolhida menos os totais de D/C/Saldo
> fluxo de caixa gerencial com gráficos bolintos e de fácil entendimento (pizza, barras, e outros) e tudo que é utilizado nos softwares modernos de analise financeira / vendas de imóveis / etc
> cliente gosta de fazer simulações que eu ainda não sei de que tipo mas deixe para futuro desenvolvimento
> mas com dados reais podemos montar o fluxo e depois encaixamos aquilo que ele gosta de simular
> tema do sistema: seguir windows, ou outro de preferência do usuário (cores padrão onde for possível) se for viável fazer isto pode fazer e deixe em preferências do usuário caso contrário se for muito honeroso e desnecessário não precisa
> elaborar agenda de compromissos 
> ao entrar com um compromisso marca se é pessoal ou corporativo, campo data, compromisso, se avisa por e-mail com antecedencia (escolher qtd dias), avisa no dia, não avisa
> se pessoal apenas o login de quem colocou o compromisso encherg na agenda
> se corporativo mostra em qualquer login que acesse o sistema e ter cor de fundo levemente diferenciada do pessoal
> sempre usar cores suaves no sistema (de acordo com as preferências do usuário)
> sempre manter nossos guias de instalação e controle do sistema atualizados para mim não me perder com tanta coisa sendo construida você é meu guia
> os modulos e coisas novas serão liberados por mim para o cliente quando eu achar conveniente pois tenho um contrato de 1 ano de desenvolvimento com o cliente para desenvolver tudo isso e mais coisas que virão depois, por isso estamos parametrizando todo sistema para num futuro cliente eu só tenho o trabalho de instalar o sistema desta construtora em outra devidamente protegido etc.
> então quando você achar conveniente e oportuno desenvolver qualquer idéia nova que coloco pode faze-lo pois ele será parâmetro de habilitado ou não
> sempre lembrando de que a cada “coisa nova” que peço procurar no mercado algo “parecido” para sugerir boas práticas e modelos de negócio atualizados
> apóes você ler e registrar este documento eu vou “zera-lo” para começe depois outra “leva” de pedidos futuoros e sempre que quiser vou pedir pra você ler e assim por diante
> avalie minhas idéias e pedidos e vamos em frente estou empolgado com o sistema a IA Claude é simplesmente excelente.
> só não fazemos tudo de uma vez para a cada etapa desenvolvida darmos nosso melhor e não acabar com meus créditos da semana rapidamente
