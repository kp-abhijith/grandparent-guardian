import os
import time
import json
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import google.generativeai as genai
from dotenv import load_dotenv
import uvicorn

# --- ANSI Colors for Hackathon Aesthetics ---
RED = '\033[91m'
GREEN = '\033[92m'
YELLOW = '\033[93m'
CYAN = '\033[96m'
RESET = '\033[0m'

# 1. Load Secrets & Initialize AI
load_dotenv()
api_key = os.getenv("GEMINI_API_KEY")

if not api_key:
    print(f"{RED}[ERROR] GEMINI_API_KEY not found in .env file!{RESET}")

genai.configure(api_key=api_key)
model = genai.GenerativeModel('gemini-1.5-flash-latest')

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 2. Define Expected Data
class AudioText(BaseModel):
    text: str

# 3. The Core API Endpoint
@app.post("/analyze")
async def analyze_text(data: AudioText):
    transcript = data.text
    
    print(f"\n{CYAN}===================================================={RESET}")
    print(f"{YELLOW}[+] INCOMING CALL INTERCEPTED:{RESET} '{transcript}'")
    print(f"{CYAN}[*] Running AI Intent Analysis...{RESET}")
    
    prompt = f"""
    You are an elite cyber-security AI protecting an elderly user in India from phone scams.
    Analyze this phone transcript: "{transcript}"
    
    CRITICAL RULES:
    1. Look for definitive manipulation: false urgency (e.g., "pay now or get arrested"), financial extraction (e.g., "share OTP", "transfer funds"), or remote access tools ("AnyDesk" or "TeamViewer").
    2. Context Matters: If the caller is just mentioning a bank casually (e.g., "I went to the bank today"), it is SAFE.
    3. Warnings: If the speaker is warning the user about scams (e.g., "don't share your OTP"), it is SAFE.
    
    Return your analysis STRICTLY as a raw JSON object with NO markdown formatting, NO backticks, and exactly these three keys:
    "threat_level": "High" or "Low"
    "tactic": "One short sentence explaining why"
    "scam_probability": an integer from 0 to 100
    """
    
    time.sleep(0.5) # Dramatic pause for terminal effect
    
    try:
        # Call the Gemini AI
        response = model.generate_content(prompt)
        
        # Parse JSON output
        try:
            # Clean up potential markdown formatting if the AI disobeys
            raw_text = response.text.replace("```json", "").replace("```", "").strip()
            ai_data = json.loads(raw_text)
            threat_level = str(ai_data.get("threat_level", ai_data.get("THREAT_LEVEL", "Low"))).lower()
            ai_analysis = str(ai_data.get("tactic", ai_data.get("TACTIC", "Unknown tactic")))
            
            prob_raw = ai_data.get("scam_probability", ai_data.get("SCAM_PROBABILITY", 0))
            try:
                scam_prob = int(prob_raw)
            except (ValueError, TypeError):
                scam_prob = 85 if "high" in threat_level else 5
                
        except json.JSONDecodeError:
            # Failsafe if JSON parsing fails
            threat_level = "low"
            if "high" in response.text.lower():
                 threat_level = "high"
            ai_analysis = "Fallback: Could not parse AI JSON output."
            scam_prob = 85 if threat_level == "high" else 5
            
        if "high" in threat_level:
            print(f"{RED}[!] SCAM DETECTED [!]{RESET}")
            print(f"{RED}{ai_analysis} ({scam_prob}% Risk){RESET}")
            print(f"{CYAN}===================================================={RESET}\n")
            return {"status": "scam_detected", "analysis": ai_analysis, "probability": scam_prob}
        else:
            print(f"{GREEN}[✓] CALL AUTHORIZED: No malicious intent detected.{RESET}")
            print(f"{CYAN}===================================================={RESET}\n")
            return {"status": "safe", "analysis": ai_analysis, "probability": scam_prob}
            
    except Exception as e:
        # FAILSAFE: If API fails or Wi-Fi drops, use offline keywords
        print(f"{RED}[!] AI API ERROR: {e}{RESET}")
        print(f"{RED}[!] FALLING BACK TO OFFLINE PHRASES.{RESET}")
        OFFLINE_PHRASES = [
            "share otp", "download anydesk", "account blocked urgent", 
            "pay customs", "digital arrest", "send money urgently", 
            "police verification fee", "fedex parcel seized",
            "teamviewer", "anydesk"
        ]
        detected = [w for w in OFFLINE_PHRASES if w in transcript.lower()]
        
        if detected:
            fallback_msg = f"Offline phrase match: {detected}"
            print(f"{RED}[!] SCAM DETECTED (OFFLINE) [!]{RESET}")
            print(f"{CYAN}===================================================={RESET}\n")
            return {"status": "scam_detected", "analysis": fallback_msg, "probability": 99}
            
        print(f"{GREEN}[✓] CALL AUTHORIZED (OFFLINE).{RESET}")
        print(f"{CYAN}===================================================={RESET}\n")
        return {"status": "safe", "analysis": "Passed offline checks.", "probability": 5}

if __name__ == "__main__":
    print(f"{GREEN}🚀 GRANDPARENT GUARDIAN AI CORE ONLINE. LISTENING ON PORT 8000...{RESET}")
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="warning")