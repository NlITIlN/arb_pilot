# arb_pilot — Справочник команд

> Полный список команд, флагов и примеров. Основан на реальном коде `bin/language_revisor.dart`.

---

## Содержание

- [Базовый синтаксис](#базовый-синтаксис)
- [Режимы работы](#режимы-работы)
- [Флаги провайдеров](#флаги-провайдеров)
- [Фильтры и пути](#фильтры-и-пути)
- [Вывод и отладка](#вывод-и-отладка)
- [Переменные окружения](#переменные-окружения)
- [Коды выхода](#коды-выхода)
- [Примеры — рабочие сценарии](#примеры--рабочие-сценарии)
- [Таблица всех флагов](#таблица-всех-флагов)

---

## Базовый синтаксис

```bash
dart run bin/language_revisor.dart [флаги]
```

Если arb_pilot лежит рядом с проектом (standalone):

```bash
dart run bin/language_revisor.dart --root=../my_flutter_app [флаги]
```

Быстрая справка прямо в терминале:

```bash
dart run bin/language_revisor.dart --help
```

---

## Режимы работы

### Без флагов — Аудит (read-only)

Безопасно запускать в любое время. Ничего не изменяет, только анализирует.

```bash
dart run bin/language_revisor.dart
```

Что показывает:
- сколько Dart-файлов просканировано
- сколько `.arb` файлов найдено и по каким модулям
- сколько уникальных ключей используется в коде
- сколько ключей имеют `@i18n-context` аннотации
- отсутствующие переводы (missing)
- устаревшие ключи (orphaned — есть в `.arb`, нет в коде)
- пустые значения и `NEEDS_REVIEW` маркеры
- проблемы качества (placeholder mismatch, слишком длинные строки)

---

### `--auto` — Автоперевод

Переводит все найденные пробелы без подтверждений. Пишет результаты в `.arb` файлы.

```bash
dart run bin/language_revisor.dart --auto
```

Порядок попытки провайдеров (fallback-цепочка):

```
DeepL → Google Translate → Yandex → Ollama → Stub (⚠️ NEEDS_REVIEW)
```

Если провайдер недоступен или не поддерживает язык — следующий подхватывает автоматически.

---

### `--interactive` — Интерактивный режим

Показывает каждый перевод и ждёт подтверждения перед записью.

```bash
dart run bin/language_revisor.dart --interactive
```

Пример диалога:

```
  Перевести [ru] createNode = "Create node"? [Y/n]: y
  Перевести [zh] createNode = "Create node"? [Y/n]: n  ← пропустить
  Перевести [hi] deleteItem = "Delete"? [Y/n]: y
```

---

### `--dry-run` — Предпросмотр без изменений

Показывает что будет переведено и каким провайдером — без записи в файлы.

```bash
dart run bin/language_revisor.dart --auto --dry-run
dart run bin/language_revisor.dart --auto --deepl-key=KEY --dry-run
```

Все строки выводятся с пометкой `[dry-run]`. Полезно перед первым запуском.

---

### `--remove-orphaned` — Удаление устаревших ключей

Удаляет из `.arb` файлов ключи, которых больше нет в Dart-коде.

```bash
# С подтверждением по каждому файлу
dart run bin/language_revisor.dart --interactive --remove-orphaned

# Без подтверждений (осторожно!)
dart run bin/language_revisor.dart --auto --remove-orphaned

# Посмотреть что будет удалено — без удаления
dart run bin/language_revisor.dart --auto --remove-orphaned --dry-run
```

---

## Флаги провайдеров

### `--deepl-key=KEY`

DeepL API ключ. Лучшее качество для EN/RU/DE/FR/ZH/ES и других европейских языков.

```bash
dart run bin/language_revisor.dart --auto --deepl-key=abc123:fx    # Free тариф
dart run bin/language_revisor.dart --auto --deepl-key=abc123       # Pro тариф
```

Free ключи заканчиваются на `:fx` — arb_pilot определяет это автоматически и использует правильный endpoint.

**Не поддерживает:** хинди (hi) — автоматически передаётся следующему провайдеру.

Альтернатива: переменная окружения `DEEPL_API_KEY`.

---

### `--google-key=KEY`

Google Cloud Translation API ключ. 130+ языков включая хинди, арабский, суахили.

```bash
dart run bin/language_revisor.dart --auto --google-key=AIzaSy...
```

Получить ключ: [Google Cloud Console](https://console.cloud.google.com/) → APIs → Cloud Translation API → Credentials.

Альтернатива: переменная окружения `GOOGLE_TRANSLATE_KEY`.

---

### `--yandex-key=KEY`

Yandex Cloud Translate ключ. Отличное качество для русского и постсоветских языков.

```bash
dart run bin/language_revisor.dart --auto --yandex-key=AQVNy...
```

Получить ключ: [Yandex Cloud Console](https://console.yandex.cloud/) → Translate API.

Альтернатива: переменная окружения `YANDEX_TRANSLATE_KEY`.

---

### `--ollama-model=NAME`

Локальный LLM через Ollama. Полностью офлайн, API ключи не нужны.

```bash
dart run bin/language_revisor.dart --auto --ollama-model=llama3
dart run bin/language_revisor.dart --auto --ollama-model=mistral
dart run bin/language_revisor.dart --auto --ollama-model=gemma2
dart run bin/language_revisor.dart --auto --ollama-model=phi3
```

По умолчанию: `llama3`.

Перед запуском Ollama должен быть запущен и модель скачана:

```bash
ollama serve
ollama pull llama3
```

---

### `--ollama-host=URL`

Хост Ollama если он запущен не на localhost.

```bash
dart run bin/language_revisor.dart --auto \
  --ollama-model=llama3 \
  --ollama-host=http://192.168.1.100:11434
```

По умолчанию: `http://localhost:11434`.

Альтернатива: переменная окружения `OLLAMA_HOST`.

---

### Комбинирование провайдеров

Рекомендуемая комбинация — DeepL для европейских языков, Google для остальных:

```bash
dart run bin/language_revisor.dart --auto \
  --deepl-key=YOUR_DEEPL_KEY:fx \
  --google-key=YOUR_GOOGLE_KEY
```

Максимальное покрытие + офлайн фоллбэк:

```bash
dart run bin/language_revisor.dart --auto \
  --deepl-key=KEY:fx \
  --google-key=KEY \
  --ollama-model=llama3
```

---

## Фильтры и пути

### `--source-lang=CODE`

Переопределить исходный язык (по умолчанию `en` или из `arb_pilot.yaml`).

```bash
dart run bin/language_revisor.dart --auto --source-lang=ru
```

---

### `--langs=CODE,CODE,...`

Переводить только для указанных языков через запятую.

```bash
# Только русский и китайский
dart run bin/language_revisor.dart --auto --langs=ru,zh --deepl-key=KEY

# Только хинди через Google
dart run bin/language_revisor.dart --auto --langs=hi --google-key=KEY

# Один язык для теста
dart run bin/language_revisor.dart --auto --langs=de --deepl-key=KEY --dry-run
```

---

### `--root=PATH`

Путь к корню проекта. По умолчанию — текущая директория.

```bash
# Относительный путь
dart run bin/language_revisor.dart --root=../my_flutter_app

# Абсолютный путь
dart run bin/language_revisor.dart --root=/Users/dev/projects/my_app

# Конкретный пакет в монорепозитории
dart run bin/language_revisor.dart --root=./packages/ui_kit
```

Альтернатива: переменная окружения `ARB_PILOT_ROOT`.

---

## Вывод и отладка

### `--format=json`

JSON-отчёт для CI/CD пайплайнов и скриптов.

```bash
dart run bin/language_revisor.dart --format=json
dart run bin/language_revisor.dart --format=json > report.json
dart run bin/language_revisor.dart --format=json | jq '.by_type'
```

Формат JSON-отчёта:

```json
{
  "generated_at": "2026-05-14T12:00:00.000Z",
  "total_issues": 15,
  "by_type": {
    "missing": 12,
    "orphaned": 3,
    "empty": 0,
    "needs_review": 0,
    "quality": 2
  },
  "orphaned_keys": [
    { "key": "oldButton", "module": "core", "locale": "ru" }
  ],
  "by_language": {
    "ru": {
      "missing_count": 4,
      "missing_keys": ["createNode", "deleteItem", "archiveAll", "exportPdf"],
      "coverage": 0.9524
    },
    "zh": {
      "missing_count": 8,
      "missing_keys": ["createNode", "..."],
      "coverage": 0.9048
    }
  }
}
```

При `--format=json` весь остальной вывод подавляется — только JSON в stdout.

---

### `--no-color`

Отключить ANSI-цвета. Полезно для Windows CMD и CI-логов.

```bash
dart run bin/language_revisor.dart --no-color
dart run bin/language_revisor.dart --format=json --no-color > report.json
```

arb_pilot автоматически отключает цвета если задана переменная `NO_COLOR`,
`TERM=dumb`, или вывод идёт не в терминал (pipe).

---

### `--debug`

Подробный вывод: стек ошибок, какой провайдер упал и почему.

```bash
dart run bin/language_revisor.dart --auto --deepl-key=KEY --debug
```

Альтернатива: переменная окружения `DEBUG=1`.

---

### `--help` / `-h`

Справка по всем флагам прямо в терминале.

```bash
dart run bin/language_revisor.dart --help
```

---

## Переменные окружения

Удобны для CI/CD — ключи не светятся в логах команд.

| Переменная | Аналог флага | Описание |
|---|---|---|
| `DEEPL_API_KEY` | `--deepl-key` | DeepL API ключ |
| `GOOGLE_TRANSLATE_KEY` | `--google-key` | Google Translate ключ |
| `YANDEX_TRANSLATE_KEY` | `--yandex-key` | Yandex Translate ключ |
| `OLLAMA_MODEL` | `--ollama-model` | Ollama модель |
| `OLLAMA_HOST` | `--ollama-host` | Ollama хост |
| `ARB_PILOT_ROOT` | `--root` | Корень проекта |
| `NO_COLOR` | `--no-color` | Отключить ANSI цвета |
| `DEBUG=1` | `--debug` | Подробный вывод ошибок |

```bash
export DEEPL_API_KEY="abc123:fx"
export GOOGLE_TRANSLATE_KEY="AIzaSy..."
export YANDEX_TRANSLATE_KEY="AQVNy..."
dart run bin/language_revisor.dart --auto
```

В GitHub Actions через Secrets:

```yaml
- name: Auto-translate
  env:
    DEEPL_API_KEY: ${{ secrets.DEEPL_API_KEY }}
    GOOGLE_TRANSLATE_KEY: ${{ secrets.GOOGLE_TRANSLATE_KEY }}
  run: dart run bin/language_revisor.dart --auto --no-color
```

---

## Коды выхода

| Код | Значение | Когда |
|---|---|---|
| `0` | Успех | Всё синхронизировано, или перевод завершён без ошибок |
| `1` | Ошибка | Сетевая ошибка, неверный API ключ, битый `.arb` файл |
| `2` | Найдены проблемы | Аудит завершён, есть missing или orphaned ключи |

Код `2` — не ошибка, это штатная ситуация для git hooks и CI.

```bash
dart run bin/language_revisor.dart
echo "Exit code: $?"   # 0 если чисто, 2 если есть проблемы
```

---

## Примеры — рабочие сценарии

### Первая проверка нового проекта

```bash
dart run bin/language_revisor.dart
```

---

### Посмотреть план перевода без изменений

```bash
dart run bin/language_revisor.dart --auto --deepl-key=KEY --dry-run
```

---

### Перевести всё через DeepL

```bash
dart run bin/language_revisor.dart --auto --deepl-key=abc123:fx
```

---

### DeepL + Google (рекомендуемая комбинация)

```bash
dart run bin/language_revisor.dart --auto \
  --deepl-key=abc123:fx \
  --google-key=AIzaSy...
```

---

### Только хинди через Google

```bash
dart run bin/language_revisor.dart --auto \
  --langs=hi \
  --google-key=AIzaSy...
```

---

### Полностью офлайн через Ollama

```bash
ollama serve &
ollama pull mistral
dart run bin/language_revisor.dart --auto --ollama-model=mistral
```

---

### Интерактивно — только русский и китайский

```bash
dart run bin/language_revisor.dart --interactive --langs=ru,zh --deepl-key=KEY
```

---

### Очистить устаревшие ключи с подтверждением

```bash
dart run bin/language_revisor.dart --interactive --remove-orphaned
```

---

### JSON-отчёт для CI

```bash
dart run bin/language_revisor.dart --format=json --no-color > i18n_report.json
cat i18n_report.json | jq '.by_type'
```

---

### Аудит конкретного пакета в монорепозитории

```bash
dart run bin/language_revisor.dart --root=./packages/ui_kit
```

---

### Полный скрипт: аудит → перевод → очистка

```bash
#!/bin/bash
set -e

echo "=== 1. Аудит ==="
dart run bin/language_revisor.dart || true

echo "=== 2. Перевод ==="
dart run bin/language_revisor.dart --auto \
  --deepl-key="$DEEPL_API_KEY" \
  --google-key="$GOOGLE_TRANSLATE_KEY"

echo "=== 3. Удаление устаревших ключей ==="
dart run bin/language_revisor.dart --auto --remove-orphaned

echo "=== 4. Итоговый отчёт ==="
dart run bin/language_revisor.dart --format=json --no-color > i18n_report.json
python3 -c "
import json
r = json.load(open('i18n_report.json'))
print(f'Missing:  {r[\"by_type\"][\"missing\"]}')
print(f'Orphaned: {r[\"by_type\"][\"orphaned\"]}')
"
echo "=== Готово ==="
```

---

### GitHub Actions — полный пример

```yaml
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

      - name: Audit translations
        run: |
          dart run bin/language_revisor.dart \
            --format=json --no-color > i18n_report.json
        continue-on-error: true

      - name: Auto-translate missing
        if: github.ref == 'refs/heads/main'
        env:
          DEEPL_API_KEY: ${{ secrets.DEEPL_API_KEY }}
          GOOGLE_TRANSLATE_KEY: ${{ secrets.GOOGLE_TRANSLATE_KEY }}
        run: |
          dart run bin/language_revisor.dart --auto --no-color

      - name: Commit updated translations
        if: github.ref == 'refs/heads/main'
        run: |
          git config user.name "arb_pilot"
          git config user.email "bot@arb-pilot.dev"
          git add "lib/**/l10n/*.arb" "packages/**/l10n/*.arb" || true
          git diff --staged --quiet || \
            git commit -m "chore: auto-translate missing strings [skip ci]"
          git push || true

      - name: Upload i18n report
        uses: actions/upload-artifact@v4
        with:
          name: i18n-report
          path: i18n_report.json
```

---

## Таблица всех флагов

| Флаг | Тип | Default | Описание |
|---|---|---|---|
| `--auto` | bool | false | Автоперевод без подтверждений |
| `--interactive` | bool | false | Подтверждение каждого шага |
| `--dry-run` | bool | false | Показать план без изменений |
| `--remove-orphaned` | bool | false | Удалить устаревшие ключи |
| `--deepl-key=KEY` | string | `$DEEPL_API_KEY` | DeepL API ключ |
| `--google-key=KEY` | string | `$GOOGLE_TRANSLATE_KEY` | Google Translate ключ |
| `--yandex-key=KEY` | string | `$YANDEX_TRANSLATE_KEY` | Yandex Translate ключ |
| `--ollama-model=NAME` | string | `llama3` | Ollama модель |
| `--ollama-host=URL` | string | `http://localhost:11434` | Ollama хост |
| `--source-lang=CODE` | string | `en` (из конфига) | Исходный язык |
| `--langs=a,b,c` | string | из конфига | Целевые языки через запятую |
| `--root=PATH` | string | текущая директория | Корень проекта |
| `--format=json` | string | — | JSON вывод для CI/CD |
| `--no-color` | bool | false | Без ANSI цветов |
| `--debug` | bool | false | Подробный вывод ошибок |
| `--help` / `-h` | bool | false | Показать справку |
