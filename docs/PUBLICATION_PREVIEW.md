# Пакет первой публичной beta

Архив одобренного пакета от 11 октября 2026. [Beta опубликована](https://github.com/DoonyFreeman/Unpile/releases/tag/v0.7.0-beta.1) в `DoonyFreeman/Unpile` из ревизии `af4709c08c17b8a01739eb65d39847008c142cd8`; скачивание всех assets без авторизации и их checksum проверены. Ниже сохранён состав одобренных действий и ещё не опубликованные материалы продвижения.

## Точное назначение и действия

Одобренные и выполненные действия:

1. Создать публичный репозиторий **DoonyFreeman/Unpile** с описанием: “Swipe through your Downloads. A free, native macOS app with review before Trash.”
2. Отправить проверенную исходную ревизию в `main`. Локальная ветка подготовки — `codex/release-beta-0.7`.
3. Использовать подготовленную MIT-лицензию с notice `2026 Unpile contributors`. Commit author — публичный GitHub username и GitHub noreply email, без личного адреса.
4. Включить private vulnerability reporting. Maintainer первого релиза — владелец `DoonyFreeman`.
5. Создать tag **v0.7.0-beta.1** на проверенной ревизии и GitHub prerelease **Unpile 0.7.0 beta**. Release body — [RELEASE_NOTES_0.7.0.md](RELEASE_NOTES_0.7.0.md), без служебного абзаца “Publication draft”.
6. Прикрепить DMG, `.sha256` и `.manifest.json`. Проверить скачивание, соответствие checksum, tag/revision и видимость beta. После успешной публикации отдельным docs-only commit убрать из English/Русского README абзацы об ожидании публикации и заменить заключительную фразу об одобрении лицензии на “Licensed under MIT.” / “Лицензия MIT.” Ссылки и функциональные описания уже подготовлены; бинарник и tag не меняются.

Это одобрение относится к GitHub source/release. Тексты внешних объявлений ниже остаются черновиками.

## Артефакт и идентичность

- `build/releases/Unpile-0.7.0-universal.dmg`, Universal arm64/x86_64, бесплатная ad hoc подпись, без notarization.
- Permanent app ID: `io.github.doonyfreeman.unpile`; separate QA ID: `io.github.doonyfreeman.unpile.qa`.
- Точная ревизия, source-tree digest и checksum — в соседнем manifest. Он записывает commit только при чистом дереве; выдуманная revision не используется.
- Сессии временных локальных beta 0.2–0.6 не импортируются. Совместимость будущих ad hoc обновлений ещё не подтверждена.

Перед публикацией публикуемый набор проверяется по Git index: исходники, synthetic tests, resources, scripts, документация и community files. Игнорируемые build, локальные контейнеры, bookmarks, review state, журналы и credentials в Git не включаются.

## Что увидит посетитель

Название: **Unpile — review your Downloads one file at a time**.

Польза: “Keep what you need. Mark the rest, review the list, and confirm the move to Trash.”

Три опорных тезиса: **Native macOS · Files stay local · Review before Trash**.

Блок Download в English/Русском README содержит точную ссылку на DMG этого beta tag и заметный beta status. Адрес артефакта:

```text
https://github.com/DoonyFreeman/Unpile/releases/download/v0.7.0-beta.1/Unpile-0.7.0-universal.dmg
```

Адрес проверен скачиванием без авторизации после публикации. Stable/latest ссылку для первой prerelease не используем.

## Сценарий ролика · 20 секунд

Все кадры — из synthetic demo. Суммы относятся к вымышленным размерам, не к реально освобождённому месту. Язык English, обычное окно; в кадре только приложение.

| Время | Действие | Подпись |
| --- | --- | --- |
| 0–3 с | Карточка и очередь | “Your Downloads, one file at a time.” |
| 3–6 с | Свайп влево на первом файле | “Mark a candidate.” |
| 6–9 с | Свайп вправо на следующем | “Keep what matters.” |
| 9–12 с | Later, затем Undo | “Not sure? Later. Changed your mind? Undo.” |
| 12–17 с | Открыть список и исключить кандидата | “Review before Trash.” |
| 17–20 с | Карточка + название/адрес проекта | “Free. Native macOS. Files stay local.” |

Ролик ещё не записан. Демо не выполняет перенос, поэтому запись не должна изображать реальное удаление или освобождение места. Публичные screenshot/social preview assets ещё предстоит сохранить и осмотреть.

## Черновик объявления · English

I built Unpile because reviewing a crowded Downloads folder takes too many little decisions. It shows one file at a time: swipe left to mark it, right to keep it, or choose Later. Nothing moves until you review the candidate list and confirm.

It's a free, open-source native macOS beta, built with SwiftUI and AppKit. Files stay on your Mac; there are no accounts or analytics. Previews, saved sessions, Undo before transfer, and English/Russian UI are included.

Source and beta download: use the repository and release URLs only after publication. The build is ad hoc signed and not notarized; installation and device limits are documented.

I'd appreciate feedback on the first review: what makes you hesitate when deciding whether to keep a download?

## Известные границы проверки

27/27 native debug/release checks и Intel checks через Rosetta. Apple Silicon/macOS 27 GUI. Physical trackpad: оба направления подтверждены пользователем в 0.6; gesture code в 0.7 тот же.

Ещё нужны: расширенный физический gesture walkthrough, spoken VoiceOver, older macOS/physical Intel GUI, clean browser-download/quarantine, media-codec matrix, проверка ad hoc обновления. Осмотр установщика в Finder пользователь отложил. Эти ограничения раскрыты в beta notes; stable v1 не заявляется.

Этот пакет одобрен и опубликован. Для следующих релизов сохраняется требование пользовательских инструкций AGENTS.md: “Wait for the user's explicit approval before merging or deploying to any shared, staging, or production environment.”
