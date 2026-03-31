import os
import time
from fastapi import FastAPI
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
model = genai.GenerativeModel('gemini-1.5-flash')

app = FastAPI()

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
    You are an elite cyber-security AI protecting an elderly user in India. 
    Analyze this phone transcript. The transcript may be in English, Hindi, or Hinglish.
    Understand the cultural context of scams (like fake police, CBI, or OTP bank frauds).
    Look for emotional manipulation, false urgency, or financial demands.
    Transcript: "{transcript}"
    
    Respond STRICTLY in English in this exact format:
    THREAT_LEVEL: (High or Low)
    TACTIC: (One short sentence explaining the psychological trick being used)
    """
    
    time.sleep(0.5) # Dramatic pause for terminal effect
    
    try:
        # Call the Gemini AI
        response = model.generate_content(prompt)
        ai_analysis = response.text.strip()
        
        if "THREAT_LEVEL: High" in ai_analysis:
            print(f"{RED}[!] SCAM DETECTED [!]{RESET}")
            print(f"{RED}{ai_analysis}{RESET}")
            print(f"{CYAN}===================================================={RESET}\n")
            return {"status": "scam_detected", "analysis": ai_analysis}
        else:
            print(f"{GREEN}[✓] CALL AUTHORIZED: No malicious intent detected.{RESET}")
            print(f"{CYAN}===================================================={RESET}\n")
            return {"status": "safe", "analysis": ai_analysis}
            
    except Exception as e:
        # FAILSAFE: If API fails or Wi-Fi drops, use offline keywords
        print(f"{RED}[!] AI API ERROR. FALLING BACK TO OFFLINE KEYWORDS.{RESET}")
        OFFLINE_KEYWORDS = ["otp", "bank", "police", "arrest", "urgent", "anydesk", "fedex"]
        detected = [w for w in OFFLINE_KEYWORDS if w in transcript.lower()]
        
        if detected:
            fallback_msg = f"THREAT_LEVEL: High\nTACTIC: Offline keyword match {detected}"
            print(f"{RED}[!] SCAM DETECTED (OFFLINE) [!]{RESET}")
            print(f"{CYAN}===================================================={RESET}\n")
            return {"status": "scam_detected", "analysis": fallback_msg}
            
        print(f"{GREEN}[✓] CALL AUTHORIZED (OFFLINE).{RESET}")
        print(f"{CYAN}===================================================={RESET}\n")
        return {"status": "safe", "analysis": "THREAT_LEVEL: Low\nTACTIC: Passed offline checks."}

if __name__ == "__main__":
    print(f"{GREEN}🚀 GRANDPARENT GUARDIAN AI CORE ONLINE. LISTENING ON PORT 8000...{RESET}")
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="warning")