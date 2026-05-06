# arb_pilot — Подключение провайдеров перевода

> Подробное руководство по настройке каждого провайдера: DeepL, Google Translate, Yandex Translate, Ollama (локальный LLM), а также по добавлению собственного провайдера.

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

arb_pilot использует **fallback-цепочку**: если первый провайдер недоступен или не поддерживает язык — автоматически используется следующий.

```
DeepL → Google Translate → Yandex → Ollama → Stub
```

Цепочка конфигурируется в `lib/tools/i18n/translator/chain.dart`.
Каждый провайдер реализует интерфейс `TranslationProvider`:

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

Чтобы добавить провайдер — реализуйте этот интерфейс и зарегистрируйте его в `TranslationChain.fromConfig()`.

---

## DeepL

**Качество:** ★★★★★ — лучшее для европейских языков и русского  
**Языков:** 29  
**Офлайн:** нет  
**Бесплатный тариф:** да (500 000 символов/месяц)

### Поддерживаемые языки

EN, RU, ZH, ES, DE, FR, IT, JA, KO, PT, NL, PL, SV, DA, FI, CS, RO, HU, TR, UK, BG, HR, SK, SL, LT, LV, ET

> ⚠️ **Хинди (HI) не поддерживается DeepL.** Для хинди используйте Google Translate или Ollama.

### Получение API ключа

