# Kenoma · backlog

Pendências registradas fora dos prompts em andamento. Quando um item entrar num prompt, ele sai daqui.

## Visual e sensação

- Sprites com pouca densidade de pixel: avatar e Ecos ainda parecem toscos mesmo com a câmera a 50 m e pixel de 3 dp. Caminhos possíveis: arte final feita no pipeline local (stable-diffusion.cpp + Pixel Art XL, acabamento no Aseprite via pixel-mcp) ou 3D→2D com Blender; avaliar se o avatar precisa de 24 a 32 px de altura com câmera ainda mais perto. (16/out/2026)
- Tráfego fantasma ainda parece andar teleportando (carros e pedestres) depois da 0.13.1. Conferir se foi resolvido quando o agente terminar; se não, investigar taxa de atualização da posição, interpolação ao longo da rua e entrada/saída pelas bordas. (16/out/2026)

## Design de interface (Claude Design)

- Design System "Kenoma" criado (https://claude.ai/artifact/YNDxtTHyy6WUofSDC5A7Ub). Falta: Yuri revisar cores e fontes, definir as cores dos 12 tipos, desenhar o celular-menu e depois Coleção, Círculo, Bestiário, Bancada, Ajustes, HUD, Chat e Fórum; exportar para docs/ui/ e reconstruir em Flutter com tema único.

## Tráfego e mapa vivo

- Semáforos, ônibus e Ônibus Espectral, veículos especiais do tráfego (fase 2).
- Bairros do rumor da Entidade solta: hoje são escritos à mão em `app/assets/data/mapa.json` (`bairros`, 19 em Campinas e 18 em São Paulo, centros aproximados). Da próxima vez que a pipeline do OSM for mexida, eles devem sair dela (`place=suburb` e `place=neighbourhood`, com o centro de cada um) para o pacote da região. (28/nov/2026)

## Casa (fase 2)

- Seiva na Horta: o GDD dá à horta "ervas, seiva e madeira", mas não existe item de seiva (nem de madeira, fora o Galho de gelo). Na 0.28.0 a Horta faz só Ervas; seiva pede item novo, a decidir com o dono. (28/nov/2026)
- A Coleção não tem limite: o santuário do Armazém conta só as criaturas deixadas em casa (guardadas e trabalhando). Se a Coleção inteira tiver de caber no santuário, como diz "Base, Bolsa e Armazém", é uma mudança maior (captura e fusão com o santuário cheio). (28/nov/2026)

## Pendências do Yuri

- Backup cifrado da chave de release em dois lugares.
- Revisar docs/textos-mentor.md.
- Começar o teste de duas semanas com amigos.
