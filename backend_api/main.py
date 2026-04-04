import os
import json
import uvicorn
from twilio.rest import Client
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
import ollama

load_dotenv()

# ─── COLORS ───────────────────────────────────────────────────────────────────
RED, GREEN, YELLOW, CYAN, RESET = '\033[91m', '\033[92m', '\033[93m', '\033[96m', '\033[0m'

app = FastAPI(title="Grandparent Guardian - AI Core")

# ─── CORS ─────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── TWILIO CREDENTIALS ───────────────────────────────────────────────────────
TWILIO_ACCOUNT_SID   = os.environ.get("TWILIO_ACCOUNT_SID", "")
TWILIO_AUTH_TOKEN    = os.environ.get("TWILIO_AUTH_TOKEN", "")
TWILIO_FROM_NUMBER   = os.environ.get("TWILIO_FROM_NUMBER", "")
TARGET_FAMILY_NUMBER = os.environ.get("TARGET_FAMILY_NUMBER", "")

# ─── MINIMAL OFFLINE SAFETY NET ───────────────────────────────────────────────
OFFLINE_PHRASES = [
    "anydesk",
    "teamviewer",
    "digital arrest",
    "cyber crime notice",
    "customs fee",
    "fedex parcel seized",
]

# Trimmed down so polite greetings don't short-circuit the AI
SAFE_PHRASES = [
    "khaana khaya",
    "khana kha liya",
    "ghar kab aa raha",
    "theek hoon",
    "aap batao",
    "did you eat",
    "when are you coming",
]

def offline_keyword_check(text: str):
    lower = text.lower()
    matched = [p for p in OFFLINE_PHRASES if p in lower]
    if matched:
        return {
            "status":      "scam_detected",
            "probability": 99,
            "analysis":    f"Remote access / impersonation scam detected: '{matched[0]}'",
        }
    return None

def offline_safe_check(text: str):
    lower = text.lower()
    matched = [p for p in SAFE_PHRASES if p in lower]
    if matched:
        return {
            "status":      "safe",
            "probability": 5,
            "analysis":    f"Family check-in detected: '{matched[0]}'",
        }
    return None

# ─── THE BEST SYSTEM PROMPT ───────────────────────────────────────────────────
SYSTEM_PROMPT = """
You are an expert Indian scam detector AI protecting elderly grandparents from phone fraud.
You have deep knowledge of Indian scam tactics, Indian culture, and family dynamics.

The transcript may be in English, Hindi, Hinglish, or a mix — analyze the MEANING, not just keywords.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PROBABILITY CALIBRATION GUIDE:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CLEARLY SAFE (probability 0-15):
- "hello kaise ho" / "how are you"
- "khana kha liya?" / "did you eat?"
- "beta ghar kab aa raha hai" / "when are you coming home"
- "main theek hoon aap batao" / "I am fine how are you"
- Any casual health or daily life check-in from family

POSSIBLY SUSPICIOUS (probability 20-45):
- Unknown person asking general questions
- Delivery agent asking for address confirmation
- Service technician calling for appointment

LIKELY SCAM (probability 50-75):
- Stranger asking for personal details
- Urgency without clear reason

DEFINITE SCAM (probability 76-100):
- Any OTP request from stranger
- Threats of arrest, police, account block
- "Share OTP to receive money" in any language
- AnyDesk, TeamViewer download request
- STRANGERS offering "scholarships", "lotteries", "loans", or "free gifts"
- Unsolicited callers claiming to be from an "Institute", "College", or "Research" asking for personal details.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CRITICAL OVERRIDE RULES (FOLLOW STRICTLY):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. THE POLITENESS TRICK: Scammers often use extremely polite language ("hope you are doing well", "please", "sir"). Do NOT lower the risk score just because the caller is polite. If a stranger offers a scholarship or asks for data, it is a HIGH THREAT (80-100%).
2. THE FAMILY OVERRIDE: If the transcript contains ANY of these phrases: "personal tone", "family member", "checking in", "familiar", "casual", "well-being", "daily life" -> probability MUST be below 20, status MUST be "safe".

The model must NEVER contradict its own analysis text.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
THINK STEP BY STEP BEFORE ANSWERING:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Who is likely calling — a stranger, institution, or known family/friend?
2. What exactly are they asking for — OTP, money, access, personal info?
3. Is there urgency, fear, or a financial hook being created?
4. Does the tone feel scripted and professional, or personal and familiar?
5. THEN make your final decision.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MARK AS SCAM (status: scam_detected):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Asking for bank OTP, UPI PIN, ATM PIN, CVV, or password from a STRANGER
- "Share OTP to RECEIVE money or loan" → ALWAYS SCAM, no exceptions
  (Real banks/senders NEVER need your OTP to send you money)
- Threats of arrest, account block, court case, police, ED, CBI, RBI action
- Impersonating: banks, RBI, police, court, IRCTC, Amazon, FedEx, customs
- Asking to download AnyDesk, TeamViewer, QuickSupport, or any remote app
- Grandparent scam: stranger pretending to be a relative in emergency needing URGENT money
- Lottery/prize/scholarship scams: "You won/are eligible, tell me your details or pay a fee"
- KYC scams: "Your account will close, update KYC now by sharing details"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MARK AS SAFE (status: safe):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Delivery agent (Amazon, Flipkart, Zomato, Swiggy) asking for delivery OTP
- Cable/internet/appliance technician asking for service completion OTP
- Actual family member or friend with personal, familiar tone asking for money casually
  (e.g., "Dada mujhe college fees ke liye 2000 chahiye" — no threats, personal tone)
- General health/wellness check from family ("beta kaisa hai", "khaana khaya?")
- Genuine bank calling to confirm a transaction YOU already initiated

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STRICT CONSISTENCY RULES:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- probability = SCAM RISK (0 = completely safe, 100 = definite scam)
- If probability >= 50 → status MUST be "scam_detected"
- If probability < 50  → status MUST be "safe"
- NEVER contradict yourself — high probability MUST equal scam_detected
- Give analysis in simple language an elderly person would understand

Respond ONLY with valid JSON. No markdown, no explanation outside JSON:
{"status": "scam_detected" or "safe", "probability": integer 0-100, "analysis": "one simple sentence in English or Hindi"}
"""

