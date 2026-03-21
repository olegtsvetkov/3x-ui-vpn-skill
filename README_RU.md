# Запустите свой Xray VPN за 10 минут

Поднимите Xray VLESS VPN на своем сервере или VPS одной командой, используя панель 3X-UI для установки и управления.

Вам понадобится:

- VPS с Ubuntu 24 или новее у любого хостинг-провайдера
- `1 vCPU`
- `512 MB` памяти
- `10 GB` диска
- около `10 минут`

Канонический skill bundle находится в [`3x-ui-vps/`](3x-ui-vps/).

Детали архитектуры: [`3x-ui-vps/references/architecture.md`](3x-ui-vps/references/architecture.md)

## Included Files

- [`3x-ui-vps/SKILL.md`](3x-ui-vps/SKILL.md): канонический bundle по стандарту Agent Skills
- [`3x-ui-vps/scripts/`](3x-ui-vps/scripts/): единственный допустимый интерфейс для изменений на удаленном сервере
- [`3x-ui-vps/references/`](3x-ui-vps/references/): справочные документы, загружаемые по мере необходимости
- [`3x-ui-vps/agents/openai.yaml`](3x-ui-vps/agents/openai.yaml): UI-метаданные для Codex/OpenAI
- [`AGENTS.md`](AGENTS.md): легковесная точка входа для Cursor и AGENTS-совместимых инструментов
- [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json): манифест Claude plugin
- [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json): манифест Claude marketplace

## Install In Claude Marketplace

Установите через Claude plugin UI или командой:

```bash
claude plugin install 3x-ui-vps
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
$skill-installer install https://github.com/olegtsvetkov/3x-ui-vpn-skill/tree/master/3x-ui-vps
```

Ручная установка тоже работает:

1. Скопируйте или заклонируйте [`3x-ui-vps/`](3x-ui-vps/) в `~/.codex/skills/3x-ui-vps`.
2. Перезапустите Codex.

## Install In Cursor

Cursor читает корневой [`AGENTS.md`](AGENTS.md).

Установка на уровне проекта:

1. Скопируйте [`AGENTS.md`](AGENTS.md) в корень проекта Cursor.
2. Скопируйте рядом полную папку [`3x-ui-vps/`](3x-ui-vps/).
3. Откройте или перезагрузите проект в Cursor.

Установка на уровне репозитория тоже работает: заклонируйте этот репозиторий и откройте его напрямую в Cursor.

## Install In Any Agent Skills-Compatible System

Используйте каноническую директорию [`3x-ui-vps/`](3x-ui-vps/) как переносимый skill bundle.

Требования:

- сохраняйте имя директории строго `3x-ui-vps`
- сохраняйте вместе [`SKILL.md`](3x-ui-vps/SKILL.md), `scripts/`, `references/` и `agents/`
- устанавливайте или копируйте эту директорию в папку skills целевого продукта или в его импортный flow

Этот layout следует открытому стандарту Agent Skills и сохраняет навык самодостаточным.

## Usage Notes

- Skill намеренно ориентирован на scripts-first workflow. Все изменения на удаленном сервере должны идти через bundled scripts.
- Панель и subscription server должны оставаться доступными только через loopback.
- nginx остается публичной гранью на `80/443`.
- Клиентский VPN-транспорт — это `VLESS + XHTTP` за nginx.

## License

Этот репозиторий и bundled skill распространяются по лицензии MIT. См. [LICENSE](LICENSE) и [`3x-ui-vps/LICENSE.txt`](3x-ui-vps/LICENSE.txt).
