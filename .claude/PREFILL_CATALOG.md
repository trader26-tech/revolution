# Prefill Catalog — handoff for the Revolution app agent

**Purpose:** prefill/suggest reminders during onboarding so users don't start from a blank list. For each life category, the **3 most likely items** with most-likely **name**, **date**, and **frequency** (India-first defaults, INR). Machine-readable source of truth: [`prefill_catalog.json`](prefill_catalog.json) in this folder — its fields match the app schema exactly (`Task.repeat`, `ItemDetails.cycle/notify/category`).

## Summary table (top 3 per category)

| Category | Item | Most likely date | Frequency |
|---|---|---|---|
| Finance | Credit card bill | 15th of month | Monthly |
| Finance | Loan EMI | 5th of month | Monthly |
| Finance | SIP investment | 5th of month | Monthly |
| Utilities | Electricity bill | 10th of month | Monthly |
| Utilities | Mobile recharge | 1st of month | Monthly |
| Utilities | Broadband bill | 8th of month | Monthly |
| Insurance | Health insurance premium | Policy anniversary | Yearly |
| Insurance | Life insurance premium (LIC/term) | Policy anniversary | Yearly |
| Insurance | Two-wheeler insurance renewal | Policy anniversary | Yearly |
| Health | Daily medicine | 8:00 AM | Daily |
| Health | Annual health checkup | Birthday month | Yearly |
| Health | Dentist visit | +6 months | Half-yearly |
| Vehicle | Car insurance renewal | Policy anniversary | Yearly |
| Vehicle | Car service | +6 months | Half-yearly |
| Vehicle | PUC certificate renewal | +6 months | Half-yearly |
| Documents | Passport renewal | 9 months before expiry | One-time |
| Documents | Driving licence renewal | 1 month before expiry | One-time |
| Documents | Visa / residency renewal | 2 months before expiry | Yearly-ish |
| Home | Rent | 1st of month | Monthly |
| Home | Society maintenance | 5th of month | Monthly |
| Home | AC service | Mid-March (pre-summer) | Yearly |
| Family | Birthday | User-entered | Yearly |
| Family | Wedding anniversary | User-entered | Yearly |
| Family | School fees | 10th of Apr/Jul/Oct/Jan | Quarterly |
| Entertainment | Netflix | Signup day | Monthly (₹199) |
| Entertainment | Amazon Prime | Signup day | Yearly (₹1499) |
| Entertainment | Disney+ Hotstar | Signup day | Yearly (₹1499) |
| Finance (taxes) | ITR filing | Jul 15 (deadline Jul 31) | Yearly |
| Finance (taxes) | Advance tax | 15 Jun/Sep/Dec/Mar | Quarterly |
| Finance (taxes) | Property tax | April | Yearly |
| Other (habits) | Exercise / walk | 6:00 PM | Daily |
| Other (habits) | Drink water | Daytime | Daily |
| Other (habits) | Meditation | 9:00 PM | Daily |

Rationale for the early-month money dates: salary lands on the 1st, so SIPs/EMIs cluster in the 3rd–10th window to avoid bounces; credit card cycles put due dates mid-month.

## How to wire it in

1. **Onboarding quiz → suggestions.** Each group in the JSON carries `quiz_keys` matching `kQuizOptions` keys in `frontend/lib/features/onboarding/domain/onboarding_quiz.dart` (`bills, insurance, loans, renewals, taxes, investments, health, vehicle, home, warranties, documents, work, subscriptions, birthdays`). After the quiz, offer the union of matching items as pre-checked suggestions; create each accepted one via `POST /tasks` (+ its `item_details` row).
2. **Dates are rules, not values.** `date_rule` must be resolved at creation time: `day_of_month` → next occurrence of that day; `anchor: policy_anniversary / signup_day / user_entered_date / expiry_minus_months` → ask the user for the real date with the stated fallback. Never create a due date in the past.
3. **Schema gaps found while building this** (worth fixing before wiring):
   - `RepeatCadence` (task.dart) has no `quarterly`/`halfYearly`, but `BillingCycle` (item_details.dart) does. Items marked `repeat: none` + `cycle: quarterly|half_yearly` need either enum extension or app-side re-scheduling on completion.
   - `OptionKind.category` defaults lack `Documents`, `Home`, `Family` — add them (or auto-append as custom options when prefilled).
   - DB `item_details.currency` defaults to `'₹'` while Dart uses `'INR'` — normalize.
4. **Icons:** `icon_name`/`icon_domain` values were chosen to match `BrandCatalog` entries where one exists; null means no obvious brand — fall back to the category icon.
