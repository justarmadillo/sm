"""Reports where lib/ departs from RULES.md.

Run from the repository root:

    python tool/audit_rules.py

Every check is a heuristic over the text of the files, not a compiler. It finds
candidates; you still have to read each one and decide. Two of its rules are
deliberately budgeted rather than empty (the over-budget functions of section 6
and the positional parameters of section 3), so a clean run is not the goal --
a run whose numbers never rise is.
"""
import os
import re

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

FILES = []
for base in ('lib',):
    for root, dirs, files in os.walk(base):
        for f in sorted(files):
            if f.endswith('.dart') and not f.endswith('.g.dart'):
                FILES.append(os.path.join(root, f).replace(os.sep, '/'))

SRC = {p: open(p, encoding='utf-8', errors='replace').read() for p in FILES}


def strip_comments(text):
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    return '\n'.join(
        '' if re.match(r'\s*///?', l) else l for l in text.split('\n'))


HEAD = re.compile(
    r'^(?P<indent>[ ]*)'
    r'(?:@override\s+)?'
    r'(?:(?:static|external|factory)\s+)*'
    r'(?P<type>[A-Za-z_][A-Za-z0-9_]*)')


def skip_generic(text, i):
    """If text[i] starts a <...> group, return the index just past it."""
    if i >= len(text) or text[i] != '<':
        return i
    depth = 0
    while i < len(text):
        if text[i] == '<':
            depth += 1
        elif text[i] == '>':
            depth -= 1
            if depth == 0:
                return i + 1
        elif text[i] in ';{}' or text[i] == chr(10):
            return None
        i += 1
    return None


KEYWORDS = {
    'return', 'if', 'for', 'while', 'switch', 'await', 'yield', 'throw',
    'new', 'const', 'final', 'var', 'else', 'case', 'do', 'try', 'catch',
    'in', 'is', 'as', 'assert', 'super', 'this', 'rethrow', 'late', 'when',
}

PARAM = re.compile(
    r'^(?:covariant\s+)?(?:required\s+)?'
    r'(?:(?:this|super)\.\w+$'
    r'|[\w<>,\[\]\?\. ]+\s+\w+$'
    r'|[\w<>,\[\]\?\. ]+\s+Function\b.*$)')


def param_list(text, open_paren_index):
    """Substring between the paren at open_paren_index and its match."""
    depth = 0
    i = open_paren_index
    while i < len(text):
        c = text[i]
        if c in '([{':
            depth += 1
        elif c in ')]}':
            depth -= 1
            if depth == 0:
                return text[open_paren_index + 1:i], i
        i += 1
    return None, None


def split_top(text):
    depth = 0
    parts = []
    cur = ''
    for c in text:
        if c in '([{<':
            depth += 1
        elif c in ')]}>':
            depth -= 1
        if c == ',' and depth == 0:
            parts.append(cur)
            cur = ''
        else:
            cur += c
    if cur.strip():
        parts.append(cur)
    return [p for p in parts if p.strip()]


def declarations():
    """Yield (path, line, name, positional_count, has_named)."""
    for p, raw in SRC.items():
        text = strip_comments(raw)
        all_lines = text.split(chr(10))
        offsets = []
        running = 0
        for one in all_lines:
            offsets.append(running)
            running += len(one) + 1
        for line_no, line in enumerate(all_lines, start=1):
            m = HEAD.match(line)
            if not m:
                continue
            i = offsets[line_no - 1] + m.end()
            i2 = skip_generic(text, i)
            if i2 is None:
                continue
            i = i2
            if i < len(text) and text[i] == '?':
                i += 1
            j = i
            while j < len(text) and text[j] == ' ':
                j += 1
            if j == i:
                continue
            name_match = re.match(r'[a-zA-Z_][A-Za-z0-9_]*', text[j:])
            if not name_match:
                continue
            name = name_match.group(0)
            k = j + name_match.end()
            k2 = skip_generic(text, k)
            if k2 is None:
                continue
            k = k2
            if k >= len(text) or text[k] != '(':
                continue
            params, close = param_list(text, k)
            if params is None:
                continue
            after = text[close + 1:close + 40].lstrip()
            if not (after.startswith('{') or after.startswith('=>')
                    or after.startswith('async') or after.startswith('sync')
                    or after.startswith(';') or after.startswith('=')):
                continue
            if m.group('type') in KEYWORDS:
                continue
            named = '{' in params or '[' in params
            positional = params.split('{')[0].split('[')[0]
            parts = split_top(positional)
            # A call's arguments carry `name:` or are bare expressions; a
            # declaration's carry a type, or `this.`/`super.`/`required`.
            if any(':' in part for part in parts):
                continue
            if parts and not all(PARAM.match(part.strip()) for part in parts):
                continue
            yield p, line_no, name, len(parts), named


