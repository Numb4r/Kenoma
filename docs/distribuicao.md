# Distribuição: a época de desenvolvimento vira a primeira publicada

Até a distribuição o jogo fica em **modo de desenvolvimento** (GDD, Épocas; `CLAUDE.md`, regra 5; desde a 0.25.2): uma época
só, a 12, embarcada no APK e ativa desde 2026-09-22, com `"dev": true` em `app/assets/data/epochs.json`. Mudança de mundo
entra nela direto. O app nunca mostra mundo desatualizado e não funde épocas do feed. Campinas e São Paulo vêm no APK.

Este é o passo a passo do dia em que o dono disser que vai distribuir. Nada aqui é feito sem esse pedido. Publicar
(`docs/pages`, GitHub Pages) continua precisando de autorização explícita, a cada vez.

## 1. Backup das chaves (antes de tudo)

A chave de release (`~/.kenoma-signing/kenoma-release.jks`) é o que deixa os amigos instalarem as versões seguintes por
cima, sem perder o save. A de publicação (`~/.kenoma-signing/publicacao_ed25519.pem`) assina o feed. Sem backup, perder o
notebook é perder as duas.

1. `./scripts/backup_signing_key.sh /pasta/de/destino` (gera `kenoma-signing-AAAAMMDD.tar.gz.gpg`, cifrado; a senha vai
   para um cofre de senhas, separada do arquivo).
2. `./scripts/backup_signing_key.sh --verify kenoma-signing-AAAAMMDD.tar.gz.gpg`.
3. Guarde uma cópia fora do notebook e anote a data em `docs/assinatura.md` ("Faça backup da chave agora").

## 2. Congelar a época 12 como a primeira publicada

1. Em `app/assets/data/epochs.json`: tire `"dev": true` e o comentário `"_"`. O `id` continua 12 (ele entra no hash do
   mundo e nos `since_epoch`; o mundo dos amigos é o mesmo que o dono já joga).
2. O início fica no passado (`2026-09-22T00:00:00Z`): é a primeira publicada e ninguém tem outra, então não há mundo a
   preservar antes dela. O `valid_until_utc` passa a ser o dia da distribuição + 90 dias.
3. Confira que tudo o que a época lista está no APK ou no catálogo assinado: `flutter test test/data/embedded_region_test.dart`.

## 3. Voltar com as regras do regime publicado

1. **Trava de release:** restaure `app/test/release_guard_test.dart` do git (`git log --diff-filter=D -- app/test/release_guard_test.dart`
   mostra o commit da 0.25.2 que o tirou; `git show <commit>^:app/test/release_guard_test.dart`) e troque as referências
   à época 12 de teste pela próxima época, quando ela existir.
2. **`CLAUDE.md`, regra 5:** volta o texto do regime publicado (o da 0.25.1 no git): nunca alterar época publicada, época
   nova com início em 2099 até publicar (`scripts/set_epoch_start.py`, 7 dias ou mais de antecedência), `since_epoch` em
   espécie, item ou bioma novo, e a linha da pipeline "nunca regere por cima um `.bin` commitado".
3. **Aviso de mundo desatualizado:** volta sozinho quando o `"dev"` sai (`EpochSchedule.isStale`).
4. **Feed:** sem o `"dev"`, `loadEpochsJson` volta a fundir o `epochs.json` assinado.

## 4. Feed e regiões

1. `docs/pages/epochs.json` ainda tem as épocas 0 a 7 da fase de testes. Ele é substituído pelo `epochs.json` do app
   (só a 12): `./scripts/assinar_publicacao.sh` (copia, assina e confere; não publica).
2. Um aparelho que guardou o feed antigo não volta para as épocas 0 a 7: o app recusa época do feed com id menor que a
   maior embutida.
3. **São Paulo:** embutida desde a 0.25.2 (+70 MB no APK, 53,5 MB só dos prédios). Para tirar do APK, publique os arquivos
   da época 12 de SP no catálogo (`scripts/assinar_regioes.py`, `docs/pages/regions.json`, `route_files` para a rota, os
   pontos e os prédios), apague-os de `app/assets/regions/` e confira que a região baixa e abre.
4. Publicar: commit de `docs/pages/` e push, só com a autorização do dono.

## 5. A versão que vai para os amigos

1. Versão nova, `flutter analyze` limpo, `flutter test` passando, release assinada com a chave de release
   (`apksigner verify --print-certs`, digest de `docs/assinatura.md`).
2. Save com migração testada a partir do save do aparelho do dono.
3. Daqui em diante, mudança de mundo vai para uma época nova (13), com início em 2099 até publicar.
4. **O menu de debug sai da build dos amigos.** Ele é só do dono (0.26.6): até aqui fica em toda build, inclusive na
   release, e com ele saem o canal `kenoma/debug_cmd` (o `celular.sh cmd`) e o `DevTools` forçado. A build que vai para os
   amigos abre direto no mapa, sem a rota do menu (`main.dart` monta `[TuningDebugMenu, GameMapScreen]` hoje), e o botão
   "Menu de debug" do selo de modo some. Na build do dono o menu continua, com a mesma chave.

## 6. O que o jogo guarda no aparelho

Para contar a quem recebe o APK: além do jogo (nível, criaturas, bolsa, Bestiário), o save guarda só neste aparelho a
**última posição do mapa**, arredondada para a célula do mapa (z21, uns 17 m de lado), para a próxima abertura já preparar
aquela área (0.26.4, chave `map_last_cell`). Ela nunca sai do celular: o backup e a exportação do save tiram a chave, o QR
do grupo só leva o código do grupo, e nada a envia pela rede. Recomeçar do zero também a apaga.
