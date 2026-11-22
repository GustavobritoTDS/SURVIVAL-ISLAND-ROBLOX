# Privacidade e conformidade

> Documento técnico do que o jogo faz com dados. **Não é** parecer jurídico nem certificação. Revise com as políticas oficiais vigentes do Roblox antes de publicar.

## Dados processados

| Dado | Onde | Por quê | Retenção |
|---|---|---|---|
| `UserId` do Roblox | Chave do DataStore `p_<UserId>` | Salvar o progresso | Enquanto a experiência existir; pode ser apagado a pedido (ver abaixo) |
| `DisplayName` | Placas de nome, avisos de território e baú (só em memória) | Mostrar o dono das construções | Não é salvo |
| Progresso de jogo | DataStore (inventário, nível, base, missões, cosméticos, configurações) | Funcionamento do jogo | Igual ao UserId |
| `PurchaseId` das compras | Últimos 60 no perfil | Evitar entrega duplicada | Rotativo |
| Lista de amigos (`IsFriendsWith`) | Cache em memória | Permitir amigos em portas e baús | Só durante a sessão |

**Não coletamos:** nome real, idade, e-mail, telefone, CPF, endereço, localização, senhas, dados bancários, voz, imagem nem texto livre digitado pelos jogadores.

**Sem serviços externos:** o jogo não usa `HttpService` para enviar dados, nem analytics de terceiros ou bancos externos. Só usa serviços oficiais do Roblox: DataStoreService, MarketplaceService e Players.

**Sem texto gerado por jogadores:** nenhum campo do jogo aceita texto livre exibido a outros, então não há conteúdo de usuário a filtrar. Se isso mudar (nome de base, placas), será obrigatório usar `TextService:FilterStringAsync`.

## Pedidos de exclusão de dados (Right to Erasure)

O Roblox pode enviar pedidos de exclusão. O procedimento manual está em `docs/MANUTENCAO.md`: remover a chave `p_<UserId>` do DataStore `SurvivalIsland_PlayerData_v1` pelo Creator Dashboard (Data Stores Manager) ou pela Open Cloud.

## Checklist de políticas do Roblox

| Item | Situação |
|---|---|
| Compras só pelos fluxos oficiais (`PromptGamePassPurchase`/`PromptProductPurchase`) | ✅ |
| Itens pagos descrevem claramente o que entregam | ✅ (descrições na loja) |
| Sem itens aleatórios pagos (loot boxes) | ✅ (nenhuma caixa aleatória) |
| Sem pedir Robux/itens fora da plataforma, links externos ou contato fora do Roblox | ✅ |
| Sem pedir informações pessoais | ✅ |
| Conteúdo: violência leve de fantasia (criaturas, sem sangue) | Declarar no questionário de maturidade |
| Sem marcas, músicas ou personagens de terceiros | ✅ (tudo feito com Parts e sons nativos) |
| Sem pay-to-win em combate | ✅ (ver MONETIZACAO.md) |
| Sem chat próprio (usa o chat padrão filtrado do Roblox) | ✅ |
| Proteção de menores: nenhum recurso de contato privado, troca por dinheiro real ou coleta de dados | ✅ |

## Aviso para a página do jogo

> Survival Island salva apenas o seu progresso de jogo (inventário, nível e base) vinculado à sua conta Roblox. Não pedimos nem armazenamos informações pessoais. Compras são feitas apenas pelo sistema oficial do Roblox.