def head(title):
    print()
    print('=' * 72)
    print(title)
    print('=' * 72)


total = 0


def report(rows, fmt):
    global total
    if not rows:
        print('  clean')
        return
    total += len(rows)
    for r in rows[:40]:
        print('  ' + fmt(r))
    if len(rows) > 40:
        print(f'  ... and {len(rows) - 40} more')


# ---------------------------------------------------------------- rule 3
head('RULE 3 - three or more parameters means named parameters')
rows = [(p, ln, n, c) for p, ln, n, c, _ in declarations() if c >= 3]
rows.sort(key=lambda r: -r[3])
report(rows, lambda r: f'{r[3]} positional  {r[0]}:{r[1]}  {r[2]}')

head('RULE 3 - forbidden verbs (get/fetch/load/store/write/put) declared here')
rows = []
for p, ln, n, c, _ in declarations():
    if re.match(r'^_?(get|fetch|load|store|put)[A-Z]', n):
        rows.append((p, ln, n))
report(rows, lambda r: f'{r[0]}:{r[1]}  {r[2]}')

head('RULE 3 - vague words in declared names')
VAGUE = r'^_?(data|item|info|handle|process|manager|util|helper|temp|thing|obj)$'
rows = []
for p, ln, n, c, _ in declarations():
    if re.match(VAGUE, n, re.I):
        rows.append((p, ln, n))
report(rows, lambda r: f'{r[0]}:{r[1]}  {r[2]}')

head('RULE 3 - "And" in a declared name (compareAndSwap excepted)')
rows = []
for p, ln, n, c, _ in declarations():
    if re.search(r'[a-z]And[A-Z]', n) and not n.startswith('compareAndSwap'):
        rows.append((p, ln, n))
report(rows, lambda r: f'{r[0]}:{r[1]}  {r[2]}')

# ---------------------------------------------------------------- rule 6
head('RULE 6 - function length')


def function_lengths():
    """(lines, path, line, name) for every declaration, longest first."""
    out = []
    for p, line_no, name, count, named in declarations():
        src = SRC[p].split(chr(10))
        depth = 0
        started = False
        end = None
        for j in range(line_no - 1, min(line_no + 400, len(src))):
            depth += src[j].count('{') - src[j].count('}')
            if '{' in src[j]:
                started = True
            if started and depth <= 0:
                end = j
                break
            if not started and src[j].rstrip().endswith(';'):
                end = j
                break
        if end is not None:
            out.append((end - line_no + 2, p, line_no, name))
    out.sort(reverse=True)
    return out


