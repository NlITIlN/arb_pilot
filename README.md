# arb_pilot ✈️

> Smart i18n CLI for Dart & Flutter — audits, auto-translates and keeps your `.arb` files in sync.

[![Dart](https://img.shields.io/badge/Dart-3.0%2B-blue?logo=dart)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey)]()
[![Zero deps](https://img.shields.io/badge/dependencies-zero-brightgreen)]()

---

## Что это

**arb_pilot** сканирует ваш Dart/Flutter проект через AST-парсер, находит каждый вызов `l10n.someKey`, сравнивает с `.arb` файлами переводов и сообщает — что отсутствует, что устарело. При желании автоматически переводит пробелы через DeepL, Google Translate, Yandex или локальный LLM через Ollama.

**Нет внешних зависимостей** — только `dart:io`, `dart:convert`, `dart:core`. Не нужен `pub get`.

```
══════════════════════════════════════════════════════════════
  ✈️  arb_pilot — i18n Revisor
  Проект: /path/to/my_app
══════════════════════════════════════════════════════════════

📁 Обнаружено
  Dart файлов для анализа                       142
  .arb файлов найдено                            18
    core: [en, ru, zh, hi, de]
    auth: [en, ru]
    profile: [en, ru, zh]

🔍 Анализ кода
  Уникальных ключей найдено                      84
  С @i18n-context аннотацией                 61 / 84
  ⚠  23 ключей без контекста — качество перевода ниже

📊 Результаты проверки
  Отсутствующих переводов                        12   ←
  Устаревших ключей (orphaned)                    3   ←
  Пустых значений                                 0   ✓
  Требуют ревью (NEEDS_REVIEW)                    0   ✓

🔌 Провайдеры перевода
    ✓ DeepL Free
    ✓ Google Translate
    ✗ Yandex Translate
    ✗ Ollama (llama3)

🤖 Автоперевод (12 строк)
  [ru] createNode → "Создать узел"          (DeepL Free)
  [zh] createNode → "创建节点"              (DeepL Free)
  [hi] createNode → "नोड बनाएं"            (Google Translate)
  [de] createNode → "Knoten erstellen"      (DeepL Free)
  ...

══════════════════════════════════════════════════════════════
  ✅ Переведено          12 строк
  ⏱  Время              4с
══════════════════════════════════════════════════════════════

  🎉 Локализация обновлена!
```

---

## Возможности

- **Аудит** — безопасное сканирование без изменений, запускайте в любое время
- **AST-парсер** — находит ключи через regex без тяжёлого `package:analyzer`
- **Автоперевод** — DeepL → Google → Yandex → Ollama, fallback-цепочка автоматически
- **Офлайн режим** — полная работа без интернета через Ollama (llama3, mistral, gemma2...)
- **Orphan detection** — находит ключи в `.arb` которых больше нет в коде
- **Quality checks** — пустые значения, NEEDS_REVIEW, placeholder mismatch, слишком длинные строки
- **Context-aware** — читает `@i18n-context` комментарии для точного перевода UI строк
- **Мультимодульный** — `lib/core/l10n/`, `lib/features/*/l10n/`, `packages/*/lib/l10n/`
- **JSON вывод** — машиночитаемые отчёты с coverage по языкам для CI/CD
- **Нет зависимостей** — чистый Dart, `pub get` не нужен
- **Конфигурируемый** — `arb_pilot.yaml` адаптирует под любую структуру проекта

---

## Быстрый старт

### 1. Получить arb_pilot

```bash
git clone https://github.com/YOUR_NAME/arb_pilot.git
```

### 2. Создать исходный `.arb` файл

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
    "description": "Button label in the main list view — creates a new item"
  }
}
EOF
```

### 3. Аудит — проверить состояние (ничего не меняет)

```bash
dart run bin/language_revisor.dart
```

### 4. Автоперевод

```bash
# DeepL — лучшее качество для RU/DE/FR/ZH/ES
dart run bin/language_revisor.dart --auto --deepl-key=YOUR_KEY:fx

# Google Translate — 130+ языков включая хинди
dart run bin/language_revisor.dart --auto --google-key=YOUR_KEY

# Лучшая комбинация — DeepL + Google
dart run bin/language_revisor.dart --auto \
  --deepl-key=DEEPL_KEY:fx \
  --google-key=GOOGLE_KEY

# Yandex — отлично для RU и постсоветских языков
dart run bin/language_revisor.dart --auto --yandex-key=YOUR_KEY

# Ollama — полностью офлайн, без API ключей
dart run bin/language_revisor.dart --auto --ollama-model=llama3
```

---

## Установка в проект

### Standalone (рекомендуется)

```
workspace/
├── my_app/
└── arb_pilot/
```

```bash
dart run arb_pilot/bin/language_revisor.dart --root=./my_app
```

### Встраивание в проект

```bash
cp -r arb_pilot/bin your_project/
mkdir -p your_project/lib/tools
cp -r arb_pilot/lib/tools/i18n your_project/lib/tools/
```

Запуск из корня проекта:

```bash
dart run bin/language_revisor.dart
```

Полное руководство — в [INSTALLATION.md](INSTALLATION.md).

---

## Конфигурация

Создайте `arb_pilot.yaml` в корне проекта. Все поля опциональны.

```yaml
# arb_pilot.yaml

source_lang: en           # Исходный язык (ведёте вручную)

target_langs:             # Целевые языки
  - ru
  - zh
  - hi
  - es
  - de
  - fr
  - ja
  - pt

l10n_paths:               # Пути к .arb файлам (glob поддерживается)
  - lib/core/l10n
  - lib/features/*/l10n
  - packages/*/lib/l10n

accessors:                # Паттерны обращения к переводам в коде
  - l10n
  - AppLocalizations.of(context)
  # GetX:   tr
  # intl:   S.of(context), S.current

arb_prefix: app           # app → app_en.arb, app_ru.arb
```

**Defaults без конфига:**

| Параметр | Значение |
|---|---|
| `source_lang` | `en` |
| `target_langs` | `ru, zh, hi, es` |
| `l10n_paths` | `lib/core/l10n`, `lib/features/*/l10n` |
| `accessors` | `l10n`, `AppLocalizations.of(context)` |
| `arb_prefix` | `app` |

---

## Context-аннотации

Добавляйте `@i18n-context` комментарии перед вызовами `l10n` — переводчик учтёт контекст UI.

```dart
// @i18n-context: button in knowledge graph view — creates a new note node
final label = l10n.createNode;

// @i18n-context: soft delete — moves item to archive, recoverable later
final action = l10n.moveToArchive;

// @i18n-context: placeholder text inside the global search input field
final hint = l10n.searchPlaceholder;

// @i18n-context: toggle button that pauses physics simulation on canvas
final toggle = l10n.pausePhysics;
```

Без контекста "node" может быть переведён как сетевой узел, дерево или граф — это разные слова в большинстве языков. С контекстом перевод точный, и строка **не** помечается как `needsReview`.

---

## Провайдеры перевода

Fallback-цепочка — пробуется по порядку, автоматически:

```
DeepL → Google Translate → Yandex → Ollama → Stub (⚠️ NEEDS_REVIEW)
```

| Провайдер | Языков | Хинди | Офлайн | Бесплатно |
|---|---|---|---|---|
| **DeepL** | 29 (EN, RU, ZH, DE, FR...) | ❌ | ❌ | 500K символов/мес |
| **Google Translate** | 130+ | ✅ | ❌ | $300 кредит |
| **Yandex Translate** | 100+ (RU, KK, UZ...) | ❌ | ❌ | Грант |
| **Ollama** | Все | ✅ | ✅ | Бесплатно |
| **Stub** | Все | ✅ | ✅ | Всегда |

Free ключи DeepL заканчиваются на `:fx` — arb_pilot определяет это автоматически.

Подробная настройка каждого провайдера — в [PROVIDERS.md](PROVIDERS.md).

---

## Формат `.arb` файлов

### Исходный (пишете вручную)

```json
{
  "@@locale": "en",
  "createItem": "Create item",
  "@createItem": {
    "description": "Button label in main list view"
  },
  "itemCount": "{count, plural, one{{count} item} other{{count} items}}",
  "@itemCount": {
    "placeholders": {
      "count": { "type": "int" }
    }
  }
}
```

### Сгенерированный (arb_pilot пишет)

```json
{
  "@@locale": "ru",
  "@@last_modified": "2026-05-14T12:00:00.000Z",
  "createItem": "Создать элемент",
  "@createItem": {
    "description": "Auto-translated by DeepL Free.",
    "x-source": "Create item"
  }
}
```

### Требует ревью (нет провайдеров)

```json
{
  "@@locale": "zh",
  "createItem": "⚠️ NEEDS_REVIEW: Create item",
  "@createItem": {
    "description": "Auto-translated by Stub. NEEDS REVIEW.",
    "x-needs-review": true,
    "x-source": "Create item"
  }
}
```

Найти строки требующие ревью:

```bash
grep -r "NEEDS_REVIEW" lib/*/l10n/ packages/*/lib/l10n/
```

---

## Все команды

```bash
dart run bin/language_revisor.dart                          # Аудит
dart run bin/language_revisor.dart --auto                   # Автоперевод
dart run bin/language_revisor.dart --interactive            # С подтверждением
dart run bin/language_revisor.dart --auto --dry-run         # Предпросмотр

dart run bin/language_revisor.dart --auto --deepl-key=KEY
dart run bin/language_revisor.dart --auto --google-key=KEY
dart run bin/language_revisor.dart --auto --yandex-key=KEY
dart run bin/language_revisor.dart --auto --ollama-model=llama3

dart run bin/language_revisor.dart --langs=ru,zh            # Только эти языки
dart run bin/language_revisor.dart --interactive --remove-orphaned
dart run bin/language_revisor.dart --format=json            # JSON для CI/CD
dart run bin/language_revisor.dart --root=../my_app         # Другой проект
dart run bin/language_revisor.dart --help                   # Справка
```

Полный справочник — в [COMMANDS.md](COMMANDS.md).

---

## CI/CD

```yaml
# .github/workflows/i18n.yml
name: i18n Audit & Translate

on:
  push:
    branches: [main]
  pull_request:

jobs:
  i18n:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable

      - name: Audit
        run: |
          dart run bin/language_revisor.dart \
            --format=json --no-color > i18n_report.json
        continue-on-error: true

      - name: Auto-translate
        if: github.ref == 'refs/heads/main'
        env:
          DEEPL_API_KEY: ${{ secrets.DEEPL_API_KEY }}
          GOOGLE_TRANSLATE_KEY: ${{ secrets.GOOGLE_TRANSLATE_KEY }}
        run: dart run bin/language_revisor.dart --auto --no-color

      - name: Commit translations
        if: github.ref == 'refs/heads/main'
        run: |
          git config user.name "arb_pilot"
          git config user.email "bot@arb-pilot.dev"
          git add "lib/**/l10n/*.arb" "packages/**/l10n/*.arb" || true
          git diff --staged --quiet || \
            git commit -m "chore: auto-translate [skip ci]"
          git push || true

      - name: Upload report
        uses: actions/upload-artifact@v4
        with:
          name: i18n-report
          path: i18n_report.json
```

---

## Коды выхода

| Код | Значение |
|---|---|
| `0` | Всё синхронизировано / перевод успешен |
| `1` | Ошибка — сеть, неверный ключ, битый `.arb` |
| `2` | Аудит завершён — найдены проблемы (для git hooks и CI) |

---

## Структура репозитория

```
arb_pilot/
├── README.md
├── INSTALLATION.md       ← установка и интеграция
├── COMMANDS.md           ← все команды и флаги
├── PROVIDERS.md          ← настройка провайдеров
├── CHANGELOG.md
├── LICENSE
├── arb_pilot.yaml        ← пример конфига
├── example/
│   └── app_en.arb        ← пример исходного файла
├── bin/
│   └── language_revisor.dart        ← точка входа CLI
└── lib/
    └── tools/
        └── i18n/
            ├── config.dart           ← загрузка настроек
            ├── discovery.dart        ← поиск файлов
            ├── ast_parser.dart       ← извлечение ключей
            ├── differ.dart           ← поиск пробелов
            ├── arb_writer.dart       ← запись переводов
            ├── reporter.dart         ← вывод в терминал/JSON
            ├── path_utils.dart       ← утилиты путей
            └── translator/
                ├── provider.dart     ← интерфейс
                ├── chain.dart        ← fallback-цепочка
                ├── deepl_provider.dart
                ├── google_provider.dart
                ├── yandex_provider.dart
                ├── llm_provider.dart ← Ollama
                └── stub_provider.dart
```

---

## Переменные окружения

```bash
DEEPL_API_KEY=abc123:fx
GOOGLE_TRANSLATE_KEY=AIzaSy...
YANDEX_TRANSLATE_KEY=AQVNy...
OLLAMA_MODEL=llama3
OLLAMA_HOST=http://localhost:11434
ARB_PILOT_ROOT=/path/to/project
NO_COLOR=1
DEBUG=1
```

---

## License

MIT © 2026
