# Relatório de auditoria: segurança, monetização, privacidade e desempenho

**Versão auditada:** commit `cc53da5`. **Data:** 2026-11-22. **Ambiente:** Roblox Studio 0.748 (Windows, i5 de 7ª geração, 8 GB), place **não publicado**.

> Os testes abaixo reduzem riscos, mas **não provam** que o jogo é seguro. Exploits de cliente (voo, noclip, auto-farm) nunca são eliminados por completo no Roblox. Os itens marcados como "não testado" exigem publicação ou vários jogadores reais.

## 1. Testes executados

| Suite | Como roda | Resultado |
|---|---|---|
| Unitários (lógica pura e configs) | `lune run tests/run`, 31 casos | ✅ 31/31 |
| Lint | `selene src`: 0 erros e 0 avisos | ✅ |
| Tipos | `luau-lsp analyze`: 3 bugs reais corrigidos; o restante é ruído do modo estrito | ✅ |
| Fumaça no Studio (servidor em modo Edit) | `run-in-roblox` + `tests/studio_smoke.luau` | ✅ Mundo em 18,7 s, 508 nós, 0 erros |
| Ponta a ponta em modo Play (jogador e cliente reais) | `tests/harness/*`, 44 verificações | ✅ 44/44, 0 erros no servidor |

## 2. Vulnerabilidades e bugs encontrados, por criticidade

| # | Criticidade | Problema | Status |
|---|---|---|---|
| V1 | 🔴 Crítica | Jogador que entrava durante a geração do mapa ficava **sem sessão de inventário** (perfil carregava antes do serviço escutar). Também afetava base, missões e passes | ✅ Corrigido (`PlayerService` processa quem já carregou; `onReady` atende tardios). Teste E2E cobre |
| V2 | 🔴 Crítica | Em place não publicado o DataStore **travava** o carregamento | ✅ Corrigido (modo memória com `PlaceId == 0` e timeout de 8 s) |
| V3 | 🟠 Alta | Exploit de velocidade de golpe: trocar de slot recriava a Tool e **zerava o cooldown** (~4x dano/coleta) | ✅ Corrigido (cooldown por jogador) |
| V4 | 🟠 Alta | Sem verificação de **teleporte/speed hack** | ✅ Corrigido (limite de 75 studs/s horizontal; reverte a posição). Teste E2E: teleporte de 300 studs revertido |
| V5 | 🟡 Média | Construção podia **prender outro jogador** | ✅ Corrigido (bloqueia construção sobre personagens) |
| V6 | 🟡 Média | Sombras da Maré nasciam **no spawn**, em cima de jogadores novos | ✅ Corrigido (fogueira permanente: zona segura de 90 studs) |
| V7 | 🟡 Média | Botões "Desequipar" cosmético nunca desequipavam (`x and false or y`) | ✅ Corrigido |
| V8 | 🟢 Baixa | HUD de vida atrás do menu/chat do Roblox | ✅ Corrigido (`ScreenInsets = CoreUISafeInsets`) |
| V9 | 🟢 Baixa | Tela de carregamento não cobria a tela inteira | ✅ Corrigido |
| V10 | 🟢 Baixa | BOM UTF-8 em 3 arquivos (risco de parse) | ✅ Corrigido |

## 3. Testes de segurança (17.1)

| Ameaça | Defesa | Teste |
|---|---|---|
| Dinheiro infinito | Conchas só mudam no servidor (missões, níveis, recibos); o cliente não tem ação que dê Conchas | ✅ E2E: Conchas não infladas |
| Duplicação de itens | Inventário só no servidor; `removeAll` atômico; trava de sessão no DataStore (impede carregar o mesmo perfil em 2 servidores); baú não desmonta com itens | ✅ Unitário + E2E |
| Manipulação de inventário | Índices validados (`Actions.int`), NaN e strings rejeitados | ✅ E2E: `Move(1e9,-5)`, `Craft(NaN)` sem efeito |
| Fome, sede e vida | Só o servidor calcula; nenhuma ação do cliente altera status; regeneração padrão do Roblox removida | ✅ Revisão de código |
| Compras falsas | Só `ProcessReceipt` concede; o cliente só pede para abrir o prompt oficial | ✅ E2E |
| Game Pass indevido | Posse via `UserOwnsGamePassAsync` | ✅ E2E: VIP não concedido |
| Abuso de remotes | Um único `RemoteEvent`, lista branca de ações, limite de taxa por ação, `pcall` | ✅ E2E: 150 chamadas em rajada + ação inexistente + `nil` |
| Funções administrativas | **Não existem** comandos de admin no jogo | ✅ |
| Permissões | Baús e portas só dono/amigos; demolir só o dono; território do Totem | ✅ Revisão (multiplayer real: ver 7) |
| Alvo de golpe | O servidor escolhe o alvo (raio à frente) e valida alcance e tier | ✅ |

