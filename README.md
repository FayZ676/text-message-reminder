# Text Message Reminder

Define a message, a contact, and a frequency once. The app notifies you on that cadence and opens Messages with the text already composed — all you do is hit Send.

It deliberately does **not** send for you. iOS has no API for sending an iMessage without user consent, so the last tap is always yours.

Reminders can optionally have their message **rewritten by Claude each time you compose**, so a weekly check-in doesn't arrive in identical words every week. Turn on "Vary this message" in the editor and paste an Anthropic API key under Settings.

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
2. **Compose** — add a reminder, then tap "Compose" on the row. Messages should open with the recipient and body prefilled. Try a message with punctuation, an ampersand, and an emoji — the body is aggressively percent-encoded specifically so those survive.
3. **Scheduled fire** — set a reminder a couple of minutes out, background the app, and wait. Tapping the notification (or its "Compose" button) should foreground the app and open Messages with the draft.
4. **Toggle and delete** — turning a reminder off should cancel its pending notification; deleting should too.
5. **Persistence** — force-quit and relaunch; reminders should survive and schedules re-sync.
6. **Message variations** — save an API key in Settings, turn on "Vary this message", then tap "Compose" a few times. Each draft should be worded differently. Then turn off Wi-Fi and compose again: it should fall back to your original text with no error. Remove the key and compose: same fallback, plus a prompt to add one.

## Tests

```bash
xcodebuild test -project TextMessageReminder.xcodeproj -scheme TextMessageReminder \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Six XCUITests cover the create flow end to end — picking a stock simulator contact, saving,
and confirming the reminder lands in the list, both from the empty state and with rows already
there — plus the contact-picker dismissal regression described below. The app takes a
`-uitesting` launch argument that swaps in an in-memory SwiftData store, so runs don't inherit
each other's reminders.

**Run them on iOS 18 as well as the latest simulator.** The deployment target is iOS 18.0, and
the suite used to identify the contact picker by its navigation bar title — which is "Contacts"
on iOS 26 but "iPhone" on iOS 18. That passed on the newest runtime while failing on the one
most devices actually run, so the create flow was effectively untested there. Tests now locate
the picker structurally (`XCUIApplication.pickerNavigationBar`).

```bash
xcodebuild test -project TextMessageReminder.xcodeproj -scheme TextMessageReminder \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6'
```

## Verified

Builds clean for simulator and device with no warnings. The create flow is covered by passing
UI tests on both iOS 18.6 and iOS 26. The `sms:` URL handoff to Messages was confirmed in the
simulator.

Not verified: the notification actually firing on schedule, and sending. The Simulator can't
send messages, so both need a real device.

Also not verified: the live Anthropic call. `MessageVariationService` returns a stub under the
`-uitesting` launch argument, so the test suite never hits the network, and no real API key has
been exercised end to end — the request shape is written to the documented Messages API but has
not been run against it. Worth doing the device pass in "What to check on device" before trusting it.

## How it's built

```
TextMessageReminder/
├── TextMessageReminderApp.swift    entry; SwiftData container, coordinator wiring
├── Models/
│   ├── Reminder.swift              @Model; contact stored denormalized
│   └── Frequency.swift             daily/weekly/monthly/yearly → DateComponents
├── Services/
│   ├── MessageComposer.swift       builds the sms: URL
│   ├── MessageVariationService.swift  rewrites the message via the Anthropic API
│   ├── KeychainStore.swift         stores the Anthropic API key
│   ├── NotificationScheduler.swift schedule/cancel/sync; ReminderSchedule snapshot
│   └── NotificationCoordinator.swift  notification taps → published state
└── Views/
    ├── ReminderListView.swift
    ├── ReminderEditorView.swift
    ├── SettingsView.swift          API key entry
    └── ContactPickerView.swift     CNContactPickerViewController wrapper
```

Three decisions worth knowing if you come back to this later:

- **The `sms:` URL uses `&body=`, not `?body=`.** iOS expects an ampersand even for the first parameter, and `URLComponents` mangles `sms:` because its path is opaque — so the string is assembled by hand in `MessageComposer`.
- **Notification taps route through published state, not the delegate.** On a cold launch the delegate fires before the app is active and `UIApplication.open` silently fails, so the tap publishes an ID and the view opens Messages once the UI is alive.
- **Nothing may dismiss the contact picker.** `CNContactPickerViewController` tears down its own presentation. Any second dismissal — `dismiss()`, or resetting the parent's `isPresented` flag — lands after the picker's sheet is already gone and closes the *editor* instead. SwiftUI resets the binding on its own; `testContactPickerCanBeReopenedAfterCancelling` guards that.
- **The scheduler never sees a SwiftData model.** `@Model` types aren't `Sendable`, so `Reminder.schedule` takes a `ReminderSchedule` snapshot on the main actor before crossing into async code. `MessageVariationService` follows the same pattern with `VariationRequest`.
- **Variations are generated at compose time, and the notification body can't be one.** `UNCalendarNotificationTrigger` bakes its content in when the request is scheduled and fires without waking the app, so the notification always shows the message as written; only the Messages draft is rewritten.
- **A failed rewrite never blocks the send.** Offline, rate-limited, or a bad response — Messages still opens with the original text and says nothing. The one exception is a missing API key, which is actionable and would otherwise be invisible, so that alerts.

The Xcode project uses a filesystem-synchronized root group, so new `.swift` files under `TextMessageReminder/` are picked up automatically — no `project.pbxproj` edits needed.

## Not in v1

Snooze/skip, message templates with variables, send history, multiple recipients, "every N days" intervals, and a Shortcuts/App Intents surface.

On variations specifically: no tone/style picker, no preview-before-send, no memory of previous variations (each rewrite is independent, so wording can occasionally repeat), and no varied notification text — see the constraint above.