measured = function_lengths()
spans = sorted(n for n, _, _, _ in measured)
median = spans[len(spans) // 2]
print(f'  functions measured  {len(spans)}')
print(f'  median function     {median} lines')
for limit in (60, 100, 200):
    over = sum(1 for n in spans if n > limit)
    print(f'  over {limit:3} lines      {over:4}  ({over / len(spans) * 100:.1f}%)')
print('  over 150 lines, longest first (the over-budget list):')
for n, p, ln, name in measured:
    if n > 150:
        print(f'    {n:4}  {p}:{ln}  {name}')

# ---------------------------------------------------------------- rule 5
head('RULE 5 - every file opens with a doc comment')
rows = []
for p, raw in SRC.items():
    first = next((l for l in raw.split('\n') if l.strip()), '')
    if not first.startswith('///'):
        rows.append((p, first[:50]))
report(rows, lambda r: f'{r[0]}   starts: {r[1]!r}')

# ---------------------------------------------------------------- rule 7
head('RULE 7 - DateTime.now() must never be read directly')
rows = []
for p, raw in SRC.items():
    for i, l in enumerate(strip_comments(raw).split('\n')):
        if 'DateTime.now()' in l and not p.endswith('clock.dart'):
            rows.append((p, i + 1, l.strip()[:60]))
report(rows, lambda r: f'{r[0]}:{r[1]}  {r[2]}')

head('RULE 7 - ids must come from an IdGenerator')
rows = []
for p, raw in SRC.items():
    if p.endswith('id_generator.dart'):
        continue
    for i, l in enumerate(strip_comments(raw).split('\n')):
        if re.search(r'Uuid\(|Random\(\)\.next|DateTime\.now\(\)\.millisecondsSinceEpoch\.toString', l):
            rows.append((p, i + 1, l.strip()[:60]))
report(rows, lambda r: f'{r[0]}:{r[1]}  {r[2]}')

# ---------------------------------------------------------------- rule 11
head('RULE 11 - command runners must not hand-roll the failure boundary')
rows = []
for p, raw in SRC.items():
    if not p.endswith('_command_runner.dart'):
        continue
    text = strip_comments(raw)
    uses_shared = 'executeCommand<' in text
    handrolled = len(re.findall(r'_transactions\.run<', text))
    if handrolled and not uses_shared:
        rows.append((p, handrolled, 'no executeCommand at all'))
    elif handrolled > 1 and uses_shared:
        rows.append((p, handrolled, 'both shared and hand-rolled'))
report(rows, lambda r: f'{r[0]}  {r[1]} direct transaction(s) - {r[2]}')

head('RULE 11 - UnexpectedFailure built by hand instead of recordCommandException')
rows = []
for p, raw in SRC.items():
    if p.endswith('command_execution.dart') or p.endswith('shared/result.dart'):
        continue
    for i, l in enumerate(strip_comments(raw).split('\n')):
        if 'UnexpectedFailure(' in l:
            rows.append((p, i + 1, l.strip()[:60]))
report(rows, lambda r: f'{r[0]}:{r[1]}  {r[2]}')

head('RULE 11 - a swallowed error with no comment saying why')
rows = []
for p, raw in SRC.items():
    # Checked on the raw text: a body holding only a comment is compliant,
    # and stripping comments first is what made every one of them look empty.
    for m in re.finditer(r'(?:catch\s*\([^)]*\)|on\s+[\w<>]+)\s*\{([^{}]*)\}',
                         raw):
        body = m.group(1)
        if body.strip():
            continue
        rows.append((p, raw[:m.start()].count('\n') + 1))
report(rows, lambda r: f'{r[0]}:{r[1]}')

# ---------------------------------------------------------------- rule 12
head('RULE 12 - every enum-index column needs a CHECK')
tables = open('lib/storage/database/tables.dart', encoding='utf-8').read()
rows = []
ENUMISH = re.compile(
    r'^(type|status|state|mode|platform|lifecycle|elementType|'
    r'parentElementType|provenanceState|legacyDueProvenance)$')
for block in re.split(r'\nclass ', tables):
    name = block.split(' ')[0] if block else ''
    for m in re.finditer(r'IntColumn get (\w+) =>((?:.|\n)*?)\(\)\;', block):
        col, body = m.group(1), m.group(2)
        if not ENUMISH.match(col):
            continue
        if '.check(' in body or '.isIn(' in body:
            continue
        # A column may go without one if the doc comment says why, as the two
        # log columns do: a log row outlives the element it names.
        preceding = block[:m.start()].rstrip().split(chr(10))
        documented = any(
            'deliberately without a `CHECK`' in line
            for line in preceding[-8:])
        if documented:
            continue
        rows.append((name, col, 'nullable' if 'nullable()' in body else 'NOT NULL'))
report(rows, lambda r: f'{r[0]}.{r[1]}  ({r[2]})  no CHECK')

# ---------------------------------------------------------------- rule 2
head('RULE 2 - a _query.dart must not write')
WRITES = re.compile(
    r'\.(insert|update|save|append|delete)[A-Z]\w*\(|runDailyAdmission|'
    r'saveRuntimeState|advanceGeneration')
rows = []
for p, raw in SRC.items():
    if not p.endswith('_query.dart'):
        continue
    for i, l in enumerate(strip_comments(raw).split('\n')):
        if WRITES.search(l):
            rows.append((p, i + 1, l.strip()[:60]))
report(rows, lambda r: f'{r[0]}:{r[1]}  {r[2]}')

print()
print('=' * 72)
print(f'TOTAL FLAGGED: {total}')
