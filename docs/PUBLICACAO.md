# Publicação

## 1. Gerar e abrir o place

```powershell
rokit install
rojo build -o build/SurvivalIsland.rbxlx
start build/SurvivalIsland.rbxlx
```

## 2. Testar no Studio

1. **Home → Game Settings → Security → Enable Studio Access to API Services** (para testar salvamento). Sem isso o jogo roda em "modo memória" e avisa na Output.
2. **Test → Play (F5)**: verifique o carregamento, a coleta, o crafting, a construção, a noite e a morte.
3. **Test → Clients and Servers → 2 Players** para testar o multiplayer (baús, portas, territórios).
4. **Test → Device** (emulador) → iPhone/iPad para conferir a UI no celular.

## 3. Publicar

1. **File → Publish to Roblox As…** → *Create new experience* → nome **Survival Island: A Maré Sombria** (já existe um "Survival Island [BETA]" antigo; o subtítulo diferencia).
2. Gênero: *Survival*. Dispositivos: Computer, Phone, Tablet, Console.
3. Creator Dashboard → **Configure → Basic Info**: descrição (`docs/MARKETING.md`), ícone e thumbnails (`marketing/`).
4. **Questionnaire de maturidade** (obrigatório): violência leve de fantasia (criaturas, sem sangue).
5. **Access → Public** quando estiver pronto.

## 4. Pós-publicação

- Crie os Game Passes e Produtos (`docs/MONETIZACAO.md`), atualize os IDs e republique.
- Ative *Analytics → Funnel Events* para medir onde o jogador sai do tutorial.
- Mantenha o `CHANGELOG.md` a cada atualização (ciclo sugerido: 1–2 semanas).

## Experiência publicada
- Place ID: `114489520493330` · Universe ID: `10778546362`
- Atualizar: abrir no Studio (Creator Dashboard → Editar no Studio), Plugins → Rojo → Connect (`rojo serve`), Arquivo → Publicar no Roblox.