# ─── DATA MODELS ──────────────────────────────────────────────────────────────
class AudioText(BaseModel):
    text: str

class AlertData(BaseModel):
    transcript:   str
    analysis:     str
    probability:  int
    family_phone: str = ""


# ─── /analyze ─────────────────────────────────────────────────────────────────
@app.post("/analyze")
async def analyze_text(data: AudioText):
    transcript = data.text.strip()
    print(f"\n{CYAN}[+] ANALYZING:{RESET} '{transcript}'")

    # ── Minimal offline safety net (only 100% obvious cases) ──
    quick = offline_keyword_check(transcript)
    if quick:
        print(f"{RED}[!] OFFLINE CATCH: {quick['analysis']}{RESET}")
        return quick

    # ── Quick check for safe family check-ins ──
    safe_check = offline_safe_check(transcript)
    if safe_check:
        print(f"{GREEN}[✓] OFFLINE SAFE: {safe_check['analysis']}{RESET}")
        return safe_check

    # ── Ollama AI — does the real thinking ────────────────────
    print(f"{CYAN}[*] Sending to Llama 3.2 for analysis...{RESET}")

    content = ""
    try:
        response = ollama.chat(
            model='llama3.2:3b',
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user",   "content": f"Analyze this call transcript: \"{transcript}\""}
            ],
            format='json',
            options={"temperature": 0.1}  # low = more consistent, less creative
        )

        content = response['message']['content'].strip()
        # Clean markdown if model gets chatty despite instructions
        content = content.replace("```json", "").replace("```", "").strip()

        result   = json.loads(content)
        status   = str(result.get("status", "safe")).lower()
        prob     = int(result.get("probability", 0))
        analysis = str(result.get("analysis", "Analysis complete."))

        # ── Enforce consistency rule in code too (double safety) ──
        if prob >= 50 and status != "scam_detected":
            print(f"{YELLOW}[!] Model contradiction fixed: prob={prob}% but said safe → overriding to scam{RESET}")
            status = "scam_detected"
        if prob < 50 and status == "scam_detected":
            print(f"{YELLOW}[!] Model contradiction fixed: prob={prob}% but said scam → overriding to safe{RESET}")
            status = "safe"

        if status == "scam_detected":
            print(f"{RED}[!] SCAM DETECTED — {prob}% — {analysis}{RESET}")
        else:
            print(f"{GREEN}[✓] SAFE — {prob}% risk — {analysis}{RESET}")

        return {"status": status, "probability": prob, "analysis": analysis}

    except json.JSONDecodeError:
        print(f"{RED}[!] JSON parse error — raw response: {content}{RESET}")
        # If JSON fails, do one more offline check then default safe
        offline = offline_keyword_check(transcript)
        if offline:
            return offline
        safe = offline_safe_check(transcript)
        if safe:
            return safe
        return {
            "status": "safe", "probability": 10,
            "analysis": "Could not parse AI response. Please re-scan."
        }
    except Exception as e:
        print(f"{RED}[!] Ollama error: {e}{RESET}")
        offline = offline_keyword_check(transcript)
        if offline:
            return offline
        safe = offline_safe_check(transcript)
        if safe:
            return safe
        return {
            "status": "safe", "probability": 10,
            "analysis": "AI temporarily unavailable. Re-scan recommended."
        }


