# arb_pilot — Подключение провайдеров перевода

> Настройка DeepL, Google Translate, Yandex Translate, Ollama и добавление своего провайдера.

---

## Содержание

- [Как работает система провайдеров](#как-работает-система-провайдеров)
- [DeepL](#deepl)
- [Google Cloud Translation](#google-cloud-translation)
- [Yandex Translate](#yandex-translate)
- [Ollama — Локальный LLM](#ollama--локальный-llm)
- [Stub — Заглушка](#stub--заглушка)
- [Добавление своего провайдера](#добавление-своего-провайдера)
- [Сравнительная таблица](#сравнительная-таблица)

---

## Как работает система провайдеров

arb_pilot использует **fallback-цепочку** — если провайдер недоступен
или не поддерживает язык, автоматически берётся следующий:

```
DeepL → Google Translate → Yandex → Ollama → Stub
```

Цепочка строится в `translator/chain.dart` методом `TranslationChain.fromConfig()`.
Провайдеры добавляются только если передан соответствующий ключ.

Каждый провайдер реализует интерфейс из `translator/provider.dart`:

```dart
abstract class TranslationProvider {
  String get name;
  bool supportsLanguage(String langCode);
  Future<bool> isAvailable();
  Future<TranslationResult> translate(
    String text, {
    required String from,
    required String to,
    String? context,
  });
}
```

При запуске arb_pilot параллельно проверяет доступность всех провайдеров
и показывает статус перед переводом:

```
🔌 Провайдеры перевода
    ✓ DeepL Free
    ✓ Google Translate
    ✗ Yandex Translate
    ✗ Ollama (llama3)
    ✓ Stub
```

---

## DeepL

**Качество:** ★★★★★ — лучшее для EU/RU/ZH языков
**Языков:** 29
**Офлайн:** нет
**Бесплатный тариф:** 500 000 символов/месяц

### Поддерживаемые языки

`en ru zh es de fr it ja ko pt nl pl sv da fi cs ro hu tr uk bg hr sk sl lt lv et id nb`

> ⚠️ **Хинди (hi) не поддерживается.** Автоматически передаётся следующему провайдеру в цепочке.

### Получение ключа

1. Зайдите на [deepl.com/pro](https://www.deepl.com/pro)
2. Создайте аккаунт и выберите тариф **Free** или **Pro**
3. Перейдите в **Account → API Keys** и скопируйте ключ
4. Free ключи заканчиваются на `:fx`

### Подключение

```bash
# Через флаг
dart run bin/language_revisor.dart --auto --deepl-key=YOUR_KEY:fx

# Через переменную окружения (рекомендуется для CI)
export DEEPL_API_KEY="YOUR_KEY:fx"
dart run bin/language_revisor.dart --auto
```

arb_pilot автоматически определяет тариф по суффиксу:
- `:fx` → `https://api-free.deepl.com`
- без суффикса → `https://api.deepl.com`

### Проверка ключа

```bash
# Free
curl -X GET "https://api-free.deepl.com/v2/usage" \
  -H "Authorization: DeepL-Auth-Key YOUR_KEY:fx"

# Pro
curl -X GET "https://api.deepl.com/v2/usage" \
  -H "Authorization: DeepL-Auth-Key YOUR_KEY"
```

Ответ должен содержать `"character_count"` и `"character_limit"`.

### Особенности реализации

В `deepl_provider.dart` используются дополнительные параметры API:
- `tag_handling: xml` — сохраняет XML/HTML теги в строках
- `preserve_formatting: 1` — не меняет форматирование
- `context` — передаётся из `@i18n-context` аннотации для улучшения качества

Без `@i18n-context` перевод помечается `needsReview: true` и получает флаг в `.arb` файле.

---

## Google Cloud Translation

**Качество:** ★★★★ — хорошее, особенно для азиатских и редких языков
**Языков:** 130+ включая хинди, арабский, суахили, вьетнамский
**Офлайн:** нет
**Бесплатный тариф:** $300 кредитов при регистрации, затем $20 за 1M символов

### Получение ключа

1. Откройте [Google Cloud Console](https://console.cloud.google.com/)
2. Создайте проект
3. Перейдите в **APIs & Services → Library**
4. Найдите и включите **Cloud Translation API**
5. Перейдите в **APIs & Services → Credentials → Create Credentials → API Key**
6. Скопируйте ключ (начинается с `AIzaSy...`)

> 💡 Ограничьте ключ по API: Edit Key → API restrictions → Cloud Translation API

### Подключение

```bash
# Через флаг
dart run bin/language_revisor.dart --auto --google-key=AIzaSy...

# Через переменную окружения
export GOOGLE_TRANSLATE_KEY="AIzaSy..."
dart run bin/language_revisor.dart --auto
```

### Проверка ключа

```bash
curl "https://translation.googleapis.com/language/translate/v2?key=YOUR_KEY&q=Hello&target=ru"
# Ответ: {"data":{"translations":[{"translatedText":"Привет"}]}}
```

### Особенности реализации

В `google_provider.dart` автоматически декодируются HTML-сущности которые Google иногда возвращает:
`&amp;` → `&`, `&lt;` → `<`, `&gt;` → `>`, `&#39;` → `'` и т.д.

### Рекомендуемая комбинация

DeepL + Google — DeepL для европейских языков, Google для хинди и редких:

```bash
dart run bin/language_revisor.dart --auto \
  --deepl-key=YOUR_KEY:fx \
  --google-key=YOUR_GOOGLE_KEY
```

---

## Yandex Translate

**Качество:** ★★★★ — отличное для RU и постсоветских языков
**Языков:** 100+ включая KK, UZ, BE, UK, AZ, HY, KA
**Офлайн:** нет
**Бесплатный тариф:** грант при регистрации в Yandex Cloud

### Поддерживаемые языки

`ru en uk be kk az hy ka uz ky tg tk mn tt ba cv ce os de fr es it pt pl nl cs sv da fi no tr ar he fa zh ja ko vi id th ms ro hu bg hr sk sl et lv lt sr mk sq el mt`

### Получение ключа

1. Зайдите на [console.yandex.cloud](https://console.yandex.cloud/)
2. Создайте платёжный аккаунт (доступен бесплатный грант)
3. Перейдите в **Translate API** → создайте сервисный аккаунт
4. Создайте API-ключ → скопируйте (начинается с `AQVN...`)

### Подключение

```bash
# Через флаг
dart run bin/language_revisor.dart --auto --yandex-key=AQVNy...

# Через переменную окружения
export YANDEX_TRANSLATE_KEY="AQVNy..."
dart run bin/language_revisor.dart --auto
```

### Проверка ключа

```bash
curl -X POST "https://translate.api.cloud.yandex.net/translate/v2/translate" \
  -H "Authorization: Api-Key YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"texts":["Hello"],"targetLanguageCode":"ru","sourceLanguageCode":"en"}'
```

---

## Ollama — Локальный LLM

**Качество:** ★★★ — зависит от модели
**Языков:** все (LLM обучены на многоязычных данных)
**Офлайн:** ✅ полностью
**Стоимость:** бесплатно

### Установка Ollama

```bash
# macOS
brew install ollama

# Linux
curl -fsSL https://ollama.com/install.sh | sh

# Windows — скачайте с https://ollama.com/download
```

### Скачивание моделей

```bash
ollama serve          # запустить сервер

# Рекомендуемые модели для перевода
ollama pull llama3    # 4.7 GB — лучшее качество
ollama pull mistral   # 4.1 GB — быстрее, меньше памяти
ollama pull gemma2    # 5.4 GB — хорошее качество от Google
ollama pull phi3      # 2.4 GB — минимальные требования
```

### Подключение

```bash
# Стандартный запуск
dart run bin/language_revisor.dart --auto --ollama-model=llama3

# Свой хост (удалённый сервер)
dart run bin/language_revisor.dart --auto \
  --ollama-model=mistral \
  --ollama-host=http://192.168.1.100:11434

# Через переменные окружения
export OLLAMA_MODEL=llama3
export OLLAMA_HOST=http://localhost:11434
dart run bin/language_revisor.dart --auto
```

### Требования к RAM

| Модель | RAM | Качество перевода |
|---|---|---|
| `phi3` | 4 GB | Базовое |
| `mistral` | 8 GB | Хорошее |
| `llama3` | 8 GB | Отличное |
| `gemma2` | 12 GB | Отличное |
| `llama3:70b` | 48 GB | Максимальное |

### Проверка доступности

```bash
# Проверить что Ollama запущен и модель есть
curl http://localhost:11434/api/tags

# Тестовый перевод
curl http://localhost:11434/api/generate -d '{
  "model": "llama3",
  "prompt": "Translate to Russian, return ONLY the translation: Create item",
  "stream": false
}'
```

### Как работает промпт

В `llm_provider.dart` используется структурированный промпт с низкой температурой (0.1):

```
You are a professional UI translator.
Translate the following UI string from English to Russian.

Context: Button label in the main list view

Rules:
- Return ONLY the translated text, nothing else
- Do NOT add quotes, explanations, or notes
- Preserve any {placeholders} exactly as-is
- Keep the same tone as the original

Text to translate:
Create item
```

Ответ автоматически очищается от кавычек, markdown-блоков и лишних пояснений.

---

## Stub — Заглушка

Активируется автоматически если ни один другой провайдер не доступен.
Создаёт записи с маркером для ручного перевода:

```json
{
  "createItem": "⚠️ NEEDS_REVIEW: Create item",
  "@createItem": {
    "description": "Auto-translated by Stub. NEEDS REVIEW.",
    "x-needs-review": true,
    "x-source": "Create item"
  }
}
```

Найти все строки требующие ревью:

```bash
grep -r "NEEDS_REVIEW" lib/*/l10n/ packages/*/lib/l10n/
```

arb_pilot в аудите отдельно считает и показывает такие строки:

```
Требуют ревью (NEEDS_REVIEW)              5   ←
```

---

## Добавление своего провайдера

### Шаг 1 — Создайте файл провайдера

`lib/tools/i18n/translator/my_provider.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'provider.dart';

class MyTranslationProvider implements TranslationProvider {
  final String apiKey;

  MyTranslationProvider({required this.apiKey});

  @override
  String get name => 'My Provider';

  @override
  bool supportsLanguage(String langCode) {
    const supported = {'en', 'ru', 'zh', 'de', 'fr', 'es'};
    return supported.contains(langCode.toLowerCase());
  }

  @override
  Future<bool> isAvailable() async {
    if (apiKey.isEmpty) return false;
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(
        Uri.parse('https://api.example.com/ping'),
      );
      req.headers.set('Authorization', 'Bearer $apiKey');
      final res = await req.close();
      await res.drain<void>();
      client.close();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<TranslationResult> translate(
    String text, {
    required String from,
    required String to,
    String? context,
  }) async {
    final body = jsonEncode({
      'text':    text,
      'source':  from,
      'target':  to,
      if (context != null) 'context': context,
    });

    final client = HttpClient();
    try {
      final req = await client.postUrl(
        Uri.parse('https://api.example.com/translate'),
      );
      req.headers.set('Authorization', 'Bearer $apiKey');
      req.headers.contentType = ContentType.json;
      req.write(body);

      final res = await req.close();
      final raw = await res.transform(utf8.decoder).join();

      if (res.statusCode != 200) {
        throw Exception('MyProvider ${res.statusCode}: $raw');
      }

      final data = jsonDecode(raw) as Map<String, dynamic>;

      return TranslationResult(
        text:        data['translation'] as String,
        provider:    name,
        needsReview: context == null,
      );
    } finally {
      client.close();
    }
  }
}
```

### Шаг 2 — Зарегистрируйте в chain.dart

Откройте `lib/tools/i18n/translator/chain.dart` и добавьте:

```dart
import 'my_provider.dart';

// В методе TranslationChain.fromConfig() — перед StubProvider:
final myKey = config.myProviderKey; // добавьте поле в ArbPilotConfig
if (myKey != null) {
  providers.add(MyTranslationProvider(apiKey: myKey));
}
```

### Шаг 3 — Добавьте поле в config.dart

```dart
// В классе ArbPilotConfig:
final String? myProviderKey;

// В factory ArbPilotConfig.fromArgs():
final myKey = _argValue(args, '--my-provider-key') ??
    Platform.environment['MY_PROVIDER_KEY'];
```

### Шаг 4 — Использование

```bash
export MY_PROVIDER_KEY="your-key"
dart run bin/language_revisor.dart --auto
```

---

## Сравнительная таблица

| Провайдер | Языков | Хинди | Офлайн | Бесплатно | Качество |
|---|---|---|---|---|---|
| **DeepL** | 29 | ❌ | ❌ | 500K символов/мес | ★★★★★ |
| **Google Translate** | 130+ | ✅ | ❌ | $300 кредит | ★★★★ |
| **Yandex Translate** | 100+ | ❌ | ❌ | Грант | ★★★★ |
| **Ollama** | Все | ✅ | ✅ | Бесплатно | ★★★ |
| **Stub** | Все | ✅ | ✅ | Бесплатно | — |

### Рекомендуемые комбинации

**Максимальное качество:**
```bash
dart run bin/language_revisor.dart --auto \
  --deepl-key=KEY:fx \
  --google-key=KEY
```

**Максимальное покрытие + офлайн фоллбэк:**
```bash
dart run bin/language_revisor.dart --auto \
  --deepl-key=KEY:fx \
  --google-key=KEY \
  --yandex-key=KEY \
  --ollama-model=llama3
```

**Полностью офлайн:**
```bash
dart run bin/language_revisor.dart --auto --ollama-model=llama3
```

**Разработка без ключей (Stub создаст NEEDS_REVIEW):**
```bash
dart run bin/language_revisor.dart --auto
```
