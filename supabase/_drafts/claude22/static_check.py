#!/usr/bin/env python3
"""Static (no-database) consistency checker for the backend package. Run from backend/:  python3 tests/static_check.py
This is NOT a substitute for executing the SQL in PostgreSQL. It catches structural mistakes only."""
import re, glob, os, sys, collections
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
errors, notes = [], []
def err(m): errors.append(m)

def strip_comments(s):
    s = re.sub(r"--[^\n]*", "", s)
    return s

def split_top(s, sep=","):
    out, depth, cur, q = [], 0, "", False
    i = 0
    while i < len(s):
        ch = s[i]
        if q:
            cur += ch
            if ch == "'":
                if i + 1 < len(s) and s[i+1] == "'": cur += "'"; i += 1
                else: q = False
        elif ch == "'": q = True; cur += ch
        elif ch == "(": depth += 1; cur += ch
        elif ch == ")": depth -= 1; cur += ch
        elif ch == sep and depth == 0: out.append(cur.strip()); cur = ""
        else: cur += ch
        i += 1
    if cur.strip(): out.append(cur.strip())
    return out

def match_paren(s, start):
    depth, q, i = 0, False, start
    while i < len(s):
        ch = s[i]
        if q:
            if ch == "'":
                if i + 1 < len(s) and s[i+1] == "'": i += 1
                else: q = False
        elif ch == "'": q = True
        elif ch == "(": depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0: return i
        i += 1
    return -1

files = sorted(glob.glob(os.path.join(ROOT, "migrations", "*.sql")))
raw = {f: open(f, encoding="utf-8").read() for f in files}
for f, s in raw.items():
    c = strip_comments(s)
    if c.count("$$") % 2: err(f"{os.path.basename(f)}: unbalanced $$")
    body = re.sub(r"\$\$.*?\$\$", "", c, flags=re.S)           # ignore function bodies for paren balance
    body = re.sub(r"'(?:[^']|'')*'", "''", body)
    if body.count("(") != body.count(")"): err(f"{os.path.basename(f)}: unbalanced parentheses outside function bodies")
    # function bodies: balance of begin/end-ish and parentheses
    for m in re.finditer(r"\$\$(.*?)\$\$", c, flags=re.S):
        b = re.sub(r"'(?:[^']|'')*'", "''", m.group(1))
        if b.count("(") != b.count(")"): err(f"{os.path.basename(f)}: unbalanced parens in a function body near: {b.strip()[:60]!r}")
sql = "\n".join(strip_comments(raw[f]) for f in files)

# ---- enums
enums = {m.group(1): re.findall(r"'([^']+)'", m.group(2)) for m in re.finditer(r"create type (\w+) as enum \((.*?)\);", sql, flags=re.S)}
# ---- tables
tables = {}
for m in re.finditer(r"create table (\w+)\s*\(", sql):
    name = m.group(1); end = match_paren(sql, m.end() - 1); body = sql[m.end(): end]
    cols = {}
    for part in split_top(body):
        first = part.split()[0].lower()
        if first in ("primary", "unique", "check", "foreign", "constraint"): continue
        cols[first] = part
    tables[name] = cols
tables["auth.users"] = {"id": "uuid primary key"}
funcs = {}
for m in re.finditer(r"create function (\w+)\s*\(", sql):
    end = match_paren(sql, m.end() - 1); args = sql[m.end(): end].strip()
    funcs.setdefault(m.group(1), []).append(len(split_top(args)) if args else 0)
notes.append(f"{len(enums)} enums, {len(tables)-1} tables, {len(funcs)} functions parsed from {len(files)} migrations")

# ---- FKs
fks = []
for t, cols in tables.items():
    for c, d in cols.items():
        for m in re.finditer(r"references\s+([\w.]+)\s*\((\w+)\)", d):
            fks.append((t, c, m.group(1), m.group(2)))
    # table-level FKs not used in this schema
for (t, c, rt, rc) in fks:
    if rt not in tables: err(f"FK {t}.{c} -> missing table {rt}")
    elif rc not in tables[rt]: err(f"FK {t}.{c} -> missing column {rt}.{rc}")
# column type must be an enum or known type
for t, cols in tables.items():
    for c, d in cols.items():
        tp = d.split()[1].lower() if len(d.split()) > 1 else ""
        base = re.sub(r"\(.*", "", tp)
        known = {"uuid","text","boolean","integer","bigint","smallint","numeric","double","timestamptz","time","date","jsonb","char","bigint","text[]"}
        if base not in known and base not in enums and base != "": err(f"{t}.{c}: unknown type {tp}")
