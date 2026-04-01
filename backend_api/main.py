import os
import json
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import ollama

# Colors for terminal output
RED, GREEN, YELLOW, CYAN, RESET = '\033[91m', '\033[92m', '\033[93m', '\033[96m', '\033[0m'

print(f"{CYAN}[*] Starting Grandparent Guardian AI (Ollama + Llama 3.2 3B)...{RESET}")

app = FastAPI(title="Grandparent Guardian - Smart Scam Detector")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

class AudioText(BaseModel):
    text: str

@app.post("/analyze")
async def analyze_text(data: AudioText):
    transcript = data.text.strip()
    print(f"\n{CYAN}===================================================={RESET}")
    print(f"{YELLOW}[+] ANALYZING TRANSCRIPT:{RESET} '{transcript}'")

    # ── SUPER SMART SYSTEM PROMPT (Hindi + English + Hinglish) ─────────────────────
    system_prompt = """
    You are an expert Indian scam detector protecting grandparents.
    Analyze the call transcript and detect if it is a scam or safe.

    Common scam tactics (catch these even in Hindi or Hinglish):
    - Asking for OTP, bank details, UPI, password, or "confirm payment"
    - Creating urgency ("abhi kar do warna account block ho jayega")
    - Impersonating bank, police, government, Amazon, IRCTC, tech support
    - Offering loan, prize, refund, or "free gift"
    - Emotional manipulation or threats
    - Any request for money or personal information
    - Official student surveys or simple greetings are SAFE.

    Respond ONLY with a valid JSON object in this exact format:
    {
      "status": "scam_detected" or "safe",
      "probability": integer between 0 and 100,
      "analysis": "1 short simple explanation in easy Hindi or English"
    }
    """

    try:
        # SENIOR FIX 1: Added format='json' and lowered temperature to 0.1 for strict logic
        response = ollama.chat(
            model='llama3.2:3b',
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": f"Call transcript: {transcript}"}
            ],
            format='json',
            options={"temperature": 0.1}
        )

        content = response['message']['content'].strip()
        
        # SENIOR FIX 2: Markdown stripper. LLMs sometimes wrap JSON in backticks.
        if content.startswith("```json"):
            content = content.replace("```json", "").replace("```", "").strip()

        result = json.loads(content)

        # SENIOR FIX 3: Safe dictionary extraction. Prevents crashes if the AI misnames a key.
        status = result.get("status", "safe")
        prob = int(result.get("probability", 0))
        analysis = result.get("analysis", "Analysis complete.")

        if status == "scam_detected":
            print(f"{RED}[!] SCAM DETECTED — {analysis} ({prob}%){RESET}")
        else:
            print(f"{GREEN}[✓] SAFE CALL — {analysis} ({prob}%){RESET}")
            
        print(f"{CYAN}===================================================={RESET}\n")

        # Return the safely parsed variables directly to Flutter
        return {"status": status, "probability": prob, "analysis": analysis}

    except Exception as e:
        print(f"{RED}[!] AI Error: {e}{RESET}")
        return {
            "status": "safe",
            "probability": 0,
            "analysis": "System error during analysis."
        }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="warning")