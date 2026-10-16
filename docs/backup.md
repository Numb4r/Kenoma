# Backup automático do Android

O app usa o Auto Backup do Android: o Google Drive da conta do aparelho guarda o save, sem login no app e sem servidor.
Só vale com o app reinstalado/restaurado na **mesma conta Google**, e o backup precisa estar ligado em Configurações do
Android > Sistema > Backup. O backup do app (Exportar/Importar nos Ajustes) continua existindo e é independente.

## O que entra

Só o save, em `<dataDir>/app_flutter/` (é onde `getApplicationDocumentsDirectory()` do `path_provider` aponta no Android;
não é `files/`, por isso `domain="root"` nos XMLs):

- `save.ksv` (a mais recente), `save.ksv.1`, `save.ksv.2` (as duas cópias rotativas).

Fora: `save.ksv.tmp`, `feed/` (cache do feed assinado), caches e o resto. Regras em
`app/android/app/src/main/res/xml/backup_rules.xml` (Android 11 e anterior) e `data_extraction_rules.xml` (Android 12+),
ligadas no `AndroidManifest.xml` (`allowBackup`, `fullBackupContent`, `dataExtractionRules`).

Limites do Android: o backup roda sozinho (aparelho ocioso, carregando, em Wi-Fi, no máximo uma vez por dia) e cada app
tem cota de 25 MB no Drive. O save tem poucos KB.

## Como testar com o celular (adb)

Com o celular conectado, com depuração USB e uma conta Google logada, e o backup do Android ligado:

```
adb shell bmgr enabled                          # Backup Manager is enabled
adb shell bmgr list transports                  # o transporte do Google (com.google.android.gms/...) tem * na frente
adb shell dumpsys backup | head -60             # estado geral e último backup de cada app

# 1. jogue um pouco (o save existe) e force um backup do app:
adb shell bmgr backupnow com.numb4r.kenoma      # esperado: "Backup finished with result: Success"
adb shell dumpsys backup | grep -A3 com.numb4r.kenoma

# 2. confira o que foi para o backup (não deve ter feed/, .tmp, caches):
adb shell bmgr list sets                        # os conjuntos de restauração (anote o token do mais novo)

# 3. apague o app e restaure:
adb uninstall com.numb4r.kenoma
adb install -r app-release.apk                  # a Play/Auto Restore só roda no 1º install; para forçar:
adb shell bmgr restore <token> com.numb4r.kenoma
```

Se `bmgr backupnow` responder `Package ... is not eligible`/`Transport error`, o backup do Android está desligado ou sem
conta. Em APK instalado por `adb install` o Android pode não restaurar sozinho; `bmgr restore` força.

Atenção: **desinstalar apaga o save local** (só o backup do Drive ou o arquivo exportado o trazem de volta). Antes de
testar num celular com save que importa, exporte o backup nos Ajustes.
