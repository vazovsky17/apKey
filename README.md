# apKey

[![CI](https://github.com/vazovsky17/apKey/actions/workflows/ci.yml/badge.svg)](https://github.com/vazovsky17/apKey/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

English | [Русский](README.ru.md)

One command to generate an Android signing keystore. Run it in any folder, answer a few prompts, and get `signKeystore.zip` with the `.jks`, a ready-to-use `keystore.properties` and certificate fingerprints.

```console
$ apkey
Имя файла keystore [release.jks]: myapp
Alias ключа [upload]:
...
Готово: /path/to/signKeystore.zip
```

> The interactive prompts are in Russian.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/vazovsky17/apKey/main/install.sh | bash
```

The script is installed to `/usr/local/bin` if that is writable, otherwise to `~/.local/bin`. Set `PREFIX` to choose another directory:

```bash
curl -fsSL https://raw.githubusercontent.com/vazovsky17/apKey/main/install.sh | PREFIX="$HOME/bin" bash
```

From a clone: `./install.sh`. To uninstall, delete the `apkey` file from the install directory.

**Requirements:** macOS or Linux, `bash`, `zip`, and `keytool` from any JDK. If `keytool` is not on `PATH`, the script finds the JDK bundled with Android Studio.

## Usage

```bash
apkey [file.jks] [alias]
```

| Argument / option | Default | Description |
|---|---|---|
| `file.jks` | `release.jks` | Keystore file name; `.jks` is appended if missing |
| `alias` | `upload` | Key alias |
| `-h`, `--help` | | Show help |
| `-V`, `--version` | | Show version |

Prompts: file name, alias, owner name (CN), organization (O), country code (C), and password twice. Press Enter to accept the default in brackets. The password must be at least 6 characters, and both entries must match.

## Output

```
signKeystore.zip
└── signKeystore/
    ├── release.jks           # JKS, RSA 2048, valid for 10000 days
    ├── keystore.properties   # storeFile, storePassword, keyAlias, keyPassword
    └── fingerprints.txt      # SHA-1 / SHA-256 for Firebase, Google APIs
```

- The store password and the key password are the same.
- Nothing except the archive is written to the current folder. If `signKeystore.zip` already exists, the script exits without changing it.
- The password reaches `keytool` through an environment variable, so it does not appear in `ps`.

## Gradle

Unzip the archive into the project root, then in `app/build.gradle.kts`:

```kotlin
import java.util.Properties

val keystoreDir = rootProject.file("signKeystore")
val keystoreProps = Properties().apply {
    keystoreDir.resolve("keystore.properties").inputStream().use(::load)
}

android {
    signingConfigs {
        create("release") {
            storeFile = keystoreDir.resolve(keystoreProps.getProperty("storeFile"))
            storePassword = keystoreProps.getProperty("storePassword")
            keyAlias = keystoreProps.getProperty("keyAlias")
            keyPassword = keystoreProps.getProperty("keyPassword")
        }
    }
    buildTypes {
        getByName("release") { signingConfig = signingConfigs.getByName("release") }
    }
}
```

Add `signKeystore/` to your project's `.gitignore`.

## Security

- `keystore.properties` stores the password in **plain text**, and the archive has no password. Anyone with the archive can sign builds as you. Do not commit it, and store it somewhere safe, such as a password manager.
- Keep a backup. If you lose an app signing key, you cannot publish updates. With Play App Signing this keystore is your *upload key*, and Google Play support can reset it.

## License

[MIT](LICENSE)
