# apKey

[English](README.md) | Русский

Одна команда для создания ключа подписи Android-приложения. Запустите её в любой папке, ответьте на несколько вопросов и получите `signKeystore.zip`: в нём `.jks`, готовый `keystore.properties` и отпечатки сертификата.

## Установка

```bash
curl -fsSL https://raw.githubusercontent.com/vazovsky17/apKey/main/install.sh | bash
```

Скрипт устанавливается в `/usr/local/bin`, если туда есть права на запись, иначе в `~/.local/bin`. Другую папку можно задать через `PREFIX`:

```bash
curl -fsSL https://raw.githubusercontent.com/vazovsky17/apKey/main/install.sh | PREFIX="$HOME/bin" bash
```

Из клона репозитория: `./install.sh`. Чтобы удалить, удалите файл `apkey` из папки установки.

**Требования:** macOS или Linux, `bash`, `zip` и `keytool` из любого JDK. Если `keytool` нет в `PATH`, скрипт найдёт JDK, который идёт с Android Studio.

## Использование

```bash
apkey [file.jks] [alias]
```

| Аргумент / флаг | По умолчанию | Описание |
|---|---|---|
| `file.jks` | `release.jks` | Имя keystore; `.jks` добавляется, если его нет |
| `alias` | `upload` | Alias ключа |
| `-h`, `--help` | | Справка |
| `-V`, `--version` | | Версия |

Скрипт спрашивает имя файла, alias, имя владельца (CN), организацию (O), код страны (C) и пароль дважды. Enter оставляет значение в квадратных скобках. Пароль должен быть не короче 6 символов, оба ввода должны совпасть.

## Результат

```
signKeystore.zip
└── signKeystore/
    ├── release.jks           # JKS, RSA 2048, срок 10000 дней
    ├── keystore.properties   # storeFile, storePassword, keyAlias, keyPassword
    └── fingerprints.txt      # SHA-1 / SHA-256 для Firebase и Google API
```

- Пароль хранилища и пароль ключа одинаковые.
- В текущую папку записывается только архив. Если `signKeystore.zip` уже есть, скрипт завершится и не изменит его.
- Пароль передаётся в `keytool` через переменную окружения, поэтому его не видно в `ps`.

## Gradle

Распакуйте архив в корень проекта и добавьте в `app/build.gradle.kts`:

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

Добавьте `signKeystore/` в `.gitignore` проекта.

## Безопасность

- В `keystore.properties` пароль хранится **открытым текстом**, а архив не защищён паролем. Любой, у кого есть архив, может подписывать сборки от вашего имени. Не коммитьте его и храните в надёжном месте, например в менеджере паролей.
- Сделайте резервную копию. Без ключа подписи приложения нельзя выпускать обновления. С Play App Signing этот keystore — ключ загрузки (*upload key*), его можно сбросить через поддержку Google Play.

## Лицензия

[MIT](LICENSE)
