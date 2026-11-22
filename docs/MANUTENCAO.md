# Manutenção

## Fluxo de trabalho

```powershell
rokit install
rojo serve                      # no Studio: plugin Rojo → Connect (edição ao vivo)
lune run tests/run              # testes de lógica e configs
selene src                      # lint
powershell -ExecutionPolicy Bypass -File tests/run_play_test.ps1   # teste E2E em modo Play (abre o Studio)
```

Para atualizar: edite em `src/`, rode os testes, `rojo build -o build/SurvivalIsland.rbxlx`, abra no Studio e use **File → Publish to Roblox**. Depois registre a mudança no `CHANGELOG.md`.

## Adicionar ou alterar itens, receitas e regiões

Tudo é por configuração em `src/shared/Config/`:

- **Novo item:** adicione em `Items.luau`.
- **Receita:** em `Recipes.luau`.
- **Nó de recurso:** em `Nodes.luau` (o modelo vai em `src/server/World/NodeModels.luau`).
- **Criatura:** em `Creatures.luau` (o modelo vai em `src/server/Builders/CreatureModels.luau`).

Os testes (`tests/run.luau`) falham se um item não puder ser obtido, se faltar uma receita para uma construção ou se algum ID estiver errado.

## Monetização: adicionar produtos, mudar preços, atualizar IDs

Arquivo: `src/shared/Config/Monetization.luau`.

1. **Criar na plataforma (manual):** Creator Dashboard → experiência → *Monetization*.
   - *Passes* → Create a Pass: nome, descrição, imagem 512×512. Depois *Sales* → ative a venda e defina o preço.
   - *Developer Products* → Create: nome, descrição, ícone e preço.
2. **Copiar o ID real** exibido pela plataforma para o campo `id` da entrada correspondente. Nunca invente IDs: com `id = 0` o item aparece como "Em breve" e nada é vendido.
3. **Novo Game Pass:** adicione uma entrada em `gamePasses` e implemente o benefício em `MonetizationService.checkPasses` (posse sempre verificada com `UserOwnsGamePassAsync`, nunca confiando no cliente).
4. **Novo Developer Product:** adicione em `devProducts` com `shells` e/ou `items`. Para efeitos especiais, trate a chave em `grantProduct`.
5. **Mudar preço:** o preço real é o definido no Dashboard. O campo `price` no arquivo só aparece na loja do jogo, então mantenha os dois iguais.
6. Rode `lune run tests/run` (o teste confere preços e itens), faça o build e publique.

Exemplo de entrada:

```lua
double_xp = { id = 0, name = "XP em Dobro (30 min)", price = 49, icon = "⚡", description = "..." },
```

## Dados de jogadores

- **DataStore:** `SurvivalIsland_PlayerData_v1`, chave `p_<UserId>`, formato `{ data = perfil, lock = { job, t } }`.
- **Migração:** campos novos são preenchidos por `reconcile()` em `DataService`. Para mudanças incompatíveis, aumente `DATA_VERSION` em `Game.luau` e trate o caso em `reconcile`.
- **Exclusão a pedido (Right to Erasure):** Creator Dashboard → *Data Stores Manager* → `SurvivalIsland_PlayerData_v1` → apague a chave `p_<UserId>`.
- **Trava travada:** se um servidor cair, a trava expira em 10 min (`LOCK_EXPIRE`).

## Desempenho

- Orçamento atual do mapa: cerca de 7 mil BaseParts (508 nós e decoração).
- Para reduzir: diminua o `count` dos nós em `Nodes.luau` ou a decoração em `World/Decor.luau`.
