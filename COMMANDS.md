# arb_pilot — Справочник команд

> Полный список команд, флагов и примеров использования.

---

## Содержание

- [Базовый синтаксис](#базовый-синтаксис)
- [Режимы работы](#режимы-работы)
- [Флаги провайдеров](#флаги-провайдеров)
- [Фильтры](#фильтры)
- [Параметры вывода](#параметры-вывода)
- [Переменные окружения](#переменные-окружения)
- [Коды выхода](#коды-выхода)
- [Примеры — рабочие сценарии](#примеры--рабочие-сценарии)

---

## Базовый синтаксис

```bash
dart run bin/language_revisor.dart [флаги]
```

Если arb_pilot находится рядом с проектом (вариант standalone):

```bash
dart run bin/language_revisor.dart --root=/path/to/your_project [флаги]
```

---

## Режимы работы

### Аудит (по умолчанию)

Только читает — ничего не изменяет. Безопасно запускать в любое время.

```bash
dart run bin/language_revisor.dart
```

Показывает:
- сколько Dart-файлов просканировано
- сколько `.arb` файлов найдено
- сколько ключей используется в коде
- отсутствующие переводы (missing)
- устаревшие ключи (orphaned)
- пустые значения (empty)
- строки, требующие ревью (NEEDS_REVIEW)

---

### `--auto` — Автоперевод

Переводит все найденные пробелы без подтверждений.

```bash
dart run bin/language_revisor.dart --auto --deepl-key=YOUR_KEY
```

Порядок попытки провайдеров:

```
DeepL → Google Translate → Ollama → Stub (⚠️ NEEDS_REVIEW)
```

Если провайдер недоступен или не поддерживает язык — автоматически используется следующий.

---

### `--interactive` — Интерактивный режим

Показывает каждый перевод и спрашивает подтверждение перед записью.

```bash
dart run bin/language_revisor.dart --interactive
```

```
  [ru] createNode → "Создать узел" (DeepL Free)
  Записать? [y/N]: y

  [zh] createNode → "创建节点" (DeepL Free)
  Записать? [y/N]: n   ← пропустить
```

---

### `--dry-run` — Предварительный просмотр

Показывает план — что будет переведено и каким провайдером — без записи в файлы.

```bash
dart run bin/language_revisor.dart --auto --dry-run
dart run bin/language_revisor.dart --auto --deepl-key=KEY --dry-run
```

Полезно перед первым запуском, чтобы убедиться, что всё настроено правильно.

---

### `--remove-orphaned` — Удаление устаревших ключей

Удаляет из `.arb` файлов ключи, которых больше нет в Dart-коде.

```bash
# Удаление с подтверждением каждого ключа
dart run bin/language_revisor.dart --interactive --remove-orphaned

# Удаление без подтверждений (осторожно!)
dart run bin/language_revisor.dart --auto --remove-orphaned
```

> ⚠️ Перед использованием без `--interactive` убедитесь, что аудит показывает
> именно те ключи, которые вы хотите удалить.

---

## Флаги провайдеров

### `--deepl-key=KEY`

DeepL API ключ. Поддерживает Free и Pro тарифы.

```bash
dart run bin/language_revisor.dart --auto --deepl-key=abc123:fx    # Free
dart run bin/language_revisor.dart --auto --deepl-key=abc123       # Pro
```

Free ключи заканчиваются на `:fx` — arb_pilot определяет это автоматически
и использует правильный endpoint (`api-free.deepl.com` vs `api.deepl.com`).

Альтернатива — переменная окружения `DEEPL_API_KEY`.

Поддерживаемые языки: EN, RU, ZH, ES, DE, FR, IT, JA, KO, PT, NL, PL и другие (29 языков).
**Хинди (HI) не поддерживается** — автоматически передаётся в Google или Ollama.

---

### `--google-key=KEY`

Google Cloud Translation API ключ. Покрывает 130+ языков включая хинди, арабский, суахили и др.

```bash
dart run bin/language_revisor.dart --auto --google-key=AIzaSy...
```

Получить ключ: [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Cloud Translation API.

Альтернатива — переменная окружения `GOOGLE_TRANSLATE_KEY`.

---

### `--ollama-model=NAME`

Локальная LLM через Ollama. Работает полностью офлайн, API ключи не нужны.

```bash
# llama3 (рекомендуется для качества)
dart run bin/language_revisor.dart --auto --ollama-model=llama3

# mistral (быстрее, меньше памяти)
dart run bin/language_revisor.dart --auto --ollama-model=mistral

# gemma2 (от Google, хорошее качество)
dart run bin/language_revisor.dart --auto --ollama-model=gemma2
```

По умолчанию модель: `llama3`.

---

### `--ollama-host=URL`

Хост Ollama, если он запущен не на localhost.

```bash
dart run bin/language_revisor.dart --auto \
  --ollama-model=llama3 \
  --ollama-host=http://192.168.1.100:11434
```

По умолчанию: `http://localhost:11434`.

---

### Комбинирование провайдеров

Рекомендуемая комбинация — DeepL для европейских языков, Google для остальных:

```bash
dart run bin/language_revisor.dart --auto \
  --deepl-key=YOUR_DEEPL_KEY:fx \
  --google-key=YOUR_GOOGLE_KEY
```

Fallback-цепочка в этом случае:
- DeepL — если язык поддерживается и ключ валиден
- Google — для языков не поддерживаемых DeepL (хинди и др.) или при ошибке DeepL
- Ollama — если Google недоступен (нет ключа)
- Stub — последний резерв, пишет `⚠️ NEEDS_REVIEW: текст`

---

## Фильтры

### `--source-lang=CODE`

Переопределить исходный язык (по умолчанию `en` или из `arb_pilot.yaml`).

```bash
# Если исходный язык — русский
dart run bin/language_revisor.dart --auto --source-lang=ru
```

---

### `--langs=CODE,CODE,...`

Переводить только для указанных языков.

```bash
# Только русский и китайский
dart run bin/language_revisor.dart --auto --langs=ru,zh --deepl-key=KEY

# Только хинди через Google
dart run bin/language_revisor.dart --auto --langs=hi --google-key=KEY
```

---

### `--root=PATH`

Корень проекта. По умолчанию — текущая директория.

```bash
# Если arb_pilot рядом с проектом
dart run bin/language_revisor.dart --root=../my_flutter_app

# Абсолютный путь
dart run bin/language_revisor.dart --root=/Users/dev/projects/my_app
```

---

## Параметры вывода

### `--format=json`

Вывод в JSON — для CI/CD пайплайнов, скриптов, интеграций.

```bash
dart run bin/language_revisor.dart --format=json > report.json
dart run bin/language_revisor.dart --format=json | jq '.by_type'
```

Пример выходного JSON:

```json
{
  "generated_at": "2026-05-01T12:00:00.000Z",
  "total_issues": 15,
  "by_type": {
    "missing": 12,
    "orphaned": 3,
    "empty": 0,
    "needs_review": 0
  },
  "by_language": {
    "ru": {
      "missing_count": 4,
      "missing_keys": ["createNode", "deleteItem", "archiveAll", "exportPdf"],
      "coverage": 0.95
    },
    "zh": {
      "missing_count": 8,
      "missing_keys": ["createNode", "deleteItem", "..."],
      "coverage": 0.90
    }
  }
}
```

---

### `--no-color`

Отключить ANSI-цвета в выводе. Полезно для Windows CMD и логов CI.

```bash
dart run bin/language_revisor.dart --no-color
```

---

### `--help`

Показать справку по всем флагам.

```bash
dart run bin/language_revisor.dart --help
```

---

## Переменные окружения

Альтернативный способ передачи настроек — удобен для CI/CD (не светить ключи в логах команд).

| Переменная | Аналог флага | Описание |
|---|---|---|
| `DEEPL_API_KEY` | `--deepl-key` | DeepL API ключ |
| `GOOGLE_TRANSLATE_KEY` | `--google-key` | Google Translate ключ |
| `ARB_PILOT_ROOT` | `--root` | Путь к корню проекта |
| `DEBUG=1` | — | Показывать полный стек ошибок |

```bash
# Пример использования env переменных
export DEEPL_API_KEY="abc123:fx"
export GOOGLE_TRANSLATE_KEY="AIzaSy..."
dart run bin/language_revisor.dart --auto
```

---

## Коды выхода

| Код | Значение | Когда |
|---|---|---|
| `0` | Успех | Всё в порядке, или перевод завершён без ошибок |
| `1` | Ошибка | Сетевая ошибка, неверный API ключ, битый `.arb` файл |
| `2` | Найдены проблемы | Аудит завершён, есть missing/orphaned ключи |

Код `2` — не ошибка, это штатная ситуация для git hooks и CI.

```bash
dart run bin/language_revisor.dart
echo $?   # 0 если всё чисто, 2 если есть проблемы
```

```yaml
# В GitHub Actions можно разрешить код 2 (аудит с проблемами)
- name: Audit
  run: dart run bin/language_revisor.dart
  continue-on-error: false   # Изменить на true если не хотите блокировать PR
```

---

## Примеры — рабочие сценарии

### Первая проверка проекта (ничего не меняет)

```bash
dart run bin/language_revisor.dart
```

---

### Перевести через DeepL, посмотреть план

```bash
dart run bin/language_revisor.dart --auto --deepl-key=KEY --dry-run
```

---

### Полноценный автоперевод с двумя провайдерами

```bash
dart run bin/language_revisor.dart --auto \
  --deepl-key=abc123:fx \
  --google-key=AIzaSy...
```

---

### Только русский и китайский, интерактивно

```bash
dart run bin/language_revisor.dart \
  --interactive \
  --langs=ru,zh \
  --deepl-key=KEY
```

---

### Перевести офлайн через Ollama

```bash
# Сначала запустить Ollama и скачать модель
ollama serve &
ollama pull mistral

# Перевести
dart run bin/language_revisor.dart --auto --ollama-model=mistral
```

---

### Очистить устаревшие ключи интерактивно

```bash
dart run bin/language_revisor.dart --interactive --remove-orphaned
```

---

### JSON-отчёт для CI

```bash
dart run bin/language_revisor.dart --format=json --no-color > i18n_report.json
```

---

### Через переменные окружения (безопасно в CI)

```bash
DEEPL_API_KEY=abc123:fx \
GOOGLE_TRANSLATE_KEY=AIzaSy... \
dart run bin/language_revisor.dart --auto
```

---

### Аудит конкретного пакета в монорепозитории

```bash
dart run bin/language_revisor.dart --root=./packages/ui_kit
```

---

### Полный pipeline: аудит → перевод → проверка → удаление orphaned

```bash
#!/bin/bash
set -e

echo "=== 1. Аудит ==="
dart run bin/language_revisor.dart

echo "=== 2. Перевод ==="
dart run bin/language_revisor.dart --auto \
  --deepl-key=$DEEPL_API_KEY \
  --google-key=$GOOGLE_KEY

echo "=== 3. Проверка результата ==="
dart run bin/language_revisor.dart --format=json > report.json
MISSING=$(python3 -c "import json,sys; print(json.load(sys.stdin)['by_type']['missing'])" < report.json)
echo "Missing: $MISSING"

echo "=== 4. Удаление orphaned ==="
dart run bin/language_revisor.dart --auto --remove-orphaned

echo "=== Готово ==="
```

---

## Таблица всех флагов

| Флаг | Значение по умолчанию | Описание |
|---|---|---|
| `--auto` | — | Автоперевод без подтверждений |
| `--interactive` | — | Подтверждение каждого действия |
| `--dry-run` | — | Показать план без изменений |
| `--deepl-key=KEY` | `$DEEPL_API_KEY` | DeepL API ключ |
| `--google-key=KEY` | `$GOOGLE_TRANSLATE_KEY` | Google Translate ключ |
| `--ollama-host=URL` | `http://localhost:11434` | Хост Ollama |
| `--ollama-model=NAME` | `llama3` | Модель Ollama |
| `--source-lang=CODE` | `en` (из конфига) | Исходный язык |
| `--langs=a,b,c` | из конфига | Целевые языки (через запятую) |
| `--root=PATH` | текущая директория | Корень проекта |
| `--remove-orphaned` | — | Удалить устаревшие ключи |
| `--format=json` | — | JSON вывод для CI/CD |
| `--no-color` | — | Без ANSI цветов |
| `--help` | — | Справка |
