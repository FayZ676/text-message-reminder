# Text Message Reminder

Define a message, a contact, and a frequency once. The app notifies you on that cadence and opens Messages with the text already composed — all you do is hit Send.

It deliberately does **not** send for you. iOS has no API for sending an iMessage without user consent, so the last tap is always yours.

Messages can be organised into **lists** — birthdays, friends and family, work — each with its own
color and icon. Lists sit at the top of the main screen and open to just their own messages;
anything you don't file into one stays listed underneath. A list is optional and purely
organisational: filing a message changes nothing about when or how it fires.

Messages are ordered by when they next come due, soonest first, and each row ends with that date.

A contact doesn't need a phone number or email. For friends you only reach in other apps, the
reminder still fires; Compose copies the message to the clipboard instead of opening Messages.

## Running on your phone

Signing is already configured for your team (`WG5M4FAV79`), so there's nothing to set up:

```bash
open TextMessageReminder.xcodeproj
```

Plug in your iPhone, select it as the run destination, and hit Run. First launch on a device will ask you to trust the developer certificate under Settings → General → VPN & Device Management.

Command-line build:

```bash
xcodebuild -project TextMessageReminder.xcodeproj -scheme TextMessageReminder \
  -destination 'generic/platform=iOS' build
```

## What to check on device

1. **Permissions** — grant notifications on first launch. The contact picker needs no permission; it runs out-of-process, so you'll never see a Contacts prompt.
2. **Compose** — add a message, then tap "Compose" on the row. Messages should open with the recipient and body prefilled. Try a message with punctuation, an ampersand, and an emoji — the body is aggressively percent-encoded specifically so those survive.
3. **Scheduled fire** — set a message a couple of minutes out, background the app, and wait. Tapping the notification (or its "Compose" button) should foreground the app and open Messages with the draft.
4. **Toggle and delete** — turning a message off should cancel its pending notification; deleting should too.
5. **Persistence** — force-quit and relaunch; messages should survive and schedules re-sync.
6. **Lists** — make a list from the message editor's "New List", move a message into it,
   force-quit, and relaunch. Deleting a list asks whether its messages go with it — check
   "Delete List Only" leaves them unfiled and still scheduled, and that "Delete List and
   Messages" cancels their pending notifications.
7. **Lock screen** — lock the phone, let a reminder fire, and tap it. After Face ID, Messages
   should open with the draft.
8. **No phone number** — schedule a message for a contact with no number or email. It should
   save and fire; Compose should copy the text and say so.

## Tests

```bash
xcodebuild test -project TextMessageReminder.xcodeproj -scheme TextMessageReminder \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Ten XCUITests cover the create flow end to end — picking a stock simulator contact, saving,
and confirming the message lands in the list, both from the empty state and with rows already
there — plus the contact-picker dismissal regression described below. The app takes a
`-uitesting` launch argument that swaps in an in-memory SwiftData store, so runs don't inherit
each other's messages.

**Run them on iOS 18 as well as the latest simulator.** The deployment target is iOS 18.0, and
the suite used to identify the contact picker by its navigation bar title — which is "Contacts"
on iOS 26 but "iPhone" on iOS 18. That passed on the newest runtime while failing on the one
most devices actually run, so the create flow was effectively untested there. Tests now locate
the picker structurally (`XCUIApplication.pickerNavigationBar`).

```bash
xcodebuild test -project TextMessageReminder.xcodeproj -scheme TextMessageReminder \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6'
```

## App Store screenshots

`AppStore/Screenshots` holds the 6.9" iPhone set (1320×2868). `ScreenshotTests` regenerates it
from sample data that a DEBUG-only `-screenshots` launch argument seeds into the in-memory store;
the test skips itself unless it's given a folder to write to:

```bash
xcrun simctl status_bar 'iPhone 17 Pro Max' override --time 9:41 --batteryState charged --batteryLevel 100
TEST_RUNNER_SCREENSHOT_DIR="$PWD/AppStore/Screenshots" xcodebuild test \
  -project TextMessageReminder.xcodeproj -scheme TextMessageReminder \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:TextMessageReminderUITests/ScreenshotTests
