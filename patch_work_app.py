import sys

filepath = r'C:\src\python\work_app.py'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

target = 'breaks = [(10, 0, 5), (12, 0, 45), (15, 0, 10), (18, 30, 10)]'
replacement = 'breaks = [(11, 55, 50), (15, 0, 10), (18, 30, 10)]'

if target in content:
    content = content.replace(target, replacement)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print('Replacement successful.')
else:
    print('Target not found in work_app.py.')
