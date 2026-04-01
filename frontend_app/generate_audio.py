import wave
import math
import struct
import os

def generate_tone(filename, frequency, duration, volume=0.5, sample_rate=44100):
    num_samples = int(sample_rate * duration)
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        
        for i in range(num_samples):
            # create a sine wave
            value = int(volume * 32767.0 * math.sin(2.0 * math.pi * frequency * i / sample_rate))
            data = struct.pack('<h', value)
            wav_file.writeframesraw(data)

def create_ringtone(filepath):
    # A simple UK/European style double ring
    sample_rate = 44100
    with wave.open(filepath, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        
        def write_tone(freq, dur, vol=1.0):
            samples = int(sample_rate * dur)
            for i in range(samples):
                val = int(vol * 32767.0 * math.sin(2.0 * math.pi * freq * i / sample_rate))
                wav_file.writeframesraw(struct.pack('<h', val))
                
        def write_silence(dur):
            samples = int(sample_rate * dur)
            for i in range(samples):
                wav_file.writeframesraw(struct.pack('<h', 0))

        # Ring sequence: Ring(0.4s) - Silence(0.2s) - Ring(0.4s) - Silence(2.0s)
        for _ in range(2):
            write_tone(400, 0.4)
            write_tone(450, 0.4) # Add harmony
            write_silence(0.2)
            write_tone(400, 0.4)
            write_tone(450, 0.4)
            write_silence(2.0)

def create_warning(filepath):
    # A high pitched siren alternating
    sample_rate = 44100
    with wave.open(filepath, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        
        def write_tone(freq, dur, vol=0.5):
            samples = int(sample_rate * dur)
            for i in range(samples):
                val = int(vol * 32767.0 * math.sin(2.0 * math.pi * freq * i / sample_rate))
                wav_file.writeframesraw(struct.pack('<h', val))
                
        for _ in range(3):
            write_tone(800, 0.5)
            write_tone(600, 0.5)

if __name__ == '__main__':
    os.makedirs('assets', exist_ok=True)
    create_ringtone('assets/ringtone.wav')
    create_warning('assets/warning.wav')
    print("Audio files generated successfully in assets/ directory.")
