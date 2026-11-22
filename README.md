# 🏝️ Survival Island — A Maré Sombria

Jogo de sobrevivência cooperativo para **Roblox**: você naufraga numa ilha tropical, coleta recursos, fabrica ferramentas, constrói sua base e sobrevive às noites, quando as **Sombras da Maré** saem do mar. O objetivo final é acender o **Farol de Resgate**.

> 🎮 **Jogar:** https://www.roblox.com/games/114489520493330 (Place ID `114489520493330`, Universe ID `10778546362`; ainda privado)
>
> Código 100% em Luau, versionado com Git e sincronizado com o Roblox Studio via [Rojo](https://rojo.space).

## ✨ Funcionalidades

| Sistema | O que existe |
|---|---|
| Mundo | Ilha gerada proceduralmente (seed fixa): praia, selva, planalto, caverna de cristal e vulcão; lagos de água doce, destroços do naufrágio, placas de região |
| Ambiente | Ciclo dia/noite (10 min), chuva e tempestades com relâmpagos, iluminação com Atmosphere/Bloom/SunRays |
| Sobrevivência | Vida, fome, sede e calor; dano por fome/frio; regeneração; renascimento na cama ou na praia |
| Coleta | 10 tipos de nó (galhos, pedras, arbustos, bananeiras, palmeiras, árvores, rochas, ferro, cristal, obsidiana) com tiers de ferramenta |
| Inventário | 24 espaços (+12 com pass), barra rápida 1–6, armadura, baús compartilhados com amigos |
| Crafting | 33 receitas em 6 abas; estações: mãos, bancada, fogueira, fornalha |
| Construção | 15 construções, prévia com encaixe na grade, rotação, desmontar, Totem de território que protege e salva a base |
| Criaturas | Caranguejo, javali, lobo, aranha de cristal, Sombra da Maré (noturna, teme fogo) e Golem de Magma; dificuldade cresce a cada noite |
| Progressão | 30 níveis, 9 regiões/receitas desbloqueáveis, 3 missões diárias, 9 conquistas, bônus de login de 7 dias, Farol de Resgate (fim de jogo) |
| Multiplayer | Cooperativo (sem PvP), bases protegidas, portas e baús só para dono e amigos |
| Salvamento | DataStore com trava de sessão, autosave, retries e BindToClose |
| Monetização | 4 Game Passes e 5 Developer Products (sem pay-to-win), loja de Conchas (moeda do jogo), ProcessReceipt idempotente |
| UI | Tela de carregamento + menu, HUD, notificações, tutorial contextual pulável; PC, celular, tablet e controle |

## 🗂️ Estrutura

```
src/
  first/     ReplicatedFirst — tela de carregamento e menu principal
  shared/    ReplicatedStorage.Shared — configs (itens, receitas, regiões…), lógica pura e Net
  server/    ServerScriptService.Server — serviços autoritativos (dados, mundo, criaturas, construção…)
  client/    StarterPlayerScripts.Client — UI e controles
tests/       testes automatizados (Lune) da lógica pura e da consistência das configs
docs/        pesquisa de mercado, arquitetura, monetização, publicação, testes
```

## 🚀 Como rodar

Pré-requisitos: Windows/macOS, [Rokit](https://github.com/rojo-rbx/rokit) e Roblox Studio.

```powershell
rokit install                         # instala rojo, selene, stylua, lune, luau-lsp nas versões do rokit.toml
rojo build -o build/SurvivalIsland.rbxlx
start build/SurvivalIsland.rbxlx      # abre no Roblox Studio → Play (F5)
```

Desenvolvimento ao vivo: `rojo serve` + plugin do Rojo no Studio → *Connect*.

## ✅ Qualidade

```powershell
lune run tests/run      # testes automatizados
selene src              # lint
stylua src              # formatação
```

## 📦 Publicação e monetização

Veja [docs/PUBLICACAO.md](docs/PUBLICACAO.md) e [docs/MONETIZACAO.md](docs/MONETIZACAO.md). Os IDs de Game Passes/Produtos ficam em `src/shared/Config/Monetization.luau` (valor `0` = "Em breve", nenhuma compra é feita).

## 📄 Licença

Código sob licença MIT. Nenhum asset de terceiros: todos os modelos são feitos com Parts e materiais nativos do Roblox.
