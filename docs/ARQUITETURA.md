# Arquitetura

## Princípio: servidor autoritativo

O cliente **só pede**; o servidor **decide**. Toda ação do jogador passa por um único `RemoteEvent` (`Remotes.Action`) e pelo roteador `server/Util/Actions.luau`, que:

- aceita apenas ações registradas (nome string);
- aplica limite de taxa por jogador e por ação (token bucket);
- valida tipos e faixas (`Actions.int`, `Actions.str`) e rejeita NaN;
- isola erros com `pcall` (um handler quebrado não derruba o servidor).

Golpes não usam remote: o servidor escuta `Tool.Activated` e **escolhe o alvo sozinho** (raio à frente do personagem, `GetPartBoundsInRadius`), com cooldown por arma. Um exploit não consegue acertar algo distante nem escolher o que acerta.

| Remote | Direção | Uso |
|---|---|---|
| `Action` | cliente → servidor | `Move`, `Drop`, `Use`, `Select`, `Craft`, `Place`, `Demolish`, `ChestMove`, `ClaimQuest`, `Prompt`, `ShellBuy`, `EquipCosmetic`, `Settings`, `Tutorial`, `RequestSync` |
| `State` | servidor → cliente | estado parcial (inventário, stats, progresso, missões, baú…) |
| `Notify` | servidor → cliente | notificações (toasts) |
| `Fx` | servidor → cliente | efeitos visuais e sonoros |

## Serviços do servidor (`src/server/Services`)

| Serviço | Responsabilidade |
|---|---|
| `DataService` | DataStore com **trava de sessão** (UpdateAsync + JobId), retries exponenciais, autosave a cada 120 s, `BindToClose`, modo memória no Studio sem API |
| `WorldService` | Geração procedural do terreno (WriteVoxels em chunks), decoração, lagos, pontos de nós |
| `PlayerService` | Inventário autoritativo, XP/níveis, Conchas, contadores, notificações, sincronização |
| `EquipService` | Barra rápida → Tool na mão, consumíveis, armadura |
| `ResourceService` | Nós de recurso: spawn, HP, drops, respawn |
| `CreatureService` | IA (vagar/fugir/perseguir/atacar), população por região, dano com armadura |
| `BuildService` | Validação de construção (distância, água, sobreposição, apoio, território, limites), portas, baús, camas, coletor de chuva, Farol; **salva a base relativa ao Totem** |
| `CraftingService` | Valida nível, estação a até 16 studs, materiais e espaço |
| `EnvironmentService` | Relógio dia/noite, clima, iluminação |
| `SurvivalService` | Tick de fome/sede/calor/vida, lagos, morte com bolsa, renascimento, bloqueio de regiões por nível |
| `QuestService` | Missões diárias determinísticas, conquistas, login diário |
| `MonetizationService` | Passes (`UserOwnsGamePassAsync`), `ProcessReceipt` idempotente, loja de Conchas, cosméticos |

`Util/Env.luau` guarda o estado ambiental (noite, chuva, fontes de calor) compartilhado sem dependências circulares.

## Lógica pura (`src/shared/Logic`)

`Inventory.luau`, `Rules.luau` e `BuildGrid.luau` não usam APIs do Roblox e são cobertas pelos testes em `tests/run.luau` (executados com Lune).

## Bases em servidores diferentes

A ilha é compartilhada e cada servidor tem jogadores diferentes. A base é salva **relativa ao Totem**. Ao entrar, se o terreno original estiver ocupado por outra base, o Totem é reposicionado no lugar livre mais próximo (espiral) e a base inteira acompanha. Construções fora do raio do Totem são temporárias, e o jogo avisa isso ao construir.

## Desempenho

- IA só roda perto de jogadores (220 studs); criaturas longe por 60 s são recicladas.
- `StreamingEnabled` com modelos `Atomic` (bom para celular).
- Todos os modelos são Parts nativas (sem download de meshes); decoração ancorada e sem sombra em peças pequenas.
- Ticks: sobrevivência 1 s, IA 0,25 s, população 6 s.
