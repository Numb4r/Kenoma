# Assinatura do APK de release

Toda build de release que vai para os amigos é assinada com uma chave própria do Kenoma. **A chave não está no
repositório e nunca deve entrar nele.**

## Onde fica

Na máquina de desenvolvimento, na pasta `~/.kenoma-signing/` (permissão `700`):

| Arquivo | O que é |
| --- | --- |
| `kenoma-release.jks` | o keystore: RSA 4096, alias `kenoma-release`, validade de 30 anos (até 2056) |
| `key.properties` | senha do keystore e da chave (a mesma), alias e caminho do keystore. Permissão `600` |

Impressão digital (SHA-256) do certificado, para conferir qualquer APK:

```
A5:EE:03:B0:ED:C7:4B:85:42:C2:8D:33:88:B5:53:88:2E:D4:D2:9C:AB:34:4C:B2:F3:39:6D:CF:8F:F6:C7:2E
```

## Como o build usa a chave

`app/android/app/build.gradle.kts` lê o `key.properties` de `KENOMA_KEY_PROPERTIES` (se a variável existir) ou de
`~/.kenoma-signing/key.properties`. Com o arquivo, `flutter build apk --release` assina com a chave de release.
**Sem o arquivo, o Gradle cai na chave de debug** para o build de desenvolvimento não quebrar: esse APK não serve
para distribuir, porque não instala por cima do outro (veja abaixo).

```
cd app && flutter build apk --release
# conferir a assinatura do APK gerado:
$ANDROID_HOME/build-tools/<versão>/apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

O digest que o `apksigner` mostra tem de ser o da tabela acima.

## Faça backup da chave agora

**Perder o keystore ou a senha é irreversível**: o Android só instala uma atualização se ela tiver a mesma
assinatura da versão instalada. Sem a chave, todo amigo teria de desinstalar o app (e perder o save) para receber
uma versão nova.

1. Copie a pasta inteira `~/.kenoma-signing/` (os dois arquivos) para **dois lugares fora desta máquina**: por
   exemplo um pendrive guardado em casa e um cofre de senhas ou um arquivo cifrado no Google Drive.
2. Cifre a cópia que for para a nuvem (`gpg -c` ou um `.zip` com senha forte). O keystore sozinho já pede senha, mas
   o `key.properties` a guarda em texto.
3. Depois de copiar, confira: `keytool -list -keystore kenoma-release.jks` na cópia tem de pedir a senha e listar
   `kenoma-release`.
4. Refaça a cópia se a chave for trocada. Anote a data do último backup aqui: _(preencher)_.

## Se a chave vazar

Quem tiver o keystore e a senha pode publicar um APK que o Android aceita como atualização do Kenoma. Se isso
acontecer: gere uma chave nova (comando abaixo), publique um APK novo e peça a todos que **desinstalem e
reinstalem** depois de exportar o backup (Ajustes > Exportar backup), porque a assinatura muda.

## Gerar uma chave nova

```
mkdir -p ~/.kenoma-signing && chmod 700 ~/.kenoma-signing
PW=$(openssl rand -base64 33 | tr -d '/+=\n' | head -c 28)
keytool -genkeypair -keystore ~/.kenoma-signing/kenoma-release.jks -storetype JKS -alias kenoma-release \
  -keyalg RSA -keysize 4096 -validity 10950 -storepass "$PW" -keypass "$PW" -dname "CN=Kenoma Veilbreakers, O=Kenoma"
umask 177
printf 'storePassword=%s\nkeyPassword=%s\nkeyAlias=kenoma-release\nstoreFile=%s\n' "$PW" "$PW" \
  ~/.kenoma-signing/kenoma-release.jks > ~/.kenoma-signing/key.properties
```

## Trocar de chave num aparelho que já tem o app

Um APK com assinatura diferente **não instala por cima**. Foi o caso na passagem da 0.11 (chave de debug) para a
0.12 (chave de release) no celular de teste: é preciso `adb uninstall com.numb4r.kenoma`, e isso apaga o save.
Antes, exporte o backup (a 0.12 tem a opção; a 0.11 não tinha).
