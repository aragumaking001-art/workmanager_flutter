import sys

file_path = r"C:\src\python\work_app.py"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

old_code = """        try:
            sound_name = "success.wav"
            if globals().get('ENABLE_RANDOM_SUCCESS_SOUND', True):
                r = random.random()
                if r < 0.7:
                    sound_name = "success.wav"
                elif r < 0.9:
                    sound_name = "success2.wav"
                else:
                    sound_name = "success3.wav"
            
            sound_path = os.path.join("assets", sound_name)
            winsound.PlaySound(sound_path, winsound.SND_FILENAME | winsound.SND_ASYNC)
        except: pass"""

new_code = """        try:
            sound_name = "success.wav"
            worker_id = self.my_worker_id if hasattr(self, 'my_worker_id') else ""
            worker_sound_path = os.path.join("assets", f"{worker_id}.wav")
            worker_a_sound_path = os.path.join("assets", f"{worker_id}_a.wav")
            
            if worker_id and os.path.exists(worker_sound_path):
                sound_name = f"{worker_id}.wav"
                if os.path.exists(worker_a_sound_path) and random.random() < 0.1:
                    sound_name = f"{worker_id}_a.wav"
            else:
                if globals().get('ENABLE_RANDOM_SUCCESS_SOUND', True):
                    r = random.random()
                    if r < 0.7:
                        sound_name = "success.wav"
                    elif r < 0.9:
                        sound_name = "success2.wav"
                    else:
                        sound_name = "success3.wav"
            
            sound_path = os.path.join("assets", sound_name)
            winsound.PlaySound(sound_path, winsound.SND_FILENAME | winsound.SND_ASYNC)
        except: pass"""

if old_code in content:
    content = content.replace(old_code, new_code)
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Patch applied successfully.")
else:
    print("Could not find the old code block in work_app.py.")
