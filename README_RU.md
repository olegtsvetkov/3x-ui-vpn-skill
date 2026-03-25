[English](README.md) | [Русский](README_RU.md)

# Запуск Xray VPN на своём сервере за 10 минут

Поднимаем Xray VLESS VPN на своем сервере или VPS одной командой, используя панель 3X-UI для установки и управления.

Вам понадобится:

- VPS с Ubuntu 24 или новее у любого хостинг-провайдера
- `1 vCPU`
- `512 MB` памяти
- `10 GB` диска
- около `10 минут`

Канонический skill bundle находится в [`skills/3x-ui-vps/`](skills/3x-ui-vps/).

Детали архитектуры: [`skills/3x-ui-vps/references/architecture.md`](skills/3x-ui-vps/references/architecture.md)

Корень этого репозитория также является Claude Code plugin с namespace `3x-ui-vpn-skills`. Навык `3x-ui-vps` внутри него работает в manual-first режиме, потому что меняет удаленную инфраструктуру.

## Что умеет скилл

В скилле есть 5 сценариев:

1. `Fresh deploy` настраивает ваш сервер с нуля, включая установку зависимостей, закрытие лишних портов и базовую конфигурацию.
2. `Panel access` пробрасывает SSH-туннель с сервера на ваш компьютер, чтобы вы могли открыть панель 3X UI.
3. `Quick inbound bootstrap` создает inbound для Xray VLESS на порту `443`, с nginx перед ним.
4. `Add another client to an existing inbound` добавляет клиента в существующий inbound, чтобы подключить еще одно устройство.
5. `Updates` обновляет систему (`apt update` и `apt upgrade`) и 3X UI.

## Как использовать

Установите скилл по инструкции ниже и затем используйте его в чате.

Примеры:

- `Codex`: `$3x-ui-vps, настрой мне VPN`
- `Claude Code`: `/3x-ui-vpn-skills:3x-ui-vps настрой мне VPN`
- `Cursor`: `Настрой мне VPN, используя инструкции из AGENTS.md`
- `OpenClaw`: `Настрой мне VPN, используя скилл 3x-ui-vps`

Пример запроса:

```text
$3x-ui-vps, настрой мне VPN
```

## Какие данные понадобятся

После запуска скилл запросит дополнительную информацию:

- `SSH target`: пользователь и IP для подключения по SSH в формате `root@X.Y.Z.A`; для установки всех зависимостей нужен пользователь `root`
- `SSH password`: пароль пользователя `root`; не нужен, если у вас уже настроена авторизация по ключу
- `Domain`: ваш домен или поддомен, на котором будет поднят VPN; подойдет любой домен от любого регистратора
- `Panel Username`: имя пользователя панели 3X UI
- `Panel Password`: пароль пользователя панели 3X UI
- `ACME Email`: ваш email для выпуска SSL-сертификата Let's Encrypt для указанного выше домена; не обязательно

## Файлы в репозитории

- [`skills/3x-ui-vps/SKILL.md`](skills/3x-ui-vps/SKILL.md): канонический bundle по стандарту Agent Skills
- [`skills/3x-ui-vps/scripts/`](skills/3x-ui-vps/scripts/): единственный допустимый интерфейс для изменений на удаленном сервере
- [`skills/3x-ui-vps/references/`](skills/3x-ui-vps/references/): справочные документы, загружаемые по мере необходимости
- [`skills/3x-ui-vps/agents/openai.yaml`](skills/3x-ui-vps/agents/openai.yaml): UI-метаданные для Codex/OpenAI
- [`.agents/skills`](.agents/skills): repo-scoped совместимый линк Codex на каноническую директорию `skills/`
- [`3x-ui-vps`](3x-ui-vps): transitional compatibility shim к каноническому bundle `skills/3x-ui-vps/`
- [`AGENTS.md`](AGENTS.md): легковесная точка входа для Cursor и AGENTS-совместимых инструментов
- [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json): манифест Claude plugin
- [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json): манифест Claude marketplace

## Установка в любого агента, который поддерживает Agent Skills

Используйте prompt:

```text
Установи этот скилл: https://github.com/olegtsvetkov/3x-ui-vpn-skill
```

## Установка в Claude Code и Cowork

Установите через Claude plugin UI или через CLI:

```bash
claude plugin marketplace add olegtsvetkov/3x-ui-vpn-skill
claude plugin install 3x-ui-vpn-skills@3x-ui-vpn-skills
```

После этого вызывайте навык так:

```text
/3x-ui-vpn-skills:3x-ui-vps
```

## Установка в Codex

Самый простой путь внутри Codex — встроенный `$skill-installer`:

```text
$skill-installer install https://github.com/olegtsvetkov/3x-ui-vpn-skill/tree/master/skills/3x-ui-vps
```

Ручная установка по-прежнему работает через `$CODEX_HOME/skills` (обычно `~/.codex/skills`):

1. Скопируйте или заклонируйте [`skills/3x-ui-vps/`](skills/3x-ui-vps/) в `$CODEX_HOME/skills/3x-ui-vps`.
2. Перезапустите Codex.

Compatibility note:

- встроенный `$skill-installer` сейчас по умолчанию ставит в `$CODEX_HOME/skills`
- этот репозиторий также экспонирует `.agents/skills` для repo-scoped совместимости с AGENTS-style discovery flows

## Установка в Cursor

Используйте prompt `/create-skill`:

```text
/create-skill Установи этот скилл в Cursor: https://github.com/olegtsvetkov/3x-ui-vpn-skill
```

## Установка в OpenClaw

Установите через **clawhub**:

```bash
clawhub install 3x-ui-vps
```

или используйте prompt:

```text
Установи этот скилл: https://github.com/olegtsvetkov/3x-ui-vpn-skill
```

## Заметки

- Skill намеренно ориентирован на scripts-first workflow. Все изменения на удаленном сервере должны идти через bundled scripts.
- Панель и subscription server должны оставаться доступными только через loopback.
- nginx остается публичной гранью на `80/443`.
- Клиентский VPN-транспорт — это `VLESS + XHTTP` за nginx.
- В корне репозитория [`3x-ui-vps`](3x-ui-vps) оставлен как shim на один релиз для клонов этого репозитория. Не используйте shim как канонический источник для новых интеграций.

## Лицензия

Этот репозиторий и bundled skill распространяются по лицензии MIT. См. [LICENSE](LICENSE) и [`skills/3x-ui-vps/LICENSE.txt`](skills/3x-ui-vps/LICENSE.txt).
