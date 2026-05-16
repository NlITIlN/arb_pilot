# arb_pilot — Установка и интеграция

> Пошаговое руководство по встраиванию arb_pilot в любой Dart/Flutter проект.

---

## Содержание

- [Требования](#требования)
- [Способы установки](#способы-установки)
- [Шаг 1 — Копирование файлов](#шаг-1--копирование-файлов)
- [Шаг 2 — pubspec.yaml](#шаг-2--pubspecyaml)
- [Шаг 3 — arb_pilot.yaml](#шаг-3--arb_pilotyaml)
- [Шаг 4 — Первый запуск](#шаг-4--первый-запуск)
- [Структура l10n директорий](#структура-l10n-директорий)
- [Частые проблемы](#частые-проблемы)
- [Интеграция в CI/CD](#интеграция-в-cicd)

---

## Требования

| Требование | Версия | Примечание |
|---|---|---|
| Dart SDK | 3.0+ | Обязательно |
| Flutter | любая | Опционально — работает и без Flutter |
| ОС | macOS / Linux / Windows | Полная поддержка |

arb_pilot **не имеет внешних зависимостей** — `pub get` не нужен.
Используются только встроенные пакеты: `dart:io`, `dart:convert`, `dart:core`.

---

## Способы установки

### Вариант A — Standalone (рекомендуется)

Клонировать рядом с проектом и запускать с флагом `--root`:

```
workspace/
├── my_app/          ← ваш проект
└── arb_pilot/       ← инструмент рядом
```

```bash
git clone https://github.com/YOUR_NAME/arb_pilot.git
dart run arb_pilot/bin/language_revisor.dart --root=./my_app
```

Плюсы: arb_pilot не трогает ваш проект, обновляется независимо.

---

### Вариант B — Встраивание в проект

Скопировать папки `bin/` и `lib/tools/i18n/` прямо в ваш проект:

```bash
git clone https://github.com/YOUR_NAME/arb_pilot.git /tmp/arb_pilot

cp -r /tmp/arb_pilot/bin      your_project/
mkdir -p your_project/lib/tools
cp -r /tmp/arb_pilot/lib/tools/i18n  your_project/lib/tools/
cp    /tmp/arb_pilot/arb_pilot.yaml  your_project/
```

Запуск из корня вашего проекта:

```bash
dart run bin/language_revisor.dart
```

---

### Вариант C — Git submodule

```bash
git submodule add https://github.com/YOUR_NAME/arb_pilot.git tools/arb_pilot
git submodule update --init
```

Запуск:

```bash
dart run tools/arb_pilot/bin/language_revisor.dart --root=.
```

---

## Шаг 1 — Копирование файлов

После установки структура должна выглядеть так:

```
your_project/
├── arb_pilot.yaml                          ← конфиг (шаг 3)
├── bin/
│   └── language_revisor.dart               ← точка входа CLI
└── lib/
    └── tools/
        └── i18n/
            ├── config.dart                 ← загрузка настроек
            ├── discovery.dart              ← поиск .arb и .dart файлов
            ├── ast_parser.dart             ← извлечение ключей из кода
            ├── differ.dart                 ← поиск пробелов и orphaned
            ├── arb_writer.dart             ← запись в .arb файлы
            ├── reporter.dart               ← вывод в терминал и JSON
            ├── path_utils.dart             ← утилиты для путей
            └── translator/
                ├── provider.dart           ← интерфейс провайдера
                ├── chain.dart              ← fallback-цепочка
                ├── deepl_provider.dart
                ├── google_provider.dart
                ├── yandex_provider.dart
                ├── llm_provider.dart       ← Ollama
                └── stub_provider.dart      ← заглушка
```

> ⚠️ Папка `lib/tools/i18n/` должна быть именно внутри `lib/` —
> так Dart находит файлы без дополнительных настроек. Не переносите её.

---

## Шаг 2 — pubspec.yaml

arb_pilot **не требует никаких изменений** в `pubspec.yaml` вашего проекта.
Никаких новых зависимостей — только стандартная библиотека Dart.

Единственное что нужно проверить:

```yaml
environment:
  sdk: '>=3.0.0 <4.0.0'
```

Если у вас Flutter проект — это уже есть. Если чистый Dart — убедитесь что версия SDK 3.0+.

---

## Шаг 3 — arb_pilot.yaml

Создайте файл `arb_pilot.yaml` в корне проекта. Все поля опциональны —
если файл отсутствует, используются значения по умолчанию.

```yaml
# arb_pilot.yaml — кладётся в корень проекта

# Исходный язык — .arb файл, который вы ведёте вручную
source_lang: en

# Целевые языки для генерации
target_langs:
  - ru
  - zh
  - hi
  - es
  - de
  - fr
  - ja
  - pt

# Пути к .arb файлам (поддерживаются glob-паттерны со *)
l10n_paths:
  - lib/core/l10n
  - lib/features/*/l10n
  - packages/*/lib/l10n

# Как в коде обращаются к переводам — под эти паттерны настроен AST-парсер
# Flutter (по умолчанию):
accessors:
  - l10n
  - AppLocalizations.of(context)
# GetX:        tr
# intl:        S.of(context), S.current
# Кастомный:   MyStrings.of(context)

# Префикс .arb файлов: app → app_en.arb, app_ru.arb
arb_prefix: app
```

### Значения по умолчанию (без arb_pilot.yaml)

| Параметр | Значение |
|---|---|
| `source_lang` | `en` |
| `target_langs` | `ru, zh, hi, es` |
| `l10n_paths` | `lib/core/l10n`, `lib/features/*/l10n` |
| `accessors` | `l10n`, `AppLocalizations.of(context)` |
| `arb_prefix` | `app` |

---

## Шаг 4 — Первый запуск

### Проверьте Dart

```bash
dart --version
# Dart SDK version: 3.x.x
```

### Создайте исходный .arb файл если его нет

```bash
mkdir -p lib/core/l10n

cat > lib/core/l10n/app_en.arb << 'EOF'
{
  "@@locale": "en",
  "appTitle": "My App",
  "@appTitle": {
    "description": "Application name shown in the title bar"
  },
  "createItem": "Create item",
  "@createItem": {
    "description": "Button label in the main list view"
  }
}
EOF
```

### Запустите аудит (ничего не изменяет)

```bash
# Вариант B/C — из корня проекта
dart run bin/language_revisor.dart

# Вариант A — из папки arb_pilot
dart run bin/language_revisor.dart --root=../my_app
```

Ожидаемый вывод:

```
══════════════════════════════════════════════════════════════
  ✈️  arb_pilot — i18n Revisor
  Проект: /path/to/your_project
══════════════════════════════════════════════════════════════

📁 Обнаружено
  Dart файлов для анализа                       142
  .arb файлов найдено                            18
    core: [en, ru, zh]
    auth: [en, ru]

🔍 Анализ кода
  Уникальных ключей найдено                      84
  С @i18n-context аннотацией                 61 / 84

📊 Результаты проверки
  Отсутствующих переводов                        12
  Устаревших ключей (orphaned)                    3
  Пустых значений                                 0
  Требуют ревью (NEEDS_REVIEW)                    0
```

---

## Структура l10n директорий

arb_pilot автоматически определяет модуль по пути к файлу:

```
lib/
├── core/
│   └── l10n/
│       ├── app_en.arb    ← пишете вручную (source)
│       ├── app_ru.arb    ← генерируется автоматически
│       ├── app_zh.arb    ← генерируется автоматически
│       └── app_hi.arb    ← генерируется автоматически
└── features/
    ├── auth/
    │   └── l10n/
    │       ├── app_en.arb
    │       └── app_ru.arb
    └── profile/
        └── l10n/
            ├── app_en.arb
            └── app_ru.arb

packages/
└── ui_kit/
    └── lib/
        └── l10n/
            ├── ui_kit_en.arb
            └── ui_kit_ru.arb
```

### Маппинг путей → модули

| Путь | Модуль | Куда пишет arb_pilot |
|---|---|---|
| `lib/core/l10n/` | `core` | `lib/core/l10n/app_ru.arb` |
| `lib/features/auth/l10n/` | `auth` | `lib/features/auth/l10n/app_ru.arb` |
| `packages/ui_kit/lib/l10n/` | `pkg_ui_kit` | `packages/ui_kit/lib/l10n/ui_kit_ru.arb` |

### Формат исходного .arb файла

```json
{
  "@@locale": "en",
  "createItem": "Create item",
  "@createItem": {
    "description": "Button label — creates a new item in the list"
  },
  "itemCount": "{count, plural, one{{count} item} other{{count} items}}",
  "@itemCount": {
    "description": "Item counter in list header",
    "placeholders": {
      "count": { "type": "int" }
    }
  }
}
```

> Чем подробнее `description` в `@key` — тем точнее автоперевод.

---

## Частые проблемы

### ❌ `dart: command not found`

Dart SDK не установлен или не в PATH.

```bash
# macOS
brew install dart

# Linux (Ubuntu/Debian)
sudo apt-get update && sudo apt-get install dart

# Или установите Flutter — он включает Dart
```

---

### ❌ `No .arb files found`

arb_pilot не нашёл ни одного `.arb` файла.

Причины:

**1. Файлы по нестандартному пути** — добавьте в `arb_pilot.yaml`:

```yaml
l10n_paths:
  - lib/l10n              # нестандартный путь
  - assets/translations   # другой нестандартный путь
```

**2. Файлы названы неверно** — ожидается `PREFIX_LANGCODE.arb`:

```bash
# Правильно
app_en.arb
app_ru.arb

# Неправильно
en.arb
strings_english.arb
```

Проверьте `arb_prefix` в конфиге (по умолчанию `app`).

**3. Директория не существует** — создайте:

```bash
mkdir -p lib/core/l10n
echo '{"@@locale": "en", "hello": "Hello"}' > lib/core/l10n/app_en.arb
```

---

### ❌ `No keys found in code`

AST-парсер не нашёл вызовов локализации.

Добавьте ваш accessor в `arb_pilot.yaml`:

```yaml
accessors:
  - l10n                          # Flutter default
  - AppLocalizations.of(context)  # Flutter default
  - tr                            # GetX
  - S.of(context)                 # intl
  - t                             # easy_localization
  - MyStrings.of(context)         # кастомный wrapper
```

Парсер ищет паттерн `ACCESSOR.keyName` — если accessor не в списке, ключи не найдутся.

---

### ❌ DeepL 403 Forbidden

```bash
# Проверьте ключ напрямую (Free)
curl -X GET "https://api-free.deepl.com/v2/usage" \
  -H "Authorization: DeepL-Auth-Key YOUR_KEY:fx"

# Pro
curl -X GET "https://api.deepl.com/v2/usage" \
  -H "Authorization: DeepL-Auth-Key YOUR_KEY"
```

Убедитесь что Free ключ заканчивается на `:fx`.

---

### ❌ Google `API key not valid`

```bash
curl "https://translation.googleapis.com/language/translate/v2?key=YOUR_KEY&q=hello&target=ru"
```

В Google Cloud Console убедитесь что для ключа включён **Cloud Translation API**.

---

### ❌ Ollama `Connection refused`

```bash
# Проверьте что Ollama запущен
curl http://localhost:11434/api/tags

# Если нет — запустите
ollama serve

# Проверьте что модель скачана
ollama list
ollama pull llama3   # если модели нет
```

---

### ❌ Переводы пишутся не туда

arb_pilot вычисляет путь из имени модуля. Проверьте соответствие:

```bash
# Запустите с --debug чтобы увидеть детали
dart run bin/language_revisor.dart --debug
```

Если нужен нестандартный путь — настройте `l10n_paths` в конфиге.

---

### ❌ Windows: кракозябры вместо цветов

```bash
dart run bin/language_revisor.dart --no-color
```

Или используйте Windows Terminal — он поддерживает ANSI автоматически.

---

### ❌ Plural-строки переводятся с ошибками

Строки формата ICU (`{count, plural, one{...} other{...}}`) передаются переводчику как есть.
Добавьте `@i18n-context` с явным указанием:

```dart
// @i18n-context: plural form — {count} is a number. Keep the ICU plural syntax unchanged, translate only the word "item"/"items" inside the plural forms
l10n.itemCount
```

---

## Интеграция в CI/CD

### GitHub Actions — аудит на каждый PR

```yaml
# .github/workflows/i18n_audit.yml
name: i18n Audit

on: [push, pull_request]

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable

      - name: Run audit
        run: |
          dart run bin/language_revisor.dart \
            --format=json --no-color > i18n_report.json
        continue-on-error: true

      - name: Check results
        run: |
          MISSING=$(python3 -c \
            "import json; r=json.load(open('i18n_report.json')); print(r['by_type']['missing'])")
          echo "Missing translations: $MISSING"
          [ "$MISSING" -eq "0" ] || exit 2

      - name: Upload report
        uses: actions/upload-artifact@v4
        with:
          name: i18n-report
          path: i18n_report.json
```

### Pre-commit hook

```bash
# .git/hooks/pre-commit
#!/bin/sh
dart run bin/language_revisor.dart --format=json --no-color \
  > /tmp/i18n_check.json 2>&1

MISSING=$(python3 -c \
  "import json; r=json.load(open('/tmp/i18n_check.json')); \
   print(r['by_type']['missing'])" 2>/dev/null || echo "0")

if [ "$MISSING" -gt "0" ]; then
  echo "⚠️  arb_pilot: $MISSING missing translations."
  echo "   Run: dart run bin/language_revisor.dart --auto"
fi
exit 0   # предупреждаем, но не блокируем
```

```bash
chmod +x .git/hooks/pre-commit
```

### .gitignore

```gitignore
# arb_pilot
.dart_tool/
pubspec.lock
build/
*.tar.gz
i18n_report.json
```
