[English](README.md) | [Русский](README_RU.md)

# Запустите свой Xray VPN за 10 минут

Поднимите Xray VLESS VPN на своем сервере или VPS одной командой, используя панель 3X-UI для установки и управления.

Вам понадобится:

- VPS с Ubuntu 24 или новее у любого хостинг-провайдера
- `1 vCPU`
- `512 MB` памяти
- `10 GB` диска
- около `10 минут`

Канонический skill bundle находится в [`skills/3x-ui-vps/`](skills/3x-ui-vps/).

Детали архитектуры: [`skills/3x-ui-vps/references/architecture.md`](skills/3x-ui-vps/references/architecture.md)

Корень этого репозитория также является Claude Code plugin с namespace `3x-ui-vpn-skills`. Навык `3x-ui-vps` внутри него работает в manual-first режиме, потому что меняет удаленную инфраструктуру.

## Что Умеет Скилл

В скилле есть 5 сценариев:

1. `Fresh deploy` настраивает ваш сервер с нуля, включая установку зависимостей, закрытие лишних портов и базовую конфигурацию.
2. `Panel access` пробрасывает SSH-туннель с сервера на ваш компьютер, чтобы вы могли открыть панель 3X UI.
3. `Quick inbound bootstrap` создает inbound для Xray VLESS на порту `443`, с nginx перед ним.
4. `Add another client to an existing inbound` добавляет клиента в существующий inbound, чтобы подключить еще одно устройство.
5. `Updates` обновляет систему (`apt update` и `apt upgrade`) и 3X UI.

## Как Использовать

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

## Какие Данные Понадобятся

После запуска скилл запросит дополнительную информацию:

- `SSH target`: пользователь и IP для подключения по SSH в формате `root@X.Y.Z.A`; для установки всех зависимостей нужен пользователь `root`
- `SSH password`: пароль пользователя `root`; не нужен, если у вас уже настроена авторизация по ключу
- `Domain`: ваш домен или поддомен, на котором будет поднят VPN; подойдет любой домен от любого регистратора
- `Panel Username`: имя пользователя панели 3X UI
- `Panel Password`: пароль пользователя панели 3X UI
- `ACME Email`: ваш email для выпуска SSL-сертификата Let's Encrypt для указанного выше домена; не обязательно

## Included Files

- [`skills/3x-ui-vps/SKILL.md`](skills/3x-ui-vps/SKILL.md): канонический bundle по стандарту Agent Skills
- [`skills/3x-ui-vps/scripts/`](skills/3x-ui-vps/scripts/): единственный допустимый интерфейс для изменений на удаленном сервере
- [`skills/3x-ui-vps/references/`](skills/3x-ui-vps/references/): справочные документы, загружаемые по мере необходимости
- [`skills/3x-ui-vps/agents/openai.yaml`](skills/3x-ui-vps/agents/openai.yaml): UI-метаданные для Codex/OpenAI
- [`3x-ui-vps`](3x-ui-vps): transitional compatibility shim к каноническому bundle `skills/3x-ui-vps/`
- [`AGENTS.md`](AGENTS.md): легковесная точка входа для Cursor и AGENTS-совместимых инструментов
- [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json): манифест Claude plugin
- [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json): манифест Claude marketplace

## Install In Claude Marketplace

Установите через Claude plugin UI или командой:

```bash
claude plugin install 3x-ui-vpn-skills@olegtsvetkov-plugins
```

Для локальной разработки загружайте корень репозитория как plugin:

```bash
claude --plugin-dir .
```

После этого вызывайте навык так:

```text
/3x-ui-vpn-skills:3x-ui-vps
```

## Install In OpenClaw

Установите так:

```bash
clawhub install 3x-ui-vps
```

## Install In Codex

Codex устанавливает пользовательские skills в `$CODEX_HOME/skills` (обычно `~/.codex/skills`).

Внутри Codex самый простой путь — встроенный `$skill-installer` с GitHub URL на поддиректорию:

```text
$skill-installer install https://github.com/olegtsvetkov/3x-ui-vpn-skill/tree/master/skills/3x-ui-vps
```

Ручная установка тоже работает:

1. Скопируйте или заклонируйте [`skills/3x-ui-vps/`](skills/3x-ui-vps/) в `~/.codex/skills/3x-ui-vps`.
2. Перезапустите Codex.

## Install In Cursor

Cursor читает корневой [`AGENTS.md`](AGENTS.md).

Установка на уровне проекта:

1. Скопируйте [`AGENTS.md`](AGENTS.md) в корень проекта Cursor.
2. Скопируйте рядом полную папку [`skills/3x-ui-vps/`](skills/3x-ui-vps/) в `skills/3x-ui-vps/`.
3. Откройте или перезагрузите проект в Cursor.

Установка на уровне репозитория тоже работает: заклонируйте этот репозиторий и откройте его напрямую в Cursor.

## Install In Any Agent Skills-Compatible System

Используйте каноническую директорию [`skills/3x-ui-vps/`](skills/3x-ui-vps/) как переносимый skill bundle.

Требования:

- сохраняйте имя директории строго `3x-ui-vps`
- сохраняйте вместе [`SKILL.md`](skills/3x-ui-vps/SKILL.md), `scripts/`, `references/` и `agents/`
- устанавливайте или копируйте эту директорию в папку skills целевого продукта или в его импортный flow

Этот layout следует открытому стандарту Agent Skills и сохраняет навык самодостаточным.

Compatibility note:

- repo-root [`3x-ui-vps`](3x-ui-vps) оставлен как shim на один релиз для клонов этого репозитория
- не используйте shim как канонический источник для новых интеграций

## Usage Notes

- Skill намеренно ориентирован на scripts-first workflow. Все изменения на удаленном сервере должны идти через bundled scripts.
- Панель и subscription server должны оставаться доступными только через loopback.
- nginx остается публичной гранью на `80/443`.
- Клиентский VPN-транспорт — это `VLESS + XHTTP` за nginx.

## License

Этот репозиторий и bundled skill распространяются по лицензии MIT. См. [LICENSE](LICENSE) и [`skills/3x-ui-vps/LICENSE.txt`](skills/3x-ui-vps/LICENSE.txt).
