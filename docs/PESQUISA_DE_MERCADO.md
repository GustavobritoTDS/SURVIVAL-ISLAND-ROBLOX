# Pesquisa de Mercado: Sobrevivência no Roblox

**Projeto:** Survival Island (náufrago em ilha tropical)
**Data da coleta:** 22/11/2026
**Método:** dados numéricos tirados direto das APIs públicas do Roblox no dia da coleta, mais guias, trackers e o DevForum. Não acessei o Reddit, porque ele bloqueia o agente de busca. As reclamações vêm do DevForum, das wikis e da leitura das notas e da monetização de cada jogo.

### Fontes de dados primárias (consultadas em 22/11/2026)
- Estatísticas: `https://games.roblox.com/v1/games?universeIds=...` (jogando agora, visitas, favoritos, datas)
- Votos: `https://games.roblox.com/v1/games/votes?universeIds=...`
- Game Passes: `https://apis.roblox.com/game-passes/v1/universes/{id}/game-passes?passView=Full`
- Developer Products: `https://apis.roblox.com/developer-products/v2/universes/{id}/developerproducts`

"Jogando agora" é um retrato de um único momento: 22/11/2026, um domingo, por volta das 17h UTC. Não é média nem pico.

---

## 1. Tabela comparativa

### 1.1 Números (API Roblox, 22/11/2026)

| Jogo (universeId) | Criador | Lançado | Jogando agora | Visitas | Favoritos | Aprovação | Máx./servidor |
|---|---|---|---|---|---|---|---|
| **99 Nights in the Forest** (7326934954) | Grandma's Favourite Games | mar/2025 | 223.722 | 30,63 bi | 10,35 mi | 90,5% | 25 |
| **The Survival Game** (3989768869) | Simple Games Incorporated | out/2022 | 856 | 336,2 mi | 878,7 mil | 82,3% | 40 |
| **Booga Booga** (= "Reborn") (4154513353) | Gang O' Fries Entertainment | dez/2022 | 1.493 | 271,7 mi | 540,6 mil | 81,4% | 50 |
| **Islands** (1659645941) | Easy.gg | abr/2020 | 750 | 2,36 bi | 3,41 mi | 89,8% | 20 |
| **Dead Rails** (7018190066) | RCM Games | jan/2025 | 30.973 | 6,67 bi | 6,20 mi | 92,5% | 16 |
| **100 Days at Sea** (9167377564) | Stranded Devs | nov/2025 | 28.610 | 450,2 mi | 10,46 mi | **97,0%** | 27 |
| **a dusty trip** (5650396773) | Jandel's Road Trip | fev/2024 | 19.317 | 2,65 bi | 2,39 mi | 90,0% | 25 |
| *Survival Island [BETA]* (762240243) (homônimo!) | Cealion | ago/2018 | 2 | 9,3 mi | 79,3 mil | 77,0% | 14 |

