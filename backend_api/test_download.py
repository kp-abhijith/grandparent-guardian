from transformers import pipeline
import logging

# This forces the terminal to show you exactly what it's downloading or failing at
logging.basicConfig(level=logging.INFO)

print("Attempting to connect to Hugging Face and download mDeBERTa...")
try:
    classifier = pipeline("zero-shot-classification", model="MoritzLaurer/mDeBERTa-v3-base-mnli-xnli")
    print("\nSUCCESS! The model is downloaded and ready to use.")
except Exception as e:
    print(f"\nFAILED! Here is the exact error stopping the download:\n{e}")