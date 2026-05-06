# arb_pilot — Установка и интеграция

> Пошаговое руководство по встраиванию arb_pilot в любой Dart/Flutter проект.

---

## Содержание

- [Требования](#требования)
- [Способы установки](#способы-установки)
- [Шаг 1 — Копирование файлов](#шаг-1--копирование-файлов)
- [Шаг 2 — Настройка pubspec.yaml](#шаг-2--настройка-pubspecyaml)
- [Шаг 3 — Конфигурация arb_pilot.yaml](#шаг-3--конфигурация-arb_pilotyaml)
- [Шаг 4 — Первый запуск](#шаг-4--первый-запуск)
- [Структура l10n директорий](#структура-l10n-директорий)
- [Частые проблемы и решения](#частые-проблемы-и-решения)
- [Интеграция в CI/CD](#интеграция-в-cicd)

---

## Требования

| Требование | Версия | Примечание |
|---|---|---|
| Dart SDK | 3.0+ | Обязательно |
| Flutter | любая | Опционально — arb_pilot работает и без Flutter |
| ОС | macOS / Linux / Windows | Полная поддержка |

arb_pilot **не имеет внешних зависимостей** — не нужен `pub get`, не нужен `pubspec.lock`.
Единственные пакеты — стандартная библиотека Dart: `dart:io`, `dart:convert`, `dart:core`.

---

## Способы установки

### Вариант A — Standalone репозиторий (рекомендуется)

Клонировать arb_pilot рядом с вашим проектом и запускать, указывая `--root`:

```
workspace/
├── my_app/          ← ваш проект
└── arb_pilot/       ← инструмент рядом
```

```bash
git clone https://github.com/YOUR_NAME/arb_pilot.git
cd arb_pilot
dart run bin/language_revisor.dart --root=../my_app
```

Плюсы: arb_pilot не засоряет ваш проект, обновляется независимо.

---

### Вариант B — Встраивание в проект (subtree / копирование)

Скопировать папки `bin/` и `lib/tools/i18n/` прямо в ваш проект:

```bash
git clone https://github.com/YOUR_NAME/arb_pilot.git /tmp/arb_pilot

# Копируем точку входа
cp -r /tmp/arb_pilot/bin your_project/

# Копируем библиотеку
mkdir -p your_project/lib/tools
cp -r /tmp/arb_pilot/lib/tools/i18n your_project/lib/tools/

# Копируем пример конфига
cp /tmp/arb_pilot/arb_pilot.yaml your_project/
```

Плюсы: запуск из корня проекта без `--root`, файлы под вашим git.

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

После клонирования структура должна выглядеть так:

```
your_project/
├── arb_pilot.yaml                     ← конфиг (создадите на шаге 3)
├── bin/
│   └── language_revisor.dart          ← точка входа CLI
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
                ├── llm_provider.dart
                └── stub_provider.dart
```

> ⚠️ Папка `lib/tools/i18n/` намеренно находится внутри `lib/` — это позволяет Dart
> находить файлы без дополнительных путей. Не переносите её.

---

## Шаг 2 — Настройка pubspec.yaml

arb_pilot **не требует никаких дополнений** в `pubspec.yaml` вашего проекта.
Он использует только встроенные Dart пакеты.

Единственное что нужно проверить — что в вашем `pubspec.yaml` уже есть:

```yaml
environment:
  sdk: '>=3.0.0 <4.0.0'
```

Если у вас Flutter проект, там это уже есть. Если чистый Dart — добавьте.

---

## Шаг 3 — Конфигурация arb_pilot.yaml

Создайте файл `arb_pilot.yaml` в корне проекта. Все поля опциональны —
если файл отсутствует, arb_pilot использует значения по умолчанию.

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

# Пути к .arb файлам (поддерживаются glob-паттерны)
l10n_paths:
  - lib/core/l10n             # ядро приложения
  - lib/features/*/l10n      # feature-модули
  - packages/*/lib/l10n      # локальные пакеты

# Как в вашем коде обращаются к переводам
# Flutter (по умолчанию):
accessors:
  - l10n
  - AppLocalizations.of(context)
# GetX:
#   - tr
# intl:
#   - S.of(context)
#   - S.current
# Кастомный wrapper:
#   - MyStrings.of(context)

# Префикс файлов: app → app_en.arb, app_ru.arb
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

### Проверьте, что Dart доступен

```bash
dart --version
# Dart SDK version: 3.x.x
```

### Запустите аудит (безопасно, ничего не меняет)

```bash
# Из корня вашего проекта (вариант B/C)
dart run bin/language_revisor.dart

# Из папки arb_pilot (вариант A)
dart run bin/language_revisor.dart --root=../my_app
```

Вы должны увидеть:

```
════════════════════════════════════════════════════════════
  ✈️  arb_pilot — i18n Revisor
════════════════════════════════════════════════════════════
  Проект: /path/to/your_project

📁 Обнаружено
  Dart файлов для анализа              142
  .arb файлов найдено                   18

🔍 Анализ кода
  Уникальных ключей найдено             84

📊 Результаты
  Отсутствующих переводов               12
  Устаревших ключей                      3
```

---

## Структура l10n директорий

arb_pilot ищет `.arb` файлы по следующей схеме:

```
lib/
├── core/
│   └── l10n/
│       ├── app_en.arb    ← пишете вручную (source)
│       ├── app_ru.arb    ← генерируется
│       ├── app_zh.arb    ← генерируется
│       └── app_hi.arb    ← генерируется
└── features/
    ├── auth/
    │   └── l10n/
    │       ├── app_en.arb
    │       └── app_ru.arb
    └── profile/
        └── l10n/
            ├── app_en.arb
            └── app_ru.arb
```

Если у вас другая структура — настройте `l10n_paths` в `arb_pilot.yaml`.

### Формат исходного .arb файла

```json
{
  "@@locale": "en",
  "appTitle": "My App",
  "@appTitle": {
    "description": "Application name shown in the title bar"
  },
  "createItem": "Create item",
  "@createItem": {
    "description": "Button label in the main list view — creates a new item"
  },
  "itemCount": "{count, plural, one{{count} item} other{{count} items}}",
  "@itemCount": {
    "description": "Item counter label",
    "placeholders": {
      "count": { "type": "int" }
    }
  }
}
```

> Чем подробнее описание в `@key.description` — тем точнее автоперевод.

---

## Частые проблемы и решения

### ❌ `dart: command not found`

Dart SDK не установлен или не в PATH.

```bash
# macOS (Homebrew)
brew install dart

# Linux (официальный)
sudo apt-get update && sudo apt-get install dart

# Или установите Flutter SDK — он включает Dart
```

---

### ❌ `No .arb files found`

arb_pilot не нашёл ни одного `.arb` файла.

**Причины и решения:**

1. Файлы находятся по нестандартному пути — добавьте `l10n_paths` в `arb_pilot.yaml`
2. Файлы названы неверно — ожидается `prefix_langcode.arb` (например `app_en.arb`). Проверьте `arb_prefix`
3. Директория ещё не создана — создайте её и добавьте хотя бы `app_en.arb`

```bash
mkdir -p lib/core/l10n
echo '{"@@locale": "en", "hello": "Hello"}' > lib/core/l10n/app_en.arb
```

---

### ❌ `No keys found in code`

AST-парсер не нашёл вызовов локализации в Dart коде.

**Причины:**

1. Вы используете нестандартный accessor — добавьте его в `accessors` в конфиге:

```yaml
accessors:
  - tr                        # GetX
  - S.of(context)             # intl
  - AppStrings.of(context)    # кастомный
```

2. Код в папках, которые arb_pilot пропускает (`bin/`, `*.g.dart`, `*.freezed.dart`) — это нормально, они намеренно исключены.

---

### ❌ Ошибка DeepL: `403 Forbidden`

Неверный API ключ или исчерпан лимит.

```bash
# Проверьте ключ напрямую
curl -X GET "https://api-free.deepl.com/v2/usage" \
  -H "Authorization: DeepL-Auth-Key YOUR_KEY:fx"
```

Free ключи заканчиваются на `:fx` — убедитесь, что суффикс на месте.

---

### ❌ Ошибка Google: `API key not valid`

```bash
# Проверьте ключ
curl "https://translation.googleapis.com/language/translate/v2?key=YOUR_KEY&q=hello&target=ru"
```

Убедитесь, что в Google Cloud Console для ключа включён **Cloud Translation API**.

---

### ❌ Ollama: `Connection refused`

```bash
# Проверьте, запущен ли Ollama
curl http://localhost:11434/api/tags

# Если нет — запустите
ollama serve

# Скачайте модель если нет
ollama pull llama3
```

---

### ❌ Переводы пишутся в неверную директорию

arb_pilot вычисляет путь к `.arb` файлу по имени модуля:

- Модуль `core` → `lib/core/l10n/app_ru.arb`
- Модуль `auth` (feature) → `lib/features/auth/l10n/app_ru.arb`
- Модуль `pkg/ui_kit` (пакет) → `packages/ui_kit/lib/l10n/app_ru.arb`

Если нужен другой путь — настройте `l10n_paths` в конфиге.

---

### ❌ `const JsonEncoder` — ошибка компиляции

Если встречаете `Error: Not a constant expression` — это known issue.
В Dart `JsonEncoder.withIndent()` должен быть `final`, не `const`:

```dart
// Неверно
const encoder = JsonEncoder.withIndent('  ');

// Верно
final encoder = JsonEncoder.withIndent('  ');
```

---

### ❌ Windows: ANSI цвета не отображаются

```bash
dart run bin/language_revisor.dart --no-color
```

Или используйте Windows Terminal (он поддерживает ANSI автоматически).

---

### ❌ Plural-строки переводятся некорректно

Строки формата `{count, plural, one{...} other{...}}` пока передаются переводчику как есть.
При переводе через DeepL или Google они могут быть искажены.

**Временное решение:** переводите plural-строки вручную или добавьте `@i18n-context` с явным указанием что это plural:

```dart
// @i18n-context: plural form — {count} is a number. Translate only the word "item"/"items", keep the ICU syntax unchanged
l10n.itemCount
```

---

## Интеграция в CI/CD

### GitHub Actions

```yaml
# .github/workflows/i18n_audit.yml
name: i18n Audit

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable

      - name: Audit translations
        run: dart run bin/language_revisor.dart --format=json > i18n_report.json

      - name: Fail if missing translations
        run: |
          MISSING=$(cat i18n_report.json | \
            python3 -c "import sys,json; print(json.load(sys.stdin)['by_type']['missing'])")
          echo "Missing translations: $MISSING"
          if [ "$MISSING" -gt "0" ]; then
            echo "❌ Found $MISSING missing translations. Run arb_pilot --auto to fix."
            exit 2
          fi

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
dart run bin/language_revisor.dart --format=json > /tmp/i18n_check.json 2>&1
MISSING=$(cat /tmp/i18n_check.json | python3 -c \
  "import sys,json; print(json.load(sys.stdin)['by_type']['missing'])" 2>/dev/null || echo "0")

if [ "$MISSING" -gt "0" ]; then
  echo "⚠️  arb_pilot: $MISSING missing translations. Run --auto to fix or --dry-run to preview."
fi
# Не блокируем коммит (exit 0), только предупреждаем
exit 0
```

```bash
chmod +x .git/hooks/pre-commit
```

---

## Переменные окружения

Удобны для CI — не нужно передавать ключи в аргументах командной строки.

```bash
export DEEPL_API_KEY="your-deepl-key:fx"
export GOOGLE_TRANSLATE_KEY="your-google-key"
export ARB_PILOT_ROOT="/path/to/project"   # альтернатива --root
export DEBUG=1                              # подробный вывод ошибок

dart run bin/language_revisor.dart --auto
```

В GitHub Actions — через Secrets:

```yaml
- name: Auto-translate
  env:
    DEEPL_API_KEY: ${{ secrets.DEEPL_API_KEY }}
  run: dart run bin/language_revisor.dart --auto
```
