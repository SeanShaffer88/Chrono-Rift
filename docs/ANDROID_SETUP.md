# Local Android debug toolchain

Use standard Godot **4.7.2**, its matching export templates, OpenJDK **17**,
Android SDK Platform **36**, Platform-Tools and Build-Tools **36.0.0**.
Command-line tools 22.0 and Platform-Tools 37.0.1 were used locally.
The debug preset uses prebuilt APK templates, so Gradle/NDK/CMake are unnecessary
for this path. A release AAB requires a separate Gradle/signing setup.

Official downloads:

- [Godot editor and templates](https://github.com/godotengine/godot/releases/tag/4.7.2-stable)
- [OpenJDK 17](https://adoptium.net/temurin/releases/?version=17)
- [Android command-line tools](https://developer.android.com/studio#command-tools)
- [Godot Android export instructions](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html)

Verify vendor checksums before extracting. For a self-contained Windows editor,
place `_sc_` beside the executable. Initialize the editor once to create
`editor_data`; place template archive contents under
`editor_data/export_templates/4.7.2.stable/`, without the archive's `templates/` wrapper.

Extract Android tools under `<sdk>/cmdline-tools/latest/`, configure `JAVA_HOME`
for the shell, then accept the SDK licenses and install:

```powershell
sdkmanager --sdk_root=<sdk> --licenses
sdkmanager --sdk_root=<sdk> "platform-tools" "platforms;android-36" "build-tools;36.0.0"
```

The tested command-line package still supplies sdkmanager but warns that Android
CLI replaces it. Recheck vendor instructions when updating the pinned toolchain.

Build from the repository with PowerShell 7:

```powershell
./tools/Build-Android.ps1 -GodotPath <console-exe> -JavaSdkPath <jdk> -AndroidSdkPath <sdk> -OutputPath <debug-apk>
```

The default paths target the original workspace's sibling `work/` installations.
The script sets portable editor paths, imports, runs all tests, exports a signed
debug APK, verifies its signature and 16 KB ZIP alignment, and prints SHA256.
Tests/export have timeouts and saved logs. No SDK, release key or APK belongs in Git.

Local Android navigation was tested on an API 36 Google APIs x86_64 emulator
using WHPX and host graphics. SwiftShader exceeded a shader uniform limit.
The debug APK includes ARM64 and x86_64; test real phones before release.
