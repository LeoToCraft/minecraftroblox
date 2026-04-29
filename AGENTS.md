# AGENTS.md

Правила для Codex/AI-агентов, работающих с этим Roblox-проектом.

## Контекст проекта

Это Rojo-проект Roblox-игры `Minecraft: Roblox Edition`: блочная песочница в стиле Minecraft с меню миров, генерацией ландшафта, сохранениями, установкой/разрушением блоков, жидкостями, падающими блоками, инвентарем и заготовкой мультиплеера через Roblox Reserved Servers.

Главная рабочая папка скриптов:

```text
D:\projects1\minecraftroblox\src
```

Папка `scripts/`, если она есть, не является основной рабочей папкой проекта. Не править ее без явного запроса пользователя.

## Структура

```text
src/
  client/
    ctrSettings.client.luau  # управление, хотбар, инвентарь, ломание/установка блоков
    guiMenu.client.luau      # меню, миры, настройки, мультиплеер, пауза
  server/
    wrlManager.server.luau   # сохранения, слоты, загрузка, хостинг, состояние игрока
    lqdSystem.server.luau    # генерация мира
    blcManager.server.luau   # обновление жидкостей
    plrModel.server.luau     # серверная проверка действий игрока
  shared/
    Hello.luau
```

## Базовые правила работы

- Перед изменениями быстро читать релевантные файлы в `src`, а не угадывать структуру.
- Для поиска использовать `rg`, если доступен. Если `rg` падает с `Access denied`, использовать `Get-ChildItem ... | Select-String`.
- Работать экономно по контексту: сначала искать конкретные функции, Remote-объекты, имена блоков или паттерны, затем читать только нужный диапазон строк вокруг найденного места.
- Не читать большие Luau-файлы целиком без необходимости. Если задача касается общего контракта, сохранений, `_G.MCRE`, Remote API, генерации мира или серверной проверки действий игрока, расширять чтение до всех связанных мест использования.
- Для проверки больших файлов не печатать весь файл. Использовать точечный поиск, `git diff --stat`, `git diff --unified=3 -- <file>` и проверку заголовков/ключевых строк.
- Не трогать чужие или несвязанные изменения в git.
- Не удалять `scripts/` самостоятельно без явного подтверждения пользователя.
- Для ручных правок использовать `apply_patch`.
- После правок проверять поиском, что не остались старые имена или очевидные конфликтующие ожидания.
- Если Roblox Studio показывает старый Output после правок в `src`, предполагать проблему синхронизации Rojo/Studio или запуск старой копии скриптов.

## Экономный рабочий процесс

Применять режим "сначала узко, потом расширять":

1. Найти релевантные места через `rg` или `Select-String`.
2. Прочитать только диапазон строк вокруг найденных совпадений.
3. Расширить чтение, если изменение влияет на общий контракт между клиентом и сервером, сохранения, структуру мира, имена ассетов или безопасность серверной проверки.
4. Перед правкой проверить все места использования изменяемого имени/Remote/атрибута.
5. После правки проверить короткий diff и поиском убедиться, что не осталось старых паттернов.

Примеры точечных команд:

```powershell
Select-String -Path src\server\wrlManager.server.luau -Pattern "LoadWorld|SaveAndQuitWorld|BuildWorld"
Get-Content src\server\wrlManager.server.luau | Select-Object -Skip 520 -First 120
git diff --stat
git diff --unified=3 -- src\server\plrModel.server.luau
Select-String -Path AGENTS.md -Pattern "^#|^##"
```

## Roblox/Rojo

Проект собирается и синхронизируется через Rojo:

```bash
rojo build -o "minecraftroblox.rbxlx"
rojo serve
```

В Roblox Studio должны существовать внешние ассеты и Remote-объекты, которые не описаны полностью в `default.project.json`:

- `ReplicatedStorage.rmtGame`
- `ReplicatedStorage.guiAssets`
- `ServerStorage.blcStorage`

При работе через MCP/инструменты браузера/Studio сначала проверять фактическую иерархию объектов в Roblox Studio, затем сверять ее с кодом в `src`. Типичная причина ошибок в этом проекте - рассинхрон имен объектов между Studio и Luau-скриптами.

## Важное соглашение по блокам

Папка шаблонов блоков:

```text
ServerStorage.blcStorage
```

Шаблоны внутри `blcStorage` в Studio должны называться:

```text
GrassBlock
DirtBlock
StoneBlock
CobblestoneBlock
LogBlock
LeavesBlock
SandBlock
GravelBlock
WaterBlock
LavaBlock
```

Игровые имена созданных блоков в `Workspace.WorldBlocks` должны оставаться в формате:

```text
blcGrass
blcDirt
blcStone
blcCobblestone
blcLog
blcLeaves
blcSand
blcGravel
blcWater
blcLava
```

Это важно: шаблоны в `ServerStorage` называются `GrassBlock`, `DirtBlock` и т.д., но клонированные блоки в мире переименовываются в `blcGrass`, `blcDirt` и т.д. Клиент, сохранения и серверная логика завязаны на игровые имена `blc*`.

## Решение уже найденного бага

Если Output Roblox показывает:

```text
Infinite yield possible on 'ServerStorage:WaitForChild("blocks")'
```

то код/Studio ищет старую папку `blocks`. Правильная папка:

```luau
local blocksFolder = ServerStorage:WaitForChild("blcStorage")
```

Если Output показывает ожидание `blcGrass`, `blcDirt`, `blcWater` и похожих имен внутри `ServerStorage.blcStorage`, нужно сверить имена шаблонов. В этом проекте код должен ждать `GrassBlock`, `DirtBlock`, `WaterBlock` и т.д., а не `blcGrass`.

После исправления обязательно проверить:

```powershell
Get-ChildItem -Path D:\projects1\minecraftroblox\src -Recurse -File |
  Select-String -Pattern 'WaitForChild\("blocks"\)|WaitForChild\("blcGrass"\)|WaitForChild\("blcDirt"\)|WaitForChild\("blcWater"\)'
```

## README vs AGENTS

- `README.md` предназначен для человека: описание проекта, возможности, запуск, общая структура.
- `AGENTS.md` предназначен для AI-агентов: рабочие правила, локальные соглашения, уже найденные решения и предупреждения.
- Архитектуру пока достаточно держать в README. Отдельный `ARCHITECTURE.md` нужен, когда появятся более крупные подсистемы: чанки, биомы, крафт, мобы, версия формата сохранений, полноценный мультиплеер.