# ---- RLS
enable_list = re.search(r"foreach t in array array\[(.*?)\] loop\s+execute format\('alter table %I enable row level security'", sql, flags=re.S)
rls = set(re.findall(r"'(\w+)'", enable_list.group(1))) if enable_list else set()
for t in tables:
    if t != "auth.users" and t not in rls: err(f"table {t} does NOT have RLS enabled")
for r in rls:
    if r not in tables: err(f"RLS list names unknown table {r}")
pol = re.findall(r"create policy (\w+) on ([\w.]+) for (\w+)", sql)
for (n, t, cmd) in pol:
    if t not in tables and not t.startswith("storage."): err(f"policy {n}: unknown table {t}")
pol_tables = collections.defaultdict(set)
for (n, t, cmd) in pol: pol_tables[t].add(cmd)
# dynamic child-table policies
for t in ["provider_specialties","provider_service_areas","provider_availability","provider_services","provider_portfolio"]:
    pol_tables[t] |= {"select","insert","delete"}
# every granted-select table needs a select policy (else invisible - flag as note)
for m in re.finditer(r"grant select on (.*?) to authenticated;", sql, flags=re.S):
    for t in [x.strip() for x in m.group(1).split(",")]:
        if t not in tables: err(f"grant select on unknown table {t}")
        elif "select" not in pol_tables[t]: err(f"table {t} granted SELECT but has no select policy")
for m in re.finditer(r"grant (insert|delete|update)(?: \(.*?\))? on (.*?) to authenticated;", sql, flags=re.S):
    cmd = m.group(1)
    for t in [x.strip() for x in m.group(2).split(",")]:
        if t not in tables: err(f"grant {cmd} on unknown table {t}")
        elif cmd in pol_tables[t] or cmd == "update" and "update" in pol_tables[t]: pass
        else: err(f"grant {cmd} on {t} but no {cmd} policy exists (writes would always fail)")
# update column grants reference real columns
for m in re.finditer(r"grant update \((.*?)\) on (\w+) to authenticated", sql, flags=re.S):
    for c in [x.strip() for x in m.group(1).split(",")]:
        if c not in tables.get(m.group(2), {}): err(f"column grant {m.group(2)}.{c} does not exist")
# policies reference known helper functions
for m in re.finditer(r"\b(is_admin|is_job_party|is_job_provider|is_job_customer|provider_visible|shares_job_with|safe_uuid)\(", sql):
    if m.group(1) not in funcs: err(f"policy/helper uses undefined function {m.group(1)}")
# ---- grants on functions: name exists and arg count matches
for m in re.finditer(r"grant execute on function (.*?) to (authenticated|service_role);", sql, flags=re.S):
    for sig in re.findall(r"(\w+)\s*\(([^)]*)\)", m.group(1)):
        name, args = sig; n = len([a for a in args.split(",") if a.strip()])
        if name not in funcs: err(f"grant execute on undefined function {name}")
        elif n not in funcs[name]: err(f"grant execute {name}: {n} args but defined with {funcs[name]}")
# every RPC that is meant for clients is granted
for rpc in ["create_job","transition_job","cancel_job","create_quote","send_quote","approve_quote","reject_quote","pay_demo","complete_job","create_review","open_dispute","resolve_dispute","search_providers"]:
    if rpc not in funcs: err(f"RPC {rpc} not defined")
# SECURITY DEFINER functions must set search_path
for m in re.finditer(r"create function (\w+)\s*\(.*?\$\$", sql, flags=re.S):
    head = m.group(0)
    if "security definer" in head and "set search_path" not in head: err(f"{m.group(1)}: SECURITY DEFINER without fixed search_path")
# ---- state machine
js = enums["job_status"]
tr = re.search(r"insert into allowed_job_transitions values(.*?);", sql, flags=re.S).group(1)
edges = re.findall(r"\('(\w+)','(\w+)','(\w+)'\)", tr)
for a, b, who in edges:
    if a not in js or b not in js: err(f"transition uses unknown state {a}->{b}")
    if who not in ("customer","provider","system","admin"): err(f"transition actor {who}")
adj = collections.defaultdict(set)
for a, b, _ in edges: adj[a].add(b)
seen, stack = set(), ["REQUESTED"]
while stack:
    x = stack.pop()
    if x in seen: continue
    seen.add(x); stack.extend(adj[x])
