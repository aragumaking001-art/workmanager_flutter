import codecs
import os

target_file = r'C:\Users\yamada\.gemini\antigravity-ide\scratch\workmanager_flutter\python_apps\work_app.py'

with codecs.open(target_file, 'r', 'utf-8') as f:
    content = f.read()

import_section = "import threading"
if "ENABLE_RANDOM_SUCCESS_SOUND" not in content:
    content = content.replace(import_section, import_section + '\n\n# --- 効果音の設宁E---\n# ランダム再生をオフにして、常に success.wav だけを鳴らす場合�EここめEFalse に変更します\nENABLE_RANDOM_SUCCESS_SOUND = True\n')

old_sound_code = '''        try:
            sound_path = os.path.join("assets", "success.wav")
            winsound.PlaySound(sound_path, winsound.SND_FILENAME | winsound.SND_ASYNC)
        except: pass'''

new_sound_code = '''        try:
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
        except: pass'''

content = content.replace(old_sound_code, new_sound_code)

with codecs.open(target_file, 'w', 'utf-8') as f:
    f.write(content)
print("Done")