```

The Messages handoff isn't in the set: the simulator has no iMessage account, so the recipient
never resolves and the draft looks broken.

`AppStore/Creative` holds the product page header (3840×1646, 21:9) and search results asset
(3840×2560, 3:2), which iOS 27 shows in place of screenshots. Both are rendered from the icon and
the screenshots above, so rerun after either changes:

```bash
python3 -I AppStore/make_creative_assets.py
```

## Verified

Builds clean for simulator and device with no warnings. The create flow is covered by passing
UI tests on both iOS 18.6 and iOS 26. The `sms:` URL handoff to Messages was confirmed in the
simulator.

Not verified: the notification actually firing on schedule, and sending. The Simulator can't
send messages, so both need a real device.

## How it's built

```
TextMessageReminder/
├── TextMessageReminderApp.swift    entry; SwiftData container, coordinator wiring
├── Models/
│   ├── Message.swift               @Model; contact stored denormalized
│   ├── MessageGroup.swift          @Model; a list, with its messages (named for its stored entity)
│   ├── GroupColor.swift            a list's color and symbol vocabulary
│   └── Frequency.swift             daily/weekly/monthly/yearly → DateComponents
├── Services/
│   ├── MessagesLink.swift          builds the sms: URL
│   ├── MessageComposer.swift       opens Messages, or copies when there's no address
│   ├── NotificationScheduler.swift schedule/cancel/sync; MessageSchedule snapshot
│   └── NotificationCoordinator.swift  notification taps → published state
└── Views/
    ├── MessageListView.swift       root: lists, then unfiled messages
    ├── MessageEditorView.swift
    ├── MessageRow.swift            one message, shown on both screens
    ├── MessageRows.swift           the rows, soonest first, plus pause/edit/delete
    ├── GroupDetailView.swift       one list's messages
    ├── GroupEditorView.swift       name, color, icon
    ├── GroupGlyph.swift            a list's symbol on its colored circle
    ├── GroupDeletion.swift         the "and its messages?" confirmation
    └── ContactPickerView.swift     CNContactPickerViewController wrapper
```

A few decisions worth knowing if you come back to this later:

- **The `sms:` URL uses `&body=`, not `?body=`.** iOS expects an ampersand even for the first parameter, and `URLComponents` mangles `sms:` because its path is opaque — so the string is assembled by hand in `MessagesLink`.
- **Notification taps route through published state, not the delegate.** On a cold launch, or a tap from the lock screen, the delegate fires before the app is active and `UIApplication.open` silently fails, so the tap publishes an ID and the list opens Messages only once the scene is `.active`.
- **"Groups" in code, "Lists" on screen.** SwiftData stores the model under its class name, so renaming `MessageGroup` would orphan every list already saved on a device.
- **Nothing may dismiss the contact picker.** `CNContactPickerViewController` tears down its own presentation. Any second dismissal — `dismiss()`, or resetting the parent's `isPresented` flag — lands after the picker's sheet is already gone and closes the *editor* instead. SwiftUI resets the binding on its own; `testContactPickerCanBeReopenedAfterCancelling` guards that.
- **The scheduler never sees a SwiftData model.** `@Model` types aren't `Sendable`, so `Message.schedule` takes a `MessageSchedule` snapshot on the main actor before crossing into async code.
- **Deleting a list never silently deletes messages.** The relationship's delete rule is `.nullify`,
  so the destructive path is the one that has to be asked for: a list with messages in it prompts,
  and "Delete List and Messages" cancels each notification and deletes each message explicitly
  before the list goes. An empty list skips the prompt.

The Xcode project uses a filesystem-synchronized root group, so new `.swift` files under `TextMessageReminder/` are picked up automatically — no `project.pbxproj` edits needed.

## Not in v1

Snooze/skip, message templates with variables, send history, multiple recipients, "every N days" intervals, and a Shortcuts/App Intents surface.