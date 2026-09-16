# mesa_agent_mobile

Agente Telegram (mismo patrón que GSP `gsp_mobile_agent`) para compilar y subir **Mesa Flutter** desde el Mac.

Corre en el **Mac de desarrollo** (no en el droplet). No toca API, MySQL ni el front web.

| Comando | Acción |
|--------|--------|
| `/mobile` | ayuda |
| `/mobile status` | flutter, pubspec, versiones android/ios |
| `/mobile doctor` | flutter, java, adb, xcode, pods, secrets |
| `/mobile clean` | `flutter clean` + `pub get` |
| `/mobile build android` | AAB release → `artifacts/android/` |
| `/mobile build ios` | archive + export IPA → `artifacts/ios/` |
| `/mobile upload android` | Play Console API (track `internal` por defecto) |
| `/mobile upload ios` | App Store Connect (`altool`) |
| `/mobile full all` | clean → build android → upload android → build ios → upload ios |

Texto o comando desconocido → lista de comandos.

Los builds usan `--dart-define-from-file=config_production.json` (configurable en `config/agent.env`).

Los scripts usan `mesa_flutter` (`scripts/_common.sh`) con stdin desde `/dev/null` para evitar el crash de Flutter `errno 9` cuando el proceso padre no tiene TTY (Telegram subprocess, launchd, Cursor agent).

---

## Install (Mac)

Bot: @BotFather → `/newbot` (ej. `Mesa Mobile Deploy`). Token en `config.yaml`. User id: @userinfobot.

```bash
cd "/Users/carlossaldiviaabreu/Documents/GitHub/Sistema Administrativo Global/mesa_agent_mobile"
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

cp config.yaml.example config.yaml
cp config/agent.env.example config/agent.env
cp config/.env.example config/.env
cp config/exportOptions.plist.example config/exportOptions.plist
chmod 600 config.yaml config/agent.env config/.env
nano config.yaml          # token + allowed_users
nano config/agent.env     # MESA_MOBILE_REPO + FLUTTER
nano config/.env          # Apple + Play secrets
nano config/exportOptions.plist  # teamID

# Play upload: service account JSON de Play Console
cp /path/to/play-service-account.json config/play-service-account.json
chmod 600 config/play-service-account.json

chmod +x scripts/*.sh
./scripts/doctor.sh
```

### launchd (opcional, agente siempre encendido)

```bash
sudo mkdir -p /opt/mesa-mobile-agent
sudo rsync -a --exclude venv --exclude artifacts --exclude logs \
  "./" /opt/mesa-mobile-agent/
cd /opt/mesa-mobile-agent
python3 -m venv venv && ./venv/bin/pip install -r requirements.txt
# copiar config.yaml, agent.env, .env, exportOptions.plist, play-service-account.json

cp launchd/mesa-mobile-agent.plist.example ~/Library/LaunchAgents/mesa-mobile-agent.plist
# editar rutas si no usas /opt/mesa-mobile-agent
launchctl load ~/Library/LaunchAgents/mesa-mobile-agent.plist
```

Deberías recibir en Telegram: `mesa-mobile-agent online`.

### Tras cambiar código del agente

```bash
cd mesa_agent_mobile && git pull
chmod +x scripts/*.sh
launchctl kickstart -k gui/$(id -u)/mesa-mobile-agent
# o reinicia el proceso manual si corres agent.py en foreground
```

---

## Prerrequisitos en mesa_mobile

- `android/key.properties` + keystore (`keys/android/mesa-upload-keystore.jks`)
- `google-services.json` / `GoogleService-Info.plist` instalados (`python3 tool/configure_native.py`)
- Versiones nativas actualizadas manualmente en `build.gradle.kts` e `Info.plist` antes de subir
- Fila `app_version` en Plataforma alineada con `versionName` / `CFBundleShortVersionString`

Ver `mesa_mobile/COMMANDS.md` para builds manuales y Firebase SHA.

---

## Seguridad

- `config.yaml`, `agent.env`, `.env`, `play-service-account.json` y `exportOptions.plist` gitignored
- Un bot / un token
- `allowed_users` restringe quién dispara builds
