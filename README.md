# Gazu

Aplicación Flutter para autenticación, gestión de negocio y reputación.

## Requisitos

- Flutter SDK instalado y funcionando en tu entorno
- Proyecto Firebase configurado
- Node.js si también vas a trabajar con `functions/`

## Configuración inicial

1. Instala dependencias:

   ```bash
   flutter pub get
   ```

2. Genera la configuración de Firebase por plataforma:

   ```bash
   flutterfire configure
   ```

3. Verifica que existan estos archivos nativos:
   - `/tmp/workspace/HECTORGMHM/gazuproyecto/android/app/google-services.json`
   - `/tmp/workspace/HECTORGMHM/gazuproyecto/ios/Runner/GoogleService-Info.plist`

4. Valida el proyecto:

   ```bash
   flutter analyze
   flutter test
   ```

## Nota importante

El proyecto trae validación de arranque para avisar cuando Firebase no está configurado correctamente en la plataforma actual. Si ves una pantalla de error al iniciar, normalmente falta ejecutar `flutterfire configure` o agregar los archivos nativos de Firebase.
