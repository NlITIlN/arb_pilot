# arb_pilot ✈️

> Smart i18n CLI for Dart & Flutter — audits, auto-translates and keeps your `.arb` files in sync.

[![Dart](https://img.shields.io/badge/Dart-3.0%2B-blue?logo=dart)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey)]()
[![Zero deps](https://img.shields.io/badge/dependencies-zero-brightgreen)]()

---

## Что это

**arb_pilot** сканирует ваш Dart/Flutter проект, находит каждый вызов `l10n.someKey`, и сравнивает их с `.arb` файлами переводов. Затем сообщает — что отсутствует, что устарело, и при желании — автоматически переводит пробелы через DeepL, Google Translate, Yandex или локальный LLM через Ollama.

**Нет внешних зависимостей.** Только `dart:io`, `dart:convert`, `dart:core`. Запускается без `pub get`.

```
════════════════════════════════════════════════════════════
  ✈️  arb_pilot — i18n Revisor
════════════════════════════════════════════════════════════

📁 Обнаружено
  Dart файлов для анализа                       142
  .arb файлов найдено                            18

🔍 Анализ кода
  Уникальных ключей найдено                      84
  С @i18n-context аннотацией                     61

📊 Результаты
  Отсутствующих переводов                        12   ←
  Устаревших ключей                               3   ←
  Пустых значений                                 0   ✓
  Требуют ревью (NEEDS_REVIEW)                    0   ✓

🤖 Автоперевод (12 строк)
  [ru] createNode → "Создать узел"          (DeepL Free)
  [zh] createNode → "创建节点"              (DeepL Free)
  [hi] createNode → "नोड बनाएं"            (Google Translate)
  [de] createNode → "Knoten erstellen"      (DeepL Free)

════════════════════════════════════════════════════════════
  ✅ Готово — 12 строк · 4 языка · 3 сек
════════════════════════════════════════════════════════════
```

---

## Возможности

- **Аудит** — безопасное сканирование без изменений, можно запускать в любое время
- **Автоперевод** — DeepL → Google → Yandex → Ollama, fallback-цепочка автоматически
- **Офлайн режим** — полная работа без интернета через Ollama (llama3, mistral, gemma2...)
- **Поиск orphaned ключей** — находит переводы в `.arb`, которых больше нет в коде
- **Context-aware** — читает `@i18n-context` комментарии для точного перевода UI строк
- **Мультимодульный** — поддерживает `lib/core/l10n/`, `lib/features/*/l10n/`, `packages/*/lib/l10n/`
- **JSON вывод** — машиночитаемые отчёты для CI/CD
- **Нет зависимостей** — чистый Dart, не нужен `pub get`
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
# DeepL (лучшее качество для RU/DE/FR/ZH/ES)
dart run bin/language_revisor.dart --auto --deepl-key=YOUR_KEY:fx

# Google Translate (130+ языков включая хинди)
dart run bin/language_revisor.dart --auto --google-key=YOUR_KEY

# Оба — DeepL для EU языков, Google для хинди и остальных
dart run bin/language_revisor.dart --auto --deepl-key=DEEPL_KEY --google-key=GOOGLE_KEY

# Ollama — полностью офлайн, без API ключей
dart run bin/language_revisor.dart --auto --ollama-model=llama3
```

---

## Установка в проект

### Standalone (рекомендуется)

Клонировать рядом с проектом:

```
workspace/
├── my_app/
└── arb_pilot/
```

```bash
dart run arb_pilot/bin/language_revisor.dart --root=./my_app
```

### Встраивание

```bash
cp -r arb_pilot/bin your_project/
mkdir -p your_project/lib/tools
cp -r arb_pilot/lib/tools/i18n your_project/lib/tools/
```

Запуск из корня вашего проекта:

```bash
dart run bin/language_revisor.dart
```

Полное руководство по установке — в [INSTALLATION.md](INSTALLATION.md).

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

l10n_paths:               # Пути к .arb файлам (glob)
  - lib/core/l10n
  - lib/features/*/l10n
  - packages/*/lib/l10n

accessors:                # Паттерны обращения к переводам
  - l10n
  - AppLocalizations.of(context)
  # Для GetX:  tr
  # Для intl:  S.of(context), S.current

arb_prefix: app           # app → app_en.arb, app_ru.arb
```

**Defaults** без конфига:

| Параметр | Значение |
|---|---|
| `source_lang` | `en` |
| `target_langs` | `ru, zh, hi, es` |
| `l10n_paths` | `lib/core/l10n`, `lib/features/*/l10n` |
| `accessors` | `l10n`, `AppLocalizations.of(context)` |
| `arb_prefix` | `app` |

---

## Команды

### Режимы

```bash
dart run bin/language_revisor.dart                   # Аудит (read-only)
dart run bin/language_revisor.dart --auto            # Автоперевод
dart run bin/language_revisor.dart --interactive     # С подтверждением каждого шага
dart run bin/language_revisor.dart --auto --dry-run  # Показать план без изменений
```

### Провайдеры

```bash
--deepl-key=KEY       # DeepL (или env DEEPL_API_KEY)
--google-key=KEY      # Google Translate (или env GOOGLE_TRANSLATE_KEY)
--ollama-model=NAME   # Ollama модель (default: llama3)
--ollama-host=URL     # Ollama хост (default: http://localhost:11434)
```

### Фильтры

```bash
--langs=ru,zh,hi      # Только эти языки
--source-lang=ru      # Другой исходный язык
--root=PATH           # Корень проекта (default: текущая папка)
--remove-orphaned     # Удалить устаревшие ключи
```

### Вывод

```bash
--format=json         # JSON для CI/CD
--no-color            # Без ANSI цветов (Windows CMD)
```

Полный справочник команд — в [COMMANDS.md](COMMANDS.md).

---

## Context-аннотации

Добавляйте комментарии перед вызовами `l10n` — переводчик учтёт контекст.

```dart
// @i18n-context: button in knowledge graph view — creates a new note node
l10n.createNode

// @i18n-context: soft delete — moves item to archive, can be recovered
l10n.moveToArchive

// @i18n-context: placeholder text inside the global search input field
l10n.searchPlaceholder
```

Без контекста "node" может быть переведён как сетевой узел, дерево, или граф — это разные слова в большинстве языков. С контекстом перевод точный, и строка не помечается как `needsReview`.

---

## Провайдеры перевода

Цепочка пробуется по порядку, автоматический fallback:

```
DeepL → Google Translate → Yandex → Ollama → Stub (⚠️ NEEDS_REVIEW)
```

| Провайдер | Языков | Офлайн | Бесплатно |
|---|---|---|---|
| **DeepL** | 29 (EN, RU, ZH, DE, FR...) | ❌ | 500K символов/месяц |
| **Google Translate** | 130+ включая Hindi | ❌ | $300 кредит при регистрации |
| **Yandex Translate** | 100+ | ❌ | Бесплатный грант |
| **Ollama** | Все | ✅ | Бесплатно |
| **Stub** | Все | ✅ | Всегда бесплатно |

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

### Сгенерированный

```json
{
  "@@locale": "ru",
  "@@last_modified": "2026-05-01T12:00:00.000Z",
  "createItem": "Создать элемент",
  "@createItem": {
    "description": "Auto-translated by DeepL (Free)."
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
    "x-needs-review": true
  }
}
```

---

## CI/CD

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

      - name: Audit translations
        run: dart run bin/language_revisor.dart --format=json --no-color > i18n_report.json

      - name: Check for missing translations
        run: |
          MISSING=$(cat i18n_report.json | \
            python3 -c "import sys,json; print(json.load(sys.stdin)['by_type']['missing'])")
          echo "Missing: $MISSING"
          if [ "$MISSING" -gt "0" ]; then exit 2; fi

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
├── INSTALLATION.md        ← установка и интеграция
├── COMMANDS.md            ← справочник всех команд
├── PROVIDERS.md           ← настройка провайдеров
├── CHANGELOG.md
├── LICENSE
├── arb_pilot.yaml         ← пример конфига
├── example/
│   └── app_en.arb
├── bin/
│   └── language_revisor.dart   ← точка входа CLI
└── lib/
    └── tools/
        └── i18n/
            ├── discovery.dart
            ├── ast_parser.dart
            ├── differ.dart
            ├── validator.dart
            ├── reporter.dart
            ├── arb_writer.dart
            └── translator/
                ├── provider.dart
                ├── chain.dart
                ├── deepl_provider.dart
                ├── google_provider.dart
                ├── yandex_provider.dart
                ├── llm_provider.dart
                └── stub_provider.dart
```

---

## Переменные окружения

```bash
DEEPL_API_KEY=abc123:fx
GOOGLE_TRANSLATE_KEY=AIzaSy...
YANDEX_TRANSLATE_KEY=AQVNy...
ARB_PILOT_ROOT=/path/to/project    # альтернатива --root
DEBUG=1                             # подробный вывод ошибок
```

---

## License

MIT © 2026
