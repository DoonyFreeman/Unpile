# Проверенный кандидат 0.7.0 · опубликованная beta

Статус: [beta `v0.7.0-beta.1` опубликована](https://github.com/DoonyFreeman/Unpile/releases/tag/v0.7.0-beta.1) 11 октября 2026 после одобрения пакета в публичном `DoonyFreeman/Unpile` под MIT. Private vulnerability reporting включён. Точная исходная ревизия `af4709c08c17b8a01739eb65d39847008c142cd8` записана в manifest и соответствует tag.

## Конкретный пакет

- Приложение: `build/Unpile-0.7.0-universal.app`.
- Образ: `build/releases/Unpile-0.7.0-universal.dmg`.
- Рядом: `.sha256` и `.manifest.json` с версиями, architectures, signing mode, executable/DMG hashes и digest исходного дерева.
- Постоянный bundle ID: `io.github.doonyfreeman.unpile`; QA — `io.github.doonyfreeman.unpile.qa`. Сессии временных beta не импортируются; совместимость будущих ad hoc обновлений ещё требуется проверить.
- Бесплатная ad hoc подпись; notarization отсутствует.

Manifest опубликованного пакета фиксирует исходный digest одобренного tag; последующие изменения документации в `main` его не меняют. Manifest содержит только разрешённые папки source/docs/scripts/resources, относительные пути и hashes; состояние пользовательских папок не упаковывается.

## Проверка

- arm64 и x86_64 компилируются отдельно; lipo создаёт Universal executable.
- 27 core checks на Apple Silicon в debug/release и 27 Intel checks через Rosetta. Пять новых сценариев покрывают последовательности свайпа.
- Strict code-signature verification, sandbox entitlements, отсутствие debug entitlement и сети, иконка/языки и отсутствие host paths.
- Верификация финального DMG, mount read-only, проверка bundle внутри и после копирования в изолированный `build/test-install-0.7.0` каталог. GUI 0.7 успешно запущен из скопированного приложения; путь работающего процесса проверен. Запуск прямо из образа ранее проверен на 0.6.
- GUI 0.7: Welcome, демо, Mark/Keep/Later, список, исключение кандидата, блокировка скрытых команд и Undo. Использовалось только демо, без пользовательских файлов. На 0.6 осмотрены стопка карточек, fixed decision dock, обычное/компактное окно, preview и English/Русский; mouse drag, short drag, вертикальная прокрутка и preview guards. UI и gesture code в 0.7 не изменены.
- 11 октября 2026 пользователь подтвердил оба направления двухпальцевого свайпа в демо финальной копии 0.6.0. Полный ручной проход, включая короткий жест, инерцию, оба значения Natural Scrolling и preview/settings, ещё нужен. Поведение и критерии — [GESTURES_AND_DESIGN.md](GESTURES_AND_DESIGN.md).
- Finder metadata, Applications symlink и размер retina-фона проверены как содержимое образа; внешний вид окна установщика в Finder пользователь отложил.
- Инструкции установки соответствуют [актуальному пути Apple](https://support.apple.com/en-us/102445). Реальный quarantine-сценарий браузерного скачивания ещё нужен на чистом устройстве; защита глобально не отключается.

GUI проверен на Apple Silicon/macOS 27. Rosetta checks не подтверждают GUI на физическом Intel Mac или macOS 14. Полный VoiceOver walkthrough, media-codec matrix и добровольный пилот остаются проверками перед стабильной v1.

## Одобренный и опубликованный пакет

[PUBLICATION_PREVIEW.md](PUBLICATION_PREVIEW.md) сохраняет одобренное назначение `DoonyFreeman/Unpile`, public source/main, MIT notice, private vulnerability reporting и prerelease `v0.7.0-beta.1`. [RELEASE_NOTES_0.7.0.md](RELEASE_NOTES_0.7.0.md) — опубликованный release body без служебного footer. Commit и hashes находятся в соседнем manifest. Все три assets скачаны без авторизации и побайтно совпали с одобренным пакетом; hashes 70 исходных файлов проверены против tag.

Публичная beta раскрывает непроверенные устройства/сценарии; stable v1 не заявляется. Clean browser-download/quarantine, older macOS/physical Intel GUI и расширенные accessibility/gesture checks остаются открытыми.

Одобренные source/tag/release опубликованы в GitHub. [Hosted Checks](https://github.com/DoonyFreeman/Unpile/actions/runs/38090790265) прошёл на `macos-26` и `macos-26-intel`: core checks, сборка приложения, подпись/ресурсы и diff check. Объявления в сообщества и личные сообщения не отправлялись.

## Повторить сборку

```sh
swift run UnpileChecks
bash scripts/package-dmg.sh --universal
python3 scripts/verify-app.py build/Unpile-0.7.0-universal.app --universal
```

Только для проверки используется `--qa`. Оно меняет идентичность приложения и помогает изолировать синтетический набор от пользовательского контейнера.

Finder metadata создаётся с [ds_store](https://ds-store.readthedocs.io/en/latest/) и [mac_alias](https://mac-alias.readthedocs.io/en/latest/). Эти MIT build tools фиксируются по версии и SHA-256, не включаются в приложение. Artwork создан в исходном скрипте; чужие glyphs/assets в icon не копируются.

GitHub workflows используют [macos-26 и macos-26-intel](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), read-only permissions и pinned actions. Candidate workflow запускается вручную и загружает CI artifact, не создавая GitHub Release.
