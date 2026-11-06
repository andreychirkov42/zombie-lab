# Фабрика криптозомби

[![CI](https://github.com/andreychirkov42/zombie-lab/actions/workflows/test.yml/badge.svg)](https://github.com/andreychirkov42/zombie-lab/actions/workflows/test.yml)

Практическая работа по Solidity и Foundry (Forge) по мотивам первого урока CryptoZombies.
Контракт `ZombieFactory` позволяет каждому адресу создать одного зомби с именем, ДНК и временем
появления, хранит владельцев и сообщает о создании событием. Работа выполняется локально, публичная сеть не нужна.

## Структура

```
src/ZombieFactory.sol         контракт
test/ZombieFactory.t.sol      тесты Forge
forge-test-output.txt         результат forge test -vv
lib/forge-std                 библиотека тестов (git submodule)
.github/workflows/test.yml    CI: forge fmt --check, forge build, forge test
```

## Контракт

Solidity `^0.8.20`.

| Элемент | Описание |
|---|---|
| `struct Zombie { string name; uint256 dna; uint256 createdAt; }` | данные зомби |
| `DNA_MODULUS = 10 ** 16` | ДНК лежит в диапазоне `0 ≤ dna < 10^16` |
| `Zombie[] private zombies` | все зомби; id — индекс в массиве (первый 0, дальше +1) |
| `mapping zombieToOwner` (public) | id → адрес владельца |
| `mapping ownerZombieCount` (public) | адрес → число его зомби (0 или 1) |
| `event ZombieCreated(uint256 indexed id, address indexed owner, string name, uint256 dna)` | событие о создании |
| `createZombie(string calldata name) returns (uint256 id)` | создаёт зомби для `msg.sender` |
| `totalZombies()` | количество зомби |
| `getZombie(uint256 id)` | `(name, dna, createdAt)`; для несуществующего id — стандартный revert индекса массива (panic 0x32) |

Проверки в `createZombie`:
- пустое имя — `revert("Empty name")`;
- у отправителя уже есть зомби — `revert("Already has zombie")`.

ДНК: `uint256(keccak256(abi.encodePacked(msg.sender, name))) % DNA_MODULUS`, время — `block.timestamp`.

## Запуск

Нужен [Foundry](https://getfoundry.sh) (`forge`).

```bash
git clone --recurse-submodules https://github.com/andreychirkov42/zombie-lab.git
cd zombie-lab
forge build
forge test -vv
```

Если репозиторий склонирован без `--recurse-submodules`: `git submodule update --init --recursive`.

Дополнительно:

```bash
forge fmt --check            # проверка форматирования
forge test -vvvv             # трассировки вызовов
forge coverage               # покрытие (100% строк и веток)
```

## Тесты

| Тест | Что проверяет |
|---|---|
| `testAliceCreatesZombie` | стартовый тест из задания: id 0, владелец — Alice |
| `testCreateZombieStoresData` | **01** — id, имя, ДНК, время (`vm.warp`), владелец, счётчики |
| `testTwoOwnersCreateDifferentZombies` | **02** — Alice и Bob создают по зомби, id 0 и 1, у одинаковых имён разная ДНК |
| `testRevertsOnEmptyName` | **03** — `vm.expectRevert("Empty name")` |
| `testRevertsOnSecondZombie` | **04** — повторный вызов: `vm.expectRevert("Already has zombie")` |
| `testDnaIsBelowModulus` | **05** — `dna < DNA_MODULUS` |
| `testEmitsZombieCreated` | событие `ZombieCreated` с верными аргументами (`vm.expectEmit`) |
| `testGetZombieRevertsForUnknownId` | несуществующий id — panic выхода за границы массива |
| `testFuzzDnaIsBelowModulus` | fuzz-тест: для случайных адресов и имён ДНК всегда меньше модуля |

Результат запуска — в [`forge-test-output.txt`](forge-test-output.txt): 9 тестов, все проходят.

## Контрольный вопрос

**Почему вычисление ДНК не является безопасной случайностью?**

ДНК — это детерминированная функция от публично известных данных: адреса отправителя и имени, которое
он сам передаёт. Любой может заранее посчитать `keccak256(abi.encodePacked(address, name)) % 10^16`
вне блокчейна и подобрать имя (или адрес), дающее нужную ДНК, а все данные транзакции видны в сети ещё до
её включения в блок. Поэтому для розыгрышей и наград нужен внешний источник случайности (например, оракул
вроде Chainlink VRF) или схема commit–reveal.
