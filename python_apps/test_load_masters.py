import sys
import os
sys.path.append('C:/src/python')
from work_app import WorkApp

# Create a dummy page to pass to WorkApp
class DummyPage:
    def __init__(self):
        self.fonts = {}
        self.window = type('obj', (object,), {'width': 0, 'height': 0, 'title_bar_hidden': False, 'frameless': False, 'prevent_close': False})()
        self.snack_bar = None
    def add(self, *args): pass
    def update(self): pass
    def on_window_event(self, *args): pass
    def on_keyboard_event(self, *args): pass

try:
    os.chdir('C:/src/python')
    app = WorkApp(DummyPage())
    app.load_masters()
    print(f"Loaded members from DB: {len(app.members)} members")
    for i, (k, v) in enumerate(app.members.items()):
        print(f"ID: {k}, Name: {v}")
        if i >= 2: break
except Exception as e:
    import traceback
    traceback.print_exc()