# ─── /alert-family ────────────────────────────────────────────────────────────
@app.post("/alert-family")
async def send_family_alert(data: AlertData):
    print(f"\n{YELLOW}[!] SENDING TWILIO SMS ALERT...{RESET}")

    # Get all family numbers (comma-separated from env)
    family_numbers = data.family_phone if data.family_phone else TARGET_FAMILY_NUMBER
    numbers = [n.strip() for n in family_numbers.split(",")]
    
    short_analysis = data.analysis[:100] + "..." if len(data.analysis) > 100 else data.analysis

    sms_text = (
        f"SCAM ALERT - Grandparent Guardian\n"
        f"Risk: {data.probability}%\n"
        f"Reason: {short_analysis}\n"
        f"Transcript: {data.transcript[:80]}...\n"
        f"Action: Call them NOW!"
    )

    sent_count = 0
    failed = []
    
    try:
        client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
        
        for to_number in numbers:
            if not to_number.startswith("+"):
                to_number = f"+91{to_number}"
            
            try:
                message = client.messages.create(
                    body=sms_text,
                    from_=TWILIO_FROM_NUMBER,
                    to=to_number,
                )
                print(f"{GREEN}[✓] SMS sent to {to_number}: {message.sid}{RESET}")
                sent_count += 1
            except Exception as e:
                print(f"{RED}[!] Failed to send to {to_number}: {e}{RESET}")
                failed.append(to_number)
        
        return {
            "status": "success" if sent_count > 0 else "error",
            "sent_to": sent_count,
            "failed": failed,
            "message": f"Sent to {sent_count} family member(s)"
        }

    except Exception as e:
        print(f"{RED}[!] Twilio error: {e}{RESET}")
        return {"status": "error", "message": str(e)}


# ─── /test-sms ────────────────────────────────────────────────────────────────
@app.get("/test-sms")
async def test_sms():
    """Visit http://localhost:8000/test-sms in browser to fire a real test SMS."""
    fake = AlertData(
        transcript  = "hello OTP bhej dijiye aapka account band ho jayega",
        analysis    = "OTP scam with account block threat detected",
        probability = 99,
        family_phone= TARGET_FAMILY_NUMBER,
    )
    return await send_family_alert(fake)


# ─── /health ──────────────────────────────────────────────────────────────────
@app.get("/health")
async def health():
    return {
        "status":  "ok",
        "model":   "llama3.2:3b (Ollama)",
        "sms":     "Twilio",
        "offline": f"{len(OFFLINE_PHRASES)} safety phrases",
    }


# ─── START ────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print(f"{GREEN}{'='*55}{RESET}")
    print(f"{GREEN}  GRANDPARENT GUARDIAN AI CORE — PORT 8000{RESET}")
    print(f"{GREEN}{'='*55}{RESET}")
    print(f"{CYAN}  Model   : llama3.2:3b via Ollama{RESET}")
    print(f"{CYAN}  SMS     : Twilio → {TARGET_FAMILY_NUMBER}{RESET}")
    print(f"{CYAN}  Test    : http://localhost:8000/test-sms{RESET}")
    print(f"{CYAN}  Health  : http://localhost:8000/health{RESET}")
    print(f"{GREEN}{'='*55}{RESET}\n")
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="warning")