# Monetização

Baseada na pesquisa de mercado (`docs/PESQUISA_DE_MERCADO.md`): os jogos do gênero mais bem avaliados são cooperativos e evitam pay-to-win. Passes como "Infinite Bag" ou "x2 Resources" geram reclamações frequentes. Regra deste projeto: **Robux compra conveniência leve e cosméticos, nunca poder de combate nem progressão bloqueada.**

## Game Passes

| Chave | Nome | Preço sugerido (R$) | Efeito | Justificativa |
|---|---|---|---|---|
| `vip` | VIP do Náufrago | 299 | Tag dourada, +10% XP, +25 Conchas/dia, rastro dourado | Faixa VIP de mercado: 299–499 |
| `big_backpack` | Mochila do Explorador | 149 | +12 espaços (24 → 36) | Mercado: +10 slots por 149–249; nunca infinita |
| `parrot` | Papagaio Companheiro | 99 | Papagaio cosmético | Cosméticos: 49–199 |
| `trails` | Rastros Lendários | 79 | 4 rastros exclusivos | Cosmético de entrada |

## Developer Products

| Chave | Nome | Preço (R$) | Entrega |
|---|---|---|---|
| `shells_small` | Saco de Conchas | 25 | 100 Conchas |
| `shells_medium` | Baú de Conchas | 99 | 450 Conchas (+12%) |
| `shells_large` | Tesouro de Conchas | 299 | 1500 Conchas (+25%) |
| `supply_crate` | Caixa de Suprimentos | 49 | 40 madeira, 40 pedra, 20 fibra, 5 carne assada, 5 cocos |
| `keep_items` | Amuleto da Maré | 35 | Não perde recursos na próxima morte |

Conchas compram apenas cosméticos e uma cesta de frutas. Também são ganhas jogando: missões, níveis, conquistas e login diário.

## Implementação

- Posse de pass: `MarketplaceService:UserOwnsGamePassAsync`, verificada ao entrar e após `PromptGamePassPurchaseFinished`.
- Produtos: `MarketplaceService.ProcessReceipt` com **idempotência** (os últimos 60 `PurchaseId` ficam no perfil), salvamento imediato e retorno `NotProcessedYet` se algo falhar, para o Roblox tentar de novo.
- O cliente nunca concede nada: só pede `Prompt`, e o servidor abre a janela de compra.

## Como ativar (manual, requer sua conta)

1. Publique o place (ver `PUBLICACAO.md`).
2. Creator Dashboard → sua experiência → **Monetization → Passes** → crie cada pass com nome, descrição, imagem e preço da tabela.
3. **Monetization → Developer Products** → crie cada produto.
4. Copie os **IDs reais** para `src/shared/Config/Monetization.luau` (campo `id`), rode `rojo build` e publique de novo.
5. Teste com compras de teste no Studio (o Studio não cobra Robux).

Considere ativar o **preço regional / Price Optimization** do Roblox depois de ter tráfego.
