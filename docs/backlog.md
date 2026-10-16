# Kenoma · backlog

Pendências registradas fora dos prompts em andamento. Quando um item entrar num prompt, ele sai daqui.

## Visual e sensação

- Sprites com pouca densidade de pixel: avatar e Ecos ainda parecem toscos mesmo com a câmera a 50 m e pixel de 3 dp. Caminhos possíveis: arte final feita no pipeline local (stable-diffusion.cpp + Pixel Art XL, acabamento no Aseprite via pixel-mcp) ou 3D→2D com Blender; avaliar se o avatar precisa de 24 a 32 px de altura com câmera ainda mais perto. (16/out/2026)
- Tráfego fantasma ainda parece andar teleportando (carros e pedestres) depois da 0.13.1. Conferir se foi resolvido quando o agente terminar; se não, investigar taxa de atualização da posição, interpolação ao longo da rua e entrada/saída pelas bordas. (16/out/2026)

## Design de interface (Claude Design)

- Design System "Kenoma" criado (https://claude.ai/artifact/YNDxtTHyy6WUofSDC5A7Ub). Falta: Yuri revisar cores e fontes, definir as cores dos 12 tipos, desenhar o celular-menu e depois Coleção, Círculo, Bestiário, Bancada, Ajustes, HUD, Chat e Fórum; exportar para docs/ui/ e reconstruir em Flutter com tema único.

## Tráfego e mapa vivo

- Semáforos, ônibus e Ônibus Espectral, veículos especiais do tráfego (fase 2).

## Pendências do Yuri

- Backup cifrado da chave de release em dois lugares.
- Revisar docs/textos-mentor.md.
- Começar o teste de duas semanas com amigos.