**Picos históricos (fontes de terceiros, que divergem entre si):**
- **99 Nights:** a PC Gamer fala em pico de 14,2 mi de jogadores simultâneos ([PC Gamer](https://www.pcgamer.com/games/survival-crafting/with-a-peak-player-count-of-14-2-million-99-nights-in-the-forest-has-an-audience-other-multiplayer-games-would-kill-for-to-find-these-behemoth-playerbases-you-need-to-be-on-a-platform-like-roblox/)). O RoWatcher registra 11,2 mi em set/2025 ([RoWatcher](https://rowatcher.com/games/7326934954)).
- **The Survival Game:** 13,2 mil no RoTrends ([RoTrends](https://rotrends.com/game/3989768869)) e 3 mil (fev/2026) no RoWatcher.
- **Booga Booga:** 5 mil em jun/2025 ([RoWatcher](https://rowatcher.com/games/4154513353)).
- **Islands:** 1,8 mil em 22/11/2026 ([Profitable.app](https://profitable.app/roblox/games/islands)). Esse número parece ser um pico recente, não o histórico. O pico histórico não foi encontrado.
- **Outros:** não encontrado.

**Notas sobre os jogos:**
- **Booga Booga:** o jogo listado acima é a versão ativa da Gang O' Fries, conhecida como "Booga Booga Reborn". Ela se baseia no Booga Booga original do Soybeen, que foi aberto (uncopylocked), segundo a própria descrição. Não encontrei números confiáveis do Booga Booga "Classic" original.
- **Survive the Night:** o título solicitado está praticamente abandonado (universeId 411193926, com 26 jogadores na coleta). Por isso troquei por Dead Rails, 100 Days at Sea e a dusty trip, que são os sucessos atuais do gênero "sobreviva N dias/noites".
- **Homônimo:** já existe um jogo chamado **"Survival Island [BETA]"**, inativo, com 9,3 mi de visitas ([roblox.com](https://roblox.com/games/2184634969/Survival-Island-BETA)). O nome precisa de um diferencial.

### 1.2 Design (mecânicas, progressão, UI, construção)

| Jogo | Loop / retenção central | Progressão | Interface / inventário | Construção |
|---|---|---|---|---|
| 99 Nights | Proteger a fogueira, coletar de dia e sobreviver às noites (Deer, Owl, Cultistas). Resgatar as 4 crianças perdidas é a meta intermediária, com objetivo final no dia 99. Partidas cooperativas de até 25 jogadores. | Fogueira e bancada de crafting sobem de nível e liberam receitas e áreas novas. Fora da partida, **classes** são compradas com diamantes (10 a 600) ([GamesRadar](https://www.gamesradar.com/games/simulation/99-nights-in-the-forest-classes-all), [Sportskeeda](https://www.sportskeeda.com/roblox-news/all-classes-99-nights-forest-costs-perks-upgrades)). | Itens são carregados no saco/mãos e o mapa é craftável ([Destructoid](https://www.destructoid.com/99-nights-in-the-forest-walkthrough/), [rblxguide](https://rblxguide.com/games/99-nights-in-the-forest/updates/beginner-guide-survive-day-1-10)). | Acampamento simples (cama, prateleiras, armadilhas, plantação). Pass de decoração por 199 R$. |
| The Survival Game | Mundo medieval persistente com fome, abrigo, reinos (clãs) e raids PvP ([ProGameGuides](https://progameguides.com/roblox/roblox-the-survival-game-beginners-guide-the-survival-game-tips-and-tricks/), [Sportskeeda](https://www.sportskeeda.com/roblox-news/the-survival-game-a-definitive-guide)). | 4 skills (Mining, Woodcutting, Crafting, Food) com teto 25. **Rebirth** dá token para comprar passivas. | Menu de construção na tecla C e de reino na Q, com botões no mobile. Tem pass de "Infinite Bag". | Base completa com paredes, teto e armazenamento. Tem reinos e NPCs. |
| Booga Booga | Sandbox aberto: coletar, explorar cavernas, construir bases e atacar outras tribos (descrição oficial). | Mojo/níveis, itens de tier, baús e cosméticos com moedas ([Twinfinite](https://twinfinite.net/roblox/booga-booga-reborn-codes/)). | Hotbar e bolsa clássicas. Detalhes de UI não encontrados. | Bases livres que podem ser raidadas. Tem pass de clã. |
| Islands | Ilha própria persistente no estilo skyblock: fazenda, automação, comércio e expansão ([Islands Wiki](https://robloxislands.fandom.com/wiki/Skyblock_Roblox_Wiki)). | 12 ou mais skills com XP próprio (farming, pesca, mineração, combate, magia...). Boosts de 2h são vendidos à parte. | Inventário amplo, banco compartilhado e máquinas. | Construção por blocos muito livre, com automação de fábrica. |
| Dead Rails | Viagem de trem por 80 km. Combustível e recursos à noite contra hordas. Partidas curtas de até 16 jogadores. | Classes e maestria com Bonds (moeda premium). | Armazenamento limitado no trem, expandido com pass (+5 slots por 95 R$). | Fortificar o trem e as paradas. |
| 100 Days at Sea | Jangada no oceano, com 8 ilhas, 6 chefes e meta de 100 dias com ciclo dia/noite ([allthings.how](https://allthings.how/100-days-at-sea-on-roblox-codes-classes-islands-and-bosses/), [ProGameGuides](https://progameguides.com/roblox/complete-100-days-at-sea-beginners-guide/)). | Missões, crafting (serraria, armadilha de caranguejo), classes e "Level Skip". | Arpão para coletar. Detalhes de UI não encontrados. | Expansão da jangada com estruturas e defesas. |
| a dusty trip | Road trip num carro que você mantém funcionando. Saques e eventos no caminho. | Moeda Bottle Caps, roletas de armas e carros, recompensas diárias. | Mochilas de 8 ou 10 slots vendidas por Robux. | Personalização do carro. |

### 1.3 Monetização (API Roblox, 22/11/2026, preços em Robux)

**99 Nights in the Forest**
- **Game Passes:** Decorator Pass por 199. Os passes Diamond Hunter, Ranger Class e Medic Class estão fora de venda.
- **Developer Products:**
  - Diamantes: 20 = 99, 100 = 400, 250 = 900, 700 = 2.500. Existem versões "Gift" com os mesmos preços.
  - Revive: próprio por 55 (95 na segunda vez), de um amigo por 95, de todos por 230.
  - Outros: Starter Survival Kit por 299, Skip to Level 2/3 por 290/400, Reroll de classes de 99 a 400 (preço crescente), 3 Offerings por 99, armas de uma vida por 40 e 80.

**The Survival Game**
- **Game Passes:** Infinite Bag 1.989, x2 Resources 1.189, +10 NPCs 1.189, x2 Experience 989, Choose Spawn 889, x2 Tool Power 499, Dangerous Mounts 499, Paint Tool 399, x2 Hunger 299, Kingdom Customization 249, Player Cosmetics 189.
- **Developer Products:**
  - Moedas: 100 = 19, 500 = 95, 1.500 = 249, 4.500 = 749, 10.000 = 1.499, 20.000 = 2.499.
  - Rebirth Tokens: 1 = 250, 3 = 700, 10 = 2.000.
  - Outros: Starter Bundle 99, +1 Kingdom Server 250, votos em sugestões de 10 a 200, "Create Your Own Suggestion" 10.000.

**Booga Booga (Reborn)**
- **Game Passes:** Double Mojo 999, Double Hat 499, Wandering Trader Compass 399, Cosmetics Plus 249, Boulder 249, Clan Pass 199, Faster Chest Open 149.
- **Developer Products:**
  - Moedas: 200 = 16, 500 = 40, 1.000 = 80, 5.000 = 360, 10.000 = 640, 50.000 = 2.000, 100.000 = 3.200, 500.000 = 9.600.
  - Gemas: 1.000 = 100, 10.000 = 1.000.
  - Outros: Starter Pack 39, Wish 49 (10 por 449), Premium Crate 45 (10 por 450), Refresh Trader 29, evento Pirate Ship 149, versões Gift e Voucher de todos os passes.

**Islands**
- **Game Passes:** PRO 1.699, VIP 399, Banner Bench 499, Jukebox 499, Instruments 499, Obby Kit 399, Firework Barrel 199, Starter Pack 199, Floral Bench 149, Lighting Station 149, Shared Bank Account 119.
- **Developer Products:** boosts de +50% de XP por 2h a 99 por skill (49 em Cooking e Animal Husbandry), animais e skins de 399 a 499, Piggy Bank 399.

**Dead Rails**
- **Game Passes:** Tommy Gun 175, Mauser C96 148, Sawed-Off 148, +5 Storage 95.
- **Developer Products:**
  - Bonds: 5 = 65, 10 = 95, 20 = 129, 50 = 199, 100 = 379, 200 = 565.
  - MP: 5 = 75, até 100 = 899.
  - Revive: próprio por 45, do time por 200, de colega por 67.
  - Outros: Starter Pack 149, Mastery XP Boost (3 runs) 100, bundles de Natal por 275 e 499.

**100 Days at Sea**
- **Game Passes:** nenhum (zero). Monetiza só com Developer Products, num total de 51.
- **Developer Products:**
  - Pérolas: 25 = 99, 100 = 350, 250 = 800, 1.000 = 2.500.
  - Ofertas de entrada: Starter Deal 59, primeiro giro da roleta por 12 (giros normais por 25), Reroll de missões diárias por 19.
  - Revive: próprio por 80 (55 com desconto), Medkit para reviver amigo por 69, de todos por 200.
  - Pulo de nível: Level Skip 2/3/4 por 249/349/449.
  - Bundles e classes: 799 a 1.899, mais Companion LIMITED por 499.

**a dusty trip**
- **Game Passes:** cerca de 35 passes de armas e veículos de 99 a 699. Inclui 8 Slot Backpack por 499, 10 Slot Backpack por 679 e 180 (duas versões), sprint +20% por 99, extra health por 150 e big stomach por 149.
- **Developer Products:**
  - Bottle Caps: 150 = 37, 318 = 74, 513 = 113, 1.200 = 225, 2.500 = 450.
  - Outros: roletas a 37 (10 por 300), skips de 30 a 234, "Claim All Day Rewards" por 750, doações de 5 a 5.000.

**Estimativas de receita de terceiros** (modeladas, não oficiais; use com cautela):
- 99 Nights: cerca de US$ 1,27 mi por mês ([RoWatcher](https://rowatcher.com/games/7326934954)).
- Islands: cerca de US$ 18,8 mi acumulados ([Profitable.app](https://profitable.app/roblox/games/islands)).
- Demais jogos: não encontrado.

---

## 2. Padrões que funcionam

1. **Meta numérica clara no título** ("99 Nights", "100 Days", "80 km"). Os três maiores sucessos recentes do gênero (99 Nights, 100 Days at Sea e Dead Rails) usam um contador visível que dá ritmo e uma razão para "só mais uma noite".
2. **Âncora central para defender.** Fogueira (99 Nights), jangada (100 Days), trem (Dead Rails) e carro (dusty trip) dão foco espacial e tensão. O jogador entende o objetivo sem tutorial.
3. **Ciclo dia/noite com papéis distintos:** o dia é para coletar e explorar com risco baixo, a noite é para defender com risco alto. É o coração dos jogos de topo.
4. **Cooperativo, não PvP.** Os campeões atuais são PvE cooperativos, com aprovação de 90% a 97%. Os jogos com PvP e raid aberto (The Survival Game e Booga Booga) têm as menores aprovações (82,3% e 81,4%) e pouca gente jogando.
5. **Progressão dentro da partida** (nível da fogueira/bancada, que libera receitas e áreas) **mais progressão permanente fora dela** (classes, cosméticos). As duas mantêm o jogador voltando.
6. **Moeda premium com escada de preços padronizada**, por exemplo 99, 400, 900 e 2.500 (99 Nights) ou 99, 350, 800 e 2.500 (100 Days). As versões "Gift" dos pacotes estimulam o lado social.
7. **Revive pago e barato (45 a 95 R$)** é uma das monetizações mais aceitas porque acontece no momento de maior emoção, e o "reviver amigo/todos" é social.
8. **Starter pack barato e único (39 a 299 R$)** aparece em todos os jogos analisados como porta de entrada para o primeiro gasto.
9. **Missões, recompensas diárias e rerolls** (100 Days, dusty trip, 99 Nights) criam o hábito de voltar todo dia.
10. **Atualizações frequentes e eventos sazonais.** 99 Nights, Dead Rails, Booga e dusty trip foram atualizados nos 8 dias anteriores à coleta. Islands está sem atualização desde jan/2026 e tem 750 jogadores.
11. **Servidores pequenos (16 a 27 jogadores)** nos sucessos recentes, que favorecem grupos de amigos.

## 3. Reclamações comuns a evitar

O Reddit estava inacessível, então as fontes aqui são DevForum, wikis e o que as notas e a monetização indicam.

- **Tutorial obrigatório e longo:** é motivo direto de abandono na primeira sessão ([DevForum: Players Leaving During Tutorial](https://devforum.roblox.com/t/players-leaving-during-tutorial-feedback-needed/3147818), [DevForum: Players leaving after a single round](https://devforum.roblox.com/t/players-leaving-after-a-single-round/4664307)).
- **Inventário e UI confusos**, sem rótulo de tecla e sem botões para mobile ([DevForum: New Player Experience](https://devforum.roblox.com/t/feedback-on-improving-my-new-player-experience/4142662), [DevForum: Survival game feedback](https://devforum.roblox.com/t/feedback-on-survival-game/4201595)).
- **Loop mal explicado** depois do onboarding: "não sei por onde começar" (mesmos tópicos acima).
- **Carregamento lento** para novatos (exemplo citado: 90 s) e servidores difíceis de entrar. No Islands, a wiki registra jogadores que mal conseguem entrar ([Roblox Wiki: Islands](https://roblox.fandom.com/wiki/Easy.gg/Islands)).
- **Economia desequilibrada**, por exemplo trading que rende mais que a atividade principal (fazenda) no Islands (mesma fonte).
- **Grind excessivo e progresso "zerado"** em atualizações. O caso do Fisch é citado como causa de saída em massa ([allthings.how](https://allthings.how/?p=148282)).
- **Raid e PvP punitivos** que destroem bases. Não dá para impedir totalmente ser raidado no The Survival Game ([itemlevel.net](https://itemlevel.net/?p=103037)). Existe também bug de perda de progresso ao reconectar durante raid em outro jogo ([BetaHub](https://app.betahub.io/projects/pr-7182653216/issues/g-93781)).
- **Pay-to-win percebido** (análise minha, sem citação direta de jogadores). Passes como "Infinite Bag" (1.989), "x2 Resources" (1.189) e "Double Mojo" (999) em jogos com PvP dão vantagem competitiva comprada. As aprovações baixas desses jogos são coerentes com isso. A documentação do Roblox avisa que jogadores tendem a dar dislike quando reprovam a monetização ([Creator Docs](https://create.roblox.com/docs/production/monetization)).
- **Lag e bugs** são tema recorrente de guias até no 99 Nights ([bo3.gg](https://bo3.gg/games/articles/how-to-eliminate-lag-and-bugs-in-99-night-in-the-forest)).
- **Trolls em servidores públicos** (atrair lobos para o acampamento, desperdiçar recursos) aparecem até em guias de "como trollar" ([Gamezebo](https://www.gamezebo.com/walkthroughs/how-to-troll-in-99-nights-in-the-forest/)).
- **Reclamações específicas de jogadores do Reddit:** não encontrado.

## 4. Faixas de preço recomendadas (Robux)

Ferramentas do Roblox que valem para todos os preços abaixo:
- **Regional Pricing** de passes desde abr/2025 e de developer products depois disso. Você define um preço base e o Roblox ajusta por país ([DevForum](https://devforum.roblox.com/t/introducing-regional-pricing-for-passes/3621382), [Newsroom](https://about.roblox.com/newsroom/2025/04/roblox-launches-regional-pricing-for-in-experience-items)).
- **Managed Pricing** une regional pricing e price optimization. O Roblox relata aumento médio de 4% a 10% no gasto de Robux, sem garantia ([DevForum](https://devforum.roblox.com/t/managed-pricing-one-system-for-better-pricing-and-earnings-growth/4684738), [Docs](https://create.roblox.com/docs/en-us/production/monetization/managed-pricing)).
- **Price Optimization** com testes A/B exige pelo menos 60 mil transações por mês ([DevForum](https://devforum.roblox.com/t/introducing-price-optimization-find-the-best-prices-for-in-experience-items-and-passes/3186081)).
- O criador recebe 70% do valor dos passes ([Creator Docs](https://create.roblox.com/docs/production/monetization)).
- Benchmark de transação média por dia (GameAnalytics 2025): mediana entre US$ 0,89 e 1,29 em jogos com sessões de 13 min ou mais ([GameAnalytics](https://www.gameanalytics.com/cn/reports/2025-roblox-report)). Por isso a maior parte das vendas deve ficar na faixa de 49 a 299 R$.

| Item | Faixa recomendada | Referência observada | Observação |
|---|---|---|---|
| **VIP** (pass) | **299 a 499** (ideal 399) | Islands VIP 399, PRO 1.699 | Benefícios de conforto e status: tag no chat, cor de nome, +1 slot de spawn, área VIP social, +10% de moedas. Nada que dê vantagem em combate. |
| **Mochila expandida** (pass) | **+10 slots: 149 a 249**. Mochila grande: **399 a 599** | Dead Rails +5 por 95; dusty trip 8 slots 499, 10 slots 679; Survival Game Infinite 1.989 | Não venda inventário infinito. Ofereça uma expansão grátis que se conquista jogando, para o pass só adiantar. |
| **Cosméticos** | Item avulso **49 a 199**; pass de cosmético ou decoração **199 a 299**; limitado ou sazonal **399 a 499** | 99 Nights Decorator 199; Booga Cosmetics Plus 249; Survival Game Cosmetics 189; Islands skins 399 a 499 | É a monetização mais "limpa". Coloque cosmético na ilha/acampamento, porque ele aparece para os amigos. |
| **Pacotes de recursos** | **Starter pack único 49 a 149**; pacotes 25 a 150; bundle temático 299 a 799 | Booga Starter 39; 100 Days Starter 59; Survival Game Starter 99; Dead Rails 149; 99 Nights Kit 299 | Recursos comuns (madeira, pedra) não, ou só em quantidades que economizem minutos e não horas. Prefira kits de conveniência. |
| **Moedas premium** | Escada **99 / 349 a 400 / 799 a 900 / 1.999 a 2.500** com bônus crescente; degrau de entrada de **25 a 49** | 99 Nights 99/400/900/2.500; 100 Days 99/350/800/2.500; Booga 16 a 9.600 | Ofereça versões "Gift" de cada pacote. Mostre o "% extra" em cada degrau. |
| **Revive** (extra) | **49 a 99** (próprio), **150 a 230** (todos) | 45 a 95 e 200 a 230 | Sempre deixe uma alternativa grátis: um amigo pode reviver pegando um item. |

## 5. Retenção D1/D7 típica (referência para metas)

**GameAnalytics, Relatório Roblox 2025** ([fonte](https://www.gameanalytics.com/cn/reports/2025-roblox-report)), por duração média de sessão:

| Sessão média | D1 mediana / top 5% | D7 mediana / top 5% | D30 mediana / top 5% |
|---|---|---|---|
| 13 a 18 min | 10,2% / 15,9% | 1,2% / 3,1% | 0,34% / 1,25% |
| 19 a 24 min | 11,5% / 23,6% | 1,6% / 7,9% | 0,46% / 1,94% |
| 25 min ou mais | 10,8% / 24,8% | 1,8% / 6,4% | 0,50% / 1,92% |

- Sessões de 0 a 6 minutos ficam com D1 abaixo de 10% (mediana de 4% a 6%). Jogos de sobrevivência naturalmente têm sessões longas, o que é uma vantagem.
- **Metas sugeridas para Survival Island:** D1 de 12% a 15% e D7 de 2% a 4%, acima da mediana. Uma meta ambiciosa (top 5%) seria D1 acima de 20% e D7 acima de 6%.
- O Creator Dashboard compara D1 e D7 com benchmarks por faixa de jogo ([Creator Docs: Retention](https://create.roblox.com/docs/production/analytics/retention)).
- Benchmark oficial de D7 publicado pelo Roblox: não encontrado.

---

## 6. Recomendações de design para "Survival Island"

1. **Identidade e nome.** Já existe "Survival Island [BETA]" (2018, 9,3 mi de visitas). Use um subtítulo e um contador próprios, como **"Survival Island: 50 Noites de Náufrago"**, para herdar o gancho numérico de 99 Nights e 100 Days e evitar confusão na busca. A identidade visual tropical deve ser forte e diferente da floresta escura de 99 Nights: areia, coqueiros, recifes, tempestades e noites de lua com marés.
2. **Âncora central: o Farol/Sinal de Resgate.** Em vez da fogueira, o jogador reconstrói um farol (ou fogueira de sinalização na praia) que precisa ficar aceso à noite. Cada nível do farol ilumina um raio maior, libera receitas e revela no mapa a próxima região. O objetivo final é ser resgatado por um navio.
3. **Ciclo dia/noite com a maré como mecânica própria.** De dia a maré baixa abre recifes e cavernas para coleta. À noite a maré sobe, as criaturas saem do mar (caranguejos gigantes, espíritos da névoa) e o jogo vira defesa. Avise com antecedência: o céu muda e um sino toca no acampamento.
4. **Regiões desbloqueáveis como progressão clara.** Praia, Selva, Manguezal, Vulcão, Ilhota do Naufrágio e Ruínas, com cada região pedindo uma ferramenta ou ponte (machado de pedra, jangada, corda). Mostre um mapa com as regiões em "névoa" para criar curiosidade. Nada de bloquear região com Robux.
5. **Onboarding de 60 segundos e sem tutorial forçado.** O jogador acorda na praia com destroços, recebe 3 objetivos contextuais ("pegue 3 galhos", "faça a fogueira", "construa abrigo") e as dicas aparecem quando ficam relevantes. Os recursos nos primeiros 5 minutos são generosos, para o primeiro craft acontecer em menos de 2 minutos.
6. **Inventário simples, legível e pensado para mobile.** Hotbar de 6 a 8 slots mais uma mochila de 20 slots, com botões grandes, tecla visível no PC, auto-empilhamento e "craftável agora" destacado. Crafting por lista com filtro "posso fazer", sem receitas escondidas. Ofereça baús compartilhados no acampamento.
7. **Construção por encaixe (snap) em grade sobre palafitas e árvores.** Cabana, palafita, rede, paliçada de bambu e armadilhas. O foco é defesa contra a noite e conforto (cama salva o spawn e cozinha dá buffs), não raids. **PvE cooperativo**, servidores de 8 a 12 jogadores e servidores privados.
8. **Duas camadas de progressão.** Na partida: nível do farol, bancada e regiões. Na conta, permanente: diário do náufrago com coleções de conchas, peixes e criaturas, títulos, **classes/arquétipos** (Pescador, Mergulhador, Carpinteiro, Curandeiro) e decorações da ilha. Nunca apague progresso permanente em atualizações.
9. **Retenção diária e social.** Missões diárias de 3 tarefas com reroll grátis 1 vez ao dia, "garrafa com mensagem" diária na praia com recompensa, eventos semanais (tempestade, navio pirata fantasma) e reviver amigo com item craftável. Use badges por noite alcançada (10, 25, 50) e pelo resgate final.
10. **Monetização justa e sem pay-to-win.** O foco é conveniência, cosmético e social. Os preços seguem a seção 4.
    - **Game Passes:** VIP 399, Mochila do Explorador +10 slots por 199, Pacote de Decoração da Ilha por 249, Bote Rápido (transporte cosmético mais veloz) por 299.
    - **Developer Products:** moeda premium "Pérolas do Naufrágio" na escada 99/349/799/1.999 com versões Gift, Starter Pack único por 79, revive por 59 e de todos por 199, roleta cosmética por 25.
    - **Fora da loja:** nada de x2 recursos, inventário infinito ou armas exclusivas pagas.
11. **Lançamento técnico enxuto.**
    - **Carregamento:** menos de 15 s até o jogador poder agir, com streaming de mapa ativado e regiões carregadas sob demanda.
    - **Desempenho:** pouco efeito de partículas no mobile.
    - **Segurança:** servidor autoritativo para inventário e crafting, para evitar exploits.
    - **Dados:** DataStore com sessão bloqueada, para não perder progresso.
12. **Atualizações e medição desde o dia 1.**
    - **Analytics:** Funnel Events do Roblox para medir onde o jogador sai (primeiro craft, primeira noite, primeira região). Metas: D1 de 12% a 15%, D7 de 2% a 4% e sessão média de 19 minutos ou mais.
    - **Cadência:** atualização pequena a cada 1 a 2 semanas com nova criatura, receita ou evento.
    - **Preços:** ativar Managed Pricing assim que o jogo for elegível.

---

### Lacunas (não encontrado)
- Reclamações literais de jogadores no Reddit (domínio bloqueado para o agente).
- Pico histórico confiável de Islands, Dead Rails, 100 Days at Sea e a dusty trip.
- Dados do Booga Booga "Classic" original (Soybeen).
- Benchmark oficial do Roblox para D7.
- Receita real (todas as estimativas são modeladas por terceiros).