for s_ in js:
    if s_ not in seen: err(f"state {s_} unreachable from REQUESTED")
for s_ in ("DECLINED","CANCELLED","EXPIRED"):
    if adj[s_]: err(f"terminal state {s_} has outgoing transitions")
if "IN_PROGRESS" in adj["COMPLETED"]: err("COMPLETED -> IN_PROGRESS must be forbidden")
notes.append(f"state machine: {len(edges)} (from,to,actor) rows, all 14 states reachable, terminals clean")

# ---- seed
seed_path = os.path.join(ROOT, "seed", "seed.sql")
seed = strip_comments(open(seed_path, encoding="utf-8").read())
def parse_rows(vals):
    rows = []; i = 0
    for part in split_top(vals):
        part = part.strip()
        assert part[0] == "(" and part[-1] == ")", part[:40]
        rows.append([x.strip() for x in split_top(part[1:-1])])
    return rows
def unq(v): return v[1:-1].replace("''", "'") if v.startswith("'") else v
seed_ids = collections.defaultdict(set); seed_data = {}
inserted_tables = set()
for m in re.finditer(r"insert into ([\w.]+) \((.*?)\) values\s*(.*?);\n", seed, flags=re.S):
    t = m.group(1); cols = [c.strip() for c in m.group(2).split(",")]; rows = parse_rows(m.group(3))
    inserted_tables.add(t)
    if t not in tables: err(f"seed inserts into unknown table {t}"); continue
    if t != "auth.users":
        for c in cols:
            if c not in tables[t]: err(f"seed {t}: unknown column {c}")
            elif "generated always" in tables[t][c]: err(f"seed {t}.{c}: cannot insert into generated/identity column")
        for c, d in tables[t].items():
            dl = d.lower()
            if "not null" in dl and "default" not in dl and "generated" not in dl and "primary key" not in dl and c not in cols:
                err(f"seed {t}: missing NOT NULL column {c} (no default)")
    for r in rows:
        if len(r) != len(cols): err(f"seed {t}: row has {len(r)} values for {len(cols)} columns: {r[:2]}")
    seed_data[t] = (cols, rows)
    for r in rows:
        for c, v in zip(cols, r):
            seed_ids[(t, c)].add(unq(v))
            tp = tables[t].get(c, "").split()[1].lower() if t in tables and c in tables[t] and len(tables[t][c].split()) > 1 else ""
            tp = re.sub(r"\(.*", "", tp)
            if tp in enums and v != "NULL" and unq(v) not in enums[tp]: err(f"seed {t}.{c}: '{unq(v)}' not in enum {tp}")
# phone / slug regex checks
for r in seed_data["profiles"][1]:
    ph = unq(r[seed_data["profiles"][0].index("phone")])
    if not re.match(r"^\+9627[789][0-9]{7}$", ph): err(f"seed phone invalid: {ph}")
# FK integrity within seed
for (t, c, rt, rc) in fks:
    if t in seed_data and c in seed_data[t][0]:
        for v in seed_ids[(t, c)]:
            if v == "NULL": continue
            if v not in seed_ids[(rt, rc)]: err(f"seed FK {t}.{c}={v} not found in {rt}.{rc}")
# seed state history obeys the matrix
cols, rows = seed_data["job_status_history"]
ix = {c: cols.index(c) for c in cols}
tset = {(a, b, w) for a, b, w in edges}
for r in rows:
    fr, to, actor = unq(r[ix["from_status"]]), unq(r[ix["to_status"]]), unq(r[ix["actor_role"]])
    if fr != "NULL" and (fr, to, actor) not in tset: err(f"seed history transition not in matrix: {fr}->{to} by {actor}")
# final job status equals last history status
last = {}
for r in rows: last[unq(r[ix["job_id"]])] = unq(r[ix["to_status"]])
jc, jr = seed_data["jobs"]
for r in jr:
    if last[unq(r[jc.index("id")])] != unq(r[jc.index("status")]): err(f"seed job {unq(r[0])} status != last history status")
notes.append(f"seed: {sum(len(v[1]) for v in seed_data.values())} rows across {len(seed_data)} tables; FK integrity, enums, NOT NULL, history-vs-matrix OK" if not errors else "seed parsed")
print("\n".join("INFO  " + n for n in notes))
if errors:
    print("\n".join("ERROR " + e for e in errors)); print(f"\nFAILED: {len(errors)} problem(s)"); sys.exit(1)
print("PASSED: static structural checks (this does NOT prove the SQL executes)")
