import sys
from pathlib import Path
p = Path('lib/ui/scheme_finder/scheme_finder_screen.dart')
text = p.read_text(encoding='utf-8')
stack = []
pairs = {'{':'}','(':')','[':']'}
openers = set(pairs.keys())
closers = set(pairs.values())
depth = 0
for i,line in enumerate(text.splitlines(), start=1):
    for ch in line:
        if ch in openers:
            stack.append((ch,i))
            depth += 1
        elif ch in closers:
            if not stack:
                print(f"Unmatched closer {ch} at line {i}")
                sys.exit(0)
            last, lnum = stack.pop()
            depth -= 1
            if pairs[last] != ch:
                print(f"Mismatched {last} at line {lnum} closed by {ch} at line {i}")
                sys.exit(0)
    if i % 20 == 0 or depth == 0:
        print(f"Line {i}: depth {depth}")
if stack:
    print('Unclosed openers:')
    for ch,ln in stack:
        print(f"{ch} opened at {ln}")
else:
    print('All braces and parentheses are matched.')
