# Phone verification (free, via WhatsApp)

We confirm a user's phone number **for free** — no SMS cost, no India DLT, no
billing card. The trick: instead of *us* sending an SMS OTP, the **user sends
us** a one-tap WhatsApp message containing a code. User-initiated WhatsApp
messages are free on Meta's Cloud API, and the fact that the message arrives
*from that number* is what proves they own it.

## The flow

```
App: enter phone  ──POST /phone/verify/start──▶  backend generates code,
                                                  stores its hash + TTL,
                                                  returns a wa.me deep link
        │
        ▼
App opens WhatsApp with "Verify Revolution: 4821" pre-filled  ──user taps send──▶
        │
        ▼
Meta ──POST /phone/whatsapp/webhook──▶ backend matches code + sender number
                                        → marks attempt 'verified'
        │
        ▼
App polls GET /phone/verify/{id}  ──▶  status: 'verified'  ✅
```

Ownership proof lives in one line of `ingest_inbound()`: the sender's number
must equal the number the user claimed, or it doesn't count.

## Try it right now (no WhatsApp needed)

With `OTP_DEBUG_RETURN_CODE=true` (the default in `.env.example`), the code is
returned in the API response, so you can test the whole loop locally:

```bash
# 1. Start a verification
curl -s -X POST localhost:8000/phone/verify/start \
  -H 'X-Owner-Id: demo-user' -H 'Content-Type: application/json' \
  -d '{"phone":"+91 98765 43210","region":"IN"}' | jq

# → { "id": "...", "whatsapp_url": "...", "debug_code": "4821", ... }

# 2. Simulate the inbound WhatsApp message (what Meta would POST)
curl -s -X POST localhost:8000/phone/whatsapp/webhook \
  -H 'Content-Type: application/json' \
  -d '{"entry":[{"changes":[{"value":{"messages":[
        {"type":"text","from":"919876543210","text":{"body":"Verify Revolution: 4821"}}
      ]}}]}]}'

# 3. Poll status → verified: true
curl -s localhost:8000/phone/verify/<id> -H 'X-Owner-Id: demo-user' | jq
```

## Going live: get a free WhatsApp number (one-time, ~15 min)

1. Create a Meta app at <https://developers.facebook.com> → **Add product →
   WhatsApp**. Meta gives you a **free test phone number** and a temporary token.
2. In **WhatsApp → API Setup**, copy the **Phone number ID** and **temporary
   access token** into `backend/.env`
   (`WHATSAPP_PHONE_NUMBER_ID`, `WHATSAPP_ACCESS_TOKEN`). Set
   `WHATSAPP_BUSINESS_NUMBER` to that test number (E.164, no `+`).
3. Expose your local backend (`ngrok http 8000`) and in **WhatsApp →
   Configuration → Webhook** set:
   - Callback URL: `https://<your-ngrok>/phone/whatsapp/webhook`
   - Verify token: the same value as `WHATSAPP_VERIFY_TOKEN`
   - Subscribe to the **messages** field.
4. Set `OTP_DEBUG_RETURN_CODE=false`.

> The free test number can message a small allowlist of recipients — perfect for
> development. For production, add a real number and complete Meta business
> verification (still free for the user-initiated flow we use here).

## Why not SMS OTP?

Real SMS to Indian numbers isn't free anywhere: every provider needs either
India **DLT registration** (~₹12k + weeks of paperwork) or a **billing card**
(Twilio/Firebase). The WhatsApp user-initiated flow sidesteps both while giving
a nicer one-tap UX. If you later want SMS as a fallback, the service layer is
provider-agnostic — add a `send_sms()` path alongside the WhatsApp link.
```
