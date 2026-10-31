# AI_FEATURE.md — Garden Guide (local rule-based helper)

**Owner:** Saketh Sagar Kokkireni (function, cases, evaluation). **Card UI and buttons:** Sai Athota.
**Code:** `lib/logic/garden_guide.dart`, `lib/widgets/garden_guide_card.dart`
**Tests:** `test/garden_guide_test.dart`

## What it is

Garden Guide suggests a weekly target for one habit based on what the user actually did
recently. It is labeled **"Rule-based helper"** in the app. It is not a trained or generative
model, it uses no network, and it adds no screen or table: it is a card on the Habit detail screen.

## User benefit

A gentler alternative to streak pressure: if your target is 5 but you have been practicing
about 3 days a week, the app offers 3 instead of letting you feel behind every week.

## Inputs and units

For one habit:

- The number of **distinct check-in dates (0–7 days)** in each of the **last three whole,
  completed local weeks (Monday–Sunday)** on or after the start date. Zero-count weeks are included.
- The partial starting week (if the habit started mid-week) and the current week are excluded.
- `Habit.weeklyTarget` (1–7) for the baseline and for the "keep" button.

## Method

1. `completedWeekCounts(...)` builds the three counts, oldest first. Fewer than three eligible
   weeks → `null`.
2. `suggestWeeklyTarget(...)` averages the counts, **rounds halves up** with integer math
   (`(2·sum + n) ~/ (2·n)`, so there are no floating-point surprises), and **clamps to 1–7**.

Both are pure Dart functions with no Flutter or database dependencies, so they are unit-tested directly.

## Explanation, override, disclosure

- The card shows the suggested number and the reason, e.g.
  *"Average of your last 3 full weeks (2, 3, 4) = 3.0, rounded to 3. Suggested target: 3 days a week."*
- **Apply 3 to target** opens the editor with 3 filled in. Nothing is saved until the user presses
  Save, and past weeks are never recalculated.
- **Keep my 5** hides the card.
- Disclosure on the card: *"Based only on your recent check-in counts. Not behavioral or health advice."*
  No confidence percentages are shown.

## No-data and invalid states

| Condition | Behavior |
| --- | --- |
| Fewer than 3 eligible completed weeks | "Not enough history yet…" and the user's target is kept. No number. |
| A weekly count outside 0–7 | Rejected with a message naming the bad value. No suggestion. |
| Current target outside 1–7 | Rejected. No suggestion. |
| Two check-ins on one date | Counted once (distinct dates), so duplicates can't inflate a week. |

## Baseline

The current user-set target ("suggest no change").

## Evaluation

Run with a controlled "today" (Wed Oct 28 2026) and clearly labeled fictional check-ins, so we did
not have to wait three real weeks. Absolute error = |prediction − actual next-week count|.

| Case | Type | Input | Expected | Actual (test) | Helper error | Baseline error | Pass |
| --- | --- | --- | --- | --- | --- | --- | --- |
| H1 | Normal | counts 2, 3, 4; target 5; next week actually 2 | suggest 3 | 3 | 1 | 3 | ✅ |
| H2 | No data | two eligible weeks / habit created this week | "Not enough history", no number | notEnoughHistory | – | – | ✅ |
| H3 | Invalid | a count of 9, or −1 | rejected, no suggestion | invalidInput | – | – | ✅ |
| H4 | Boundary | counts 0, 0, 1 (avg 0.33 → 0) | clamped to 1 | 1 | – | – | ✅ |
| H5 | Counterexample | counts 4, 4, 0 | mean gives 3 although usual pace is 4 | mean 3, median 4 | – | – | ✅ (limitation) |

Extra unit tests: the partial starting week is excluded; two check-ins on one date count once;
weeks are counted correctly across the Nov 1 daylight-saving change; results are clamped at 7.

**Run result (Oct 31, 2026, macOS):** `flutter test` → `00:06 +50: All tests passed!` (all 50 tests in the
project, including every Garden Guide case above). The H1 card was also checked by hand on the Android
emulator with the fictional sample habit: it showed "Suggested weekly target: 3 (yours is 5)" with the
explanation "Average of your last 3 full weeks (2, 3, 4) = 3.0, rounded to 3".

### What the evaluation does and does not show

With five hand-made cases this only shows the rule **behaves as designed**. It does not show that the
suggestion improves anyone's habits. H1's lower error than the baseline is one fictional example, not evidence.

## H5 decision: keep the mean, disclose the limitation

With counts 4, 4, 0 (one week away from routine), the mean gives 3 while the median gives 4, which
better matches the usual pace. We **kept the mean** because it is the topic recipe and is easier to
explain on the card, and because the user always decides (Apply or Keep). The median is implemented as
`GuideMethod.median` and compared in the H5 test, so switching is a one-argument change if we decide one
odd week matters more than simplicity.

## Alternatives considered

- **Median of three weeks** — less affected by one odd week (see H5); not chosen for the reasons above.
- **Trained model** — not appropriate: no data, no need, and it would be harder to explain and test.

## Privacy

All inputs are the user's own check-in rows on the device. Nothing is sent anywhere.
