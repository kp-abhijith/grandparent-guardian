import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from transformers import pipeline
import uvicorn

# Colors for terminal output
RED, GREEN, YELLOW, CYAN, RESET = '\033[91m', '\033[92m', '\033[93m', '\033[96m', '\033[0m'

print(f"{CYAN}[*] Loading Deep Intent Analysis Model...{RESET}")
# This model is specifically trained for 'Natural Language Inference' (NLI)
# It understands the relationship between a premise and a hypothesis.
classifier = pipeline("zero-shot-classification", model="MoritzLaurer/mDeBERTa-v3-base-mnli-xnli")

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

class AudioText(BaseModel):
    text: str

@app.post("/analyze")
async def analyze_text(data: AudioText):
    transcript = data.text.strip()
    print(f"\n{CYAN}===================================================={RESET}")
    print(f"{YELLOW}[+] ANALYZING INTENTION:{RESET} '{transcript}'")

    try:
        # ── INTENT HYPOTHESES ──────────────────────────────────────────
        # Instead of 'labels', we use full descriptions of 'Intent'.
        # The model will try to see which 'behavior' best describes the text.
        
        intent_scam = "The caller is actively requesting or demanding a secret OTP, a password, or a bank transfer."
        intent_warning = "The speaker is providing a safety warning or advising the listener NOT to share their codes."
        intent_safe = "A normal, harmless conversation about everyday life, school, or work."

        candidate_labels = [intent_scam, intent_warning, intent_safe]
        
        # We use multi_label=False to force the AI to pick the SINGLE most likely intention.
        # This is more accurate for 'knowing' the true purpose of the call.
        result = classifier(transcript, candidate_labels, multi_label=False)
        
        top_intent = result['labels'][0]
        confidence = int(result['scores'][0] * 100)

        # ── LOGIC BASED ON INTENT ──────────────────────────────────────
        
        # If the AI thinks the 'Intention' is a scam request:
        if top_intent == intent_scam:
            analysis = "Intention: Unauthorized data extraction (Requesting OTP/Funds)."
            print(f"{RED}[!] SCAM INTENT DETECTED — {confidence}% Certainty{RESET}")
            return {"status": "scam_detected", "analysis": analysis, "probability": confidence}

        # If the AI thinks the 'Intention' is a helpful warning:
        elif top_intent == intent_warning:
            analysis = "Intention: Proactive safety advice (Protecting the user)."
            print(f"{GREEN}[✓] SAFE INTENT (WARNING) — {confidence}% Certainty{RESET}")
            return {"status": "safe", "analysis": analysis, "probability": 10} # Low risk score

        # Otherwise, it's just a normal conversation
        else:
            analysis = "Intention: Normal social or professional interaction."
            print(f"{GREEN}[✓] SAFE INTENT (CASUAL) — {confidence}% Certainty{RESET}")
            return {"status": "safe", "analysis": analysis, "probability": 5}

    except Exception as e:
        print(f"{RED}[!] AI Error: {e}{RESET}")
        return {"status": "safe", "analysis": "Could not determine intent.", "probability": 0}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="warning")