## 4. Monetização (17.2)

| Caso | Resultado |
|---|---|
| Recibo válido entrega uma vez (+100 Conchas) | ✅ E2E (recibo simulado chamando a mesma função usada pelo Roblox) |
| Mesmo `PurchaseId` de novo **não** duplica | ✅ |
| Produto desconhecido → `NotProcessedYet` | ✅ |
| Jogador fora do servidor → `NotProcessedYet` (Roblox reenvia) | ✅ |
| Falha ao salvar após a compra → `NotProcessedYet` (sem dupla entrega graças à lista de recibos) | ✅ Revisão |
| Passes reconhecidos ao reconectar | ✅ Revisão (checados em todo login) |
| Compra de pass ou produto | ✅ 4 passes e 5 produtos criados com IDs reais; compra de teste no Studio feita pelo dono (v9) |

## 5. Salvamento

| Caso | Resultado |
|---|---|
| Base salva relativa ao Totem, com baú e conteúdo | ✅ E2E |
| Perfil pequeno (821 bytes; limite 4 MB) | ✅ |
| Dados corrompidos ou antigos (ids inválidos, pilhas acima do limite) | ✅ Unitário: `deserialize` sanitiza |
| Trava de sessão, retries, autosave e BindToClose | ✅ Revisão |
| Salvamento real no DataStore | ✅ Ativo no place publicado (sem modo memória nos logs da v7–v9) |

## 6. Privacidade e políticas (17.3)

Ver `docs/PRIVACIDADE.md`. Resumo:
- Só guarda o UserId e o progresso de jogo.
- Sem HTTP externo, sem analytics de terceiros e sem texto livre de jogadores.
- Sem loot box paga, sem pay-to-win e sem pedir dados pessoais.
- Procedimento de exclusão de dados documentado.
- Falta preencher o questionário de maturidade (ação do dono).

## 7. Multiplayer

| Caso | Resultado |
|---|---|
| Território bloqueia construção de terceiros, baú e porta de não-amigos | ✅ Revisão de código |
| Teste com 2 jogadores (Studio → Clientes e servidores) | ✅ Feito pelo dono: baú e território bloqueados para não-amigos, sem erros nos logs |

## 8. Desempenho

| Métrica | Valor |
|---|---|
| Geração do mundo | 9,8 a 18,7 s (o jogador vê a tela de carregamento) |
| Objetos | ~8,3 mil instâncias no workspace, ~7,1 mil BaseParts |
| Tick do servidor (Heartbeat) | 50,8 a 52,5/s com 1 jogador, no notebook do dono |
| Memória | 2,4 a 2,9 GB no **processo do Studio inteiro** (editor + servidor + cliente). Não é a memória do servidor publicado; medir no Developer Console após publicar |
| Celular | `StreamingEnabled` + modelos atômicos. ⏳ Testar no emulador de dispositivos do Studio |

## 9. Problemas que ainda existem

| Criticidade | Item |
|---|---|
| 🟡 Média | Exploits de movimento além de teleporte (voo, noclip) não são detectados |
| 🟡 Média | Bolsa de morte se perde se o dono sair do jogo (penalidade aceita, mas documentar) |
| 🟢 Baixa | Perder o pass de mochila com o inventário cheio pode descartar o excedente |
| 🟢 Baixa | Criaturas andam sem animação de pernas (visual) |

## 10. Condição para publicar (17.6)

**Status: pronto para uma versão de TESTE privada. Não está pronto para a versão pública definitiva.**

Antes do lançamento público, falta:
1. Publicar como **privado** e testar o DataStore real.
2. Testar com 2 ou mais jogadores.
3. Criar os produtos e testar as compras de teste do Studio.
4. Testar no emulador de celular.
5. Preencher o questionário de maturidade.

## Atualização: versão publicada v9 (2026-11-22)
- Experiência publicada (privada), DataStore real ativo e monetização com IDs reais.
- Guia Bento, Mapa da Ilha com rotas, sons licenciados e placas legíveis incluídos e testados em Play.
- Testes com 2 jogadores e no emulador de celular: ✅ aprovados pelo dono (sem erros nos logs; só um aviso de fila do DataStore, corrigido).
- Pendente antes do lançamento público: questionário de maturidade e thumbnails com capturas reais.
