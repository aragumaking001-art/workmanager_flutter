import codecs

with codecs.open(r'C:\src\python\generate_model_name_card.py', 'r', 'utf-8') as f:
    content = f.read()

# 既にラップされているかチェック（もしラップされていればスキップ）
if "import traceback" not in content[:100]:
    new_content = 'import traceback\nimport sys\n\ntry:\n'
    for line in content.split('\n'):
        new_content += '    ' + line + '\n'

    new_content += '''
except Exception as e:
    print("\\n【重大なエラーが発生しました】")
    traceback.print_exc()
    input("\\nエラー内容を確認したら、Enterキーを押して終了してください...")
'''
    with codecs.open(r'C:\src\python\generate_model_name_card.py', 'w', 'utf-8') as f:
        f.write(new_content)
    print('File updated.')
else:
    print('Already updated.')