1. Зайдите на [deepl.com/pro](https://www.deepl.com/pro) и создайте аккаунт
2. Выберите тариф **Free** (бесплатно) или **Pro**
3. В разделе **Account → API Keys** скопируйте ключ
4. Free ключи заканчиваются на `:fx` — это важно

### Настройка

```bash
# Через флаг
dart run bin/language_revisor.dart --auto --deepl-key=YOUR_KEY:fx

# Через переменную окружения (рекомендуется)
export DEEPL_API_KEY="YOUR_KEY:fx"
dart run bin/language_revisor.dart --auto
```

arb_pilot автоматически определяет тариф по суффиксу `:fx`:
- Free → использует `https://api-free.deepl.com`
- Pro → использует `https://api.deepl.com`

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

### Советы

- Добавляйте `@i18n-context` аннотации в код — DeepL использует поле `context` в API запросе для улучшения качества
- Без контекста переводы помечаются `needsReview: true` и получают флаг в `.arb` файле
- DeepL поддерживает **batch запросы** — несколько строк за один HTTP вызов (реализовано в `deepl_provider.dart`)

---

## Google Cloud Translation

**Качество:** ★★★★ — хорошее, особенно для азиатских и редких языков  
**Языков:** 130+ включая хинди, арабский, суахили, вьетнамский  
**Офлайн:** нет  
**Бесплатный тариф:** $300 кредитов при регистрации, затем $20 за 1M символов

### Получение API ключа

1. Откройте [Google Cloud Console](https://console.cloud.google.com/)
2. Создайте проект (или выберите существующий)
3. Перейдите в **APIs & Services → Library**
4. Найдите и включите **Cloud Translation API**
5. Перейдите в **APIs & Services → Credentials**
6. Нажмите **Create Credentials → API Key**
7. Скопируйте ключ

> 💡 Для ограничения доступа — нажмите **Edit Key** и добавьте ограничение по API (только Cloud Translation API).

### Настройка

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
```

Ответ: `{"data":{"translations":[{"translatedText":"Привет"}]}}`

### Рекомендуемая комбинация

DeepL + Google — покрывает все 130+ языков, при этом для европейских используется более качественный DeepL:

```bash
dart run bin/language_revisor.dart --auto \
  --deepl-key=YOUR_DEEPL_KEY:fx \
  --google-key=YOUR_GOOGLE_KEY
```

---

## Yandex Translate

**Качество:** ★★★★ — отличное для русского и постсоветских языков  
**Языков:** 100+  
**Офлайн:** нет  
**Бесплатный тариф:** через Yandex Cloud (платёжный аккаунт обязателен, но есть бесплатный грант)

### Получение API ключа

1. Зайдите на [yandex.cloud](https://yandex.cloud/) и создайте аккаунт
2. Создайте платёжный аккаунт (бесплатный грант доступен)
3. Перейдите в **Translate API** → создайте сервисный аккаунт
4. Создайте API-ключ для сервисного аккаунта
5. Скопируйте ключ (начинается с `AQVN...`)

### Настройка провайдера

Yandex Translate реализован как дополнительный провайдер.
Создайте файл `lib/tools/i18n/translator/yandex_provider.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'provider.dart';

class YandexTranslateProvider implements TranslationProvider {
  final String apiKey;
  static const _endpoint = 
    'https://translate.api.cloud.yandex.net/translate/v2/translate';

  static const _supported = {
    'ru', 'en', 'uk', 'be', 'kk', 'az', 'hy', 'ka', 'uz',
    'tr', 'de', 'fr', 'es', 'it', 'pt', 'pl', 'nl', 'cs',
    'sv', 'fi', 'zh', 'ja', 'ko', 'ar', 'he', 'vi', 'id',
  };

  YandexTranslateProvider({required this.apiKey});

  @override
  String get name => 'Yandex Translate';

  @override
  bool supportsLanguage(String langCode) =>
      _supported.contains(langCode.toLowerCase());

  @override
  Future<bool> isAvailable() async {
    if (apiKey.isEmpty) return false;
    try {
      // Тестовый запрос
      final result = await translate('test', from: 'en', to: 'ru');
      return result.text.isNotEmpty;
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
      'texts': [text],
      'targetLanguageCode': to,
      'sourceLanguageCode': from,
      if (context != null) 'glossaryConfig': {
        'glossaryData': {
          'glossaryPairs': [
            {'sourceText': context, 'translatedText': context}
          ]
        }
      },
    });

    final client = HttpClient();
    final req = await client.postUrl(Uri.parse(_endpoint));
    req.headers.set('Authorization', 'Api-Key $apiKey');
    req.headers.contentType = ContentType.json;
    req.write(body);

    final res = await req.close();
    final raw = await res.transform(utf8.decoder).join();
    client.close();

    if (res.statusCode != 200) {
      throw Exception('Yandex ${res.statusCode}: $raw');
    }

    final data = jsonDecode(raw) as Map<String, dynamic>;
    final translated = (data['translations'] as List).first['text'] as String;

    return TranslationResult(
      text: translated,
      provider: name,
      needsReview: context == null,
    );
  }
}
```

Подключите в `chain.dart`:

```dart
// lib/tools/i18n/translator/chain.dart
import 'yandex_provider.dart';

// В методе fromConfig():
final yandexKey = Platform.environment['YANDEX_TRANSLATE_KEY'] 
    ?? args['yandex-key'] ?? '';
if (yandexKey.isNotEmpty) {
  providers.add(YandexTranslateProvider(apiKey: yandexKey));
}
```

### Настройка в CLI

```bash
export YANDEX_TRANSLATE_KEY="AQVNy..."
dart run bin/language_revisor.dart --auto
```

---

## Ollama — Локальный LLM

**Качество:** ★★★ — зависит от модели  
**Языков:** все (LLM обучены на многоязычных данных)  
**Офлайн:** ✅ да — интернет не нужен  
**Стоимость:** бесплатно (только ресурсы машины)

### Установка Ollama

```bash
# macOS
brew install ollama

# Linux
curl -fsSL https://ollama.com/install.sh | sh

# Windows
# Скачайте установщик с https://ollama.com/download
```

### Запуск и скачивание моделей

```bash
# Запустить Ollama сервер
ollama serve

# Скачать рекомендуемые модели для перевода
ollama pull llama3          # 4.7GB — лучшее качество перевода
ollama pull mistral         # 4.1GB — быстрее, меньше памяти
ollama pull gemma2          # 5.4GB — хорошее качество от Google
ollama pull phi3            # 2.4GB — минимальные требования к памяти
```

### Настройка

```bash
# Стандартный запуск
dart run bin/language_revisor.dart --auto --ollama-model=llama3

# Свой хост (например удалённый сервер)
dart run bin/language_revisor.dart --auto \
  --ollama-model=mistral \
  --ollama-host=http://192.168.1.50:11434

# Через env
export OLLAMA_MODEL=llama3
export OLLAMA_HOST=http://localhost:11434
dart run bin/language_revisor.dart --auto
```

### Требования к ресурсам

| Модель | RAM | Качество перевода |
|---|---|---|
| `phi3` | 4 GB | Базовое |
| `mistral` | 8 GB | Хорошее |
| `llama3` | 8 GB | Отличное |
| `gemma2` | 12 GB | Отличное |
| `llama3:70b` | 48 GB | Максимальное |

### Советы для лучшего качества

Ollama использует промпт с контекстом (реализован в `llm_provider.dart`):

```dart
// Из llm_provider.dart — промпт отправляемый в Ollama
final prompt = '''
Translate the following UI string from $from to $to.
${context != null ? 'Context: $context' : ''}
Return ONLY the translated text, no explanations.

Text to translate: $text
''';
```

Для лучших результатов — добавляйте `@i18n-context` аннотации в код.

### Проверка доступности

```bash
curl http://localhost:11434/api/tags
# Должен вернуть список установленных моделей

# Тестовый перевод
curl http://localhost:11434/api/generate -d '{
  "model": "llama3",
  "prompt": "Translate to Russian: Create item",
  "stream": false
}'
```

---

## Stub — Заглушка

**Качество:** — (не переводит)  
**Языков:** все  
**Офлайн:** всегда доступна  
**Назначение:** позволяет запустить pipeline даже без провайдеров, помечая строки для ручного перевода

Stub автоматически активируется, если ни один другой провайдер не доступен.
Создаёт записи вида:

```json
{
  "createItem": "⚠️ NEEDS_REVIEW: Create item",
  "@createItem": {
    "x-needs-review": true,
    "x-translated-by": "Stub"
  }
}
```

Найти все строки требующие ревью:

```bash
grep -r "NEEDS_REVIEW" lib/*/l10n/
```

---

## Добавление своего провайдера

### Шаг 1 — Реализуйте интерфейс

Создайте файл `lib/tools/i18n/translator/my_provider.dart`:

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
    // Укажите поддерживаемые языки
    const supported = {'en', 'ru', 'zh', 'de', 'fr'};
    return supported.contains(langCode.toLowerCase());
  }

  @override
  Future<bool> isAvailable() async {
    if (apiKey.isEmpty) return false;
    try {
      // Проверьте доступность вашего API
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse('https://api.example.com/ping'));
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
      'text': text,
      'from': from,
      'to': to,
      if (context != null) 'context': context,
    });

    final client = HttpClient();
    final req = await client.postUrl(
      Uri.parse('https://api.example.com/translate'),
    );
    req.headers.set('Authorization', 'Bearer $apiKey');
    req.headers.contentType = ContentType.json;
    req.write(body);

    final res = await req.close();
    final raw = await res.transform(utf8.decoder).join();
    client.close();

    if (res.statusCode != 200) {
      throw Exception('MyProvider ${res.statusCode}: $raw');
    }

    final data = jsonDecode(raw) as Map<String, dynamic>;

    return TranslationResult(
      text: data['translation'] as String,
      provider: name,
      needsReview: context == null,
    );
  }
}
```

### Шаг 2 — Зарегистрируйте в цепочке

Откройте `lib/tools/i18n/translator/chain.dart` и добавьте:

```dart
import 'my_provider.dart';

// В методе TranslationChain.fromConfig():
final myKey = Platform.environment['MY_PROVIDER_KEY'] 
    ?? config['my-provider-key'] ?? '';
if (myKey.isNotEmpty) {
  providers.add(MyTranslationProvider(apiKey: myKey));
}
```

### Шаг 3 — Добавьте поддержку флага (опционально)

В `bin/language_revisor.dart`:

```dart
// В парсере аргументов:
final myKey = args['my-provider-key'] as String? ?? 
    Platform.environment['MY_PROVIDER_KEY'] ?? '';
```

### Шаг 4 — Использование

```bash
export MY_PROVIDER_KEY="your-key"
dart run bin/language_revisor.dart --auto
```

---

## Сравнительная таблица

| Провайдер | Языков | Хинди | Офлайн | Бесплатно | Качество | Рекомендуется для |
|---|---|---|---|---|---|---|
| **DeepL** | 29 | ❌ | ❌ | 500K символов/мес | ★★★★★ | EN/RU/DE/FR/ZH/ES — высшее качество |
| **Google Translate** | 130+ | ✅ | ❌ | $300 кредит | ★★★★ | Хинди, редкие языки, полное покрытие |
| **Yandex Translate** | 100+ | ❌ | ❌ | Бесплатный грант | ★★★★ | RU и постсоветские языки |
| **Ollama** | Все | ✅ | ✅ | Бесплатно | ★★★ | Офлайн, приватные проекты |
| **Stub** | Все | ✅ | ✅ | Бесплатно | — | Разработка, отладка пайплайна |

### Рекомендуемые комбинации

**Максимальное качество (платно):**
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
  --ollama-model=llama3
```

**Полностью офлайн (без интернета):**
```bash
dart run bin/language_revisor.dart --auto --ollama-model=llama3
```

**Разработка и отладка (без ключей):**
```bash
dart run bin/language_revisor.dart --auto
# Stub создаст NEEDS_REVIEW записи — их можно потом найти и перевести вручную
```
