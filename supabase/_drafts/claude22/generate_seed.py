#!/usr/bin/env python3
"""Generates seed/seed.sql deterministically (fixed UUIDs, fixed timestamps) and asserts money/state consistency.
Run:  python3 tools/generate_seed.py   (from backend/)   -> writes seed/seed.sql
DEV/DEMO ONLY. All people, phones, emails and addresses are FICTIONAL. Never run against production."""
from decimal import Decimal as D, ROUND_HALF_UP
from datetime import datetime, timedelta
import os

def u(prefix, n): return f"{prefix}-0000-4000-8000-{n:012d}"
def q3(x): return x.quantize(D("0.001"), rounding=ROUND_HALF_UP)
def lit(v):
    if v is None: return "NULL"
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, (int, D)): return str(v)
    if isinstance(v, float): return repr(v)
    if isinstance(v, datetime): return f"'{v.strftime('%Y-%m-%d %H:%M:%S')}+03'"
    return "'" + str(v).replace("'", "''") + "'"
def ins(table, cols, rows):
    out = [f"insert into {table} ({', '.join(cols)}) values"]
    out.append(",\n".join("  (" + ", ".join(lit(x) for x in r) + ")" for r in rows) + ";")
    return "\n".join(out)

P_CUST, P_PROV, P_ADMIN, CAT, SVC, JOB = "a0000000", "a0000000", "a0000000", "c0000000", "d0000000", "b0000000"
C = {i: u("a0000000", i) for i in (1, 2, 3, 4)}            # customers
P = {i: u("a0000000", 10 + i) for i in range(1, 8)}         # providers 11..17 (P7 is PENDING verification)
ADMIN = u("a0000000", 21)

customers = {
 1: ("Layla Haddad",  "+962790000001", "amman", "Abdoun",          "Fictional Street 12, Abdoun, Amman",          31.9515, 35.8840),
 2: ("Omar Nasser",   "+962790000002", "amman", "Sweifieh",        "Fictional Building 5, Sweifieh, Amman",       31.9585, 35.8670),
 3: ("Rana Khoury",   "+962790000003", "amman", "Jubeiha",         "Fictional Lane 8, Jubeiha, Amman",            32.0120, 35.8750),
 4: ("Yousef Barakat","+962790000004", "irbid", "University Street","Fictional Block 3, University Street, Irbid", 32.5390, 35.8570),
}
providers = {
 1: ("Khaled Mansour",     "+962791000001", "amman", 31.9570, 35.8640, 12, "Licensed plumber focused on leaks, drains and water heaters.",            "approved"),
 2: ("Sami Tamimi",        "+962791000002", "amman", 31.9780, 35.8480, 9,  "Residential electrician: faults, sockets and lighting installs.",        "approved"),
 3: ("Tariq Zoubi",        "+962791000003", "amman", 32.0150, 35.8720, 7,  "Air-conditioning repair and seasonal maintenance technician.",           "approved"),
 4: ("Hanan Salem",        "+962791000004", "amman", 31.9490, 35.8800, 5,  "Home deep-cleaning team lead; equipment and supplies included.",       "approved"),
 5: ("Fadi Rawashdeh",     "+962791000005", "irbid", 32.5560, 35.8500, 10, "Plumbing and electrical repairs across Irbid.",                         "approved"),
 6: ("Mahmoud Bani Hani",  "+962791000006", "irbid", 32.5420, 35.8580, 8,  "Washing machine, refrigerator and AC repair.",                          "approved"),
 7: ("Ibrahim Khasawneh",  "+962791000007", "irbid", 32.5500, 35.8520, 3,  "New electrician awaiting verification.",                                 "pending"),
}
cats = [(1,"plumbing","Plumbing","السباكة","droplet"),(2,"electrical","Electrical","الكهرباء","zap"),
        (3,"ac-hvac","AC & Cooling","التكييف والتبريد","wind"),(4,"cleaning","Cleaning","التنظيف","sparkles"),
        (5,"appliance-repair","Appliance Repair","صيانة الأجهزة المنزلية","wrench"),(6,"painting","Painting","الدهان","paintbrush")]
svcs = [(1,1,"pipe-leak-repair","Pipe leak repair","إصلاح تسرب المواسير"),(2,1,"drain-unclogging","Drain unclogging","فتح المجاري المسدودة"),
        (3,1,"water-heater-repair","Water heater repair","صيانة سخان المياه"),(4,2,"wiring-fault-repair","Wiring fault repair","إصلاح أعطال الأسلاك"),
        (5,2,"socket-switch-install","Socket & switch installation","تركيب مفاتيح وقوابس"),(6,2,"lighting-installation","Lighting installation","تركيب الإنارة"),
        (7,3,"ac-repair","AC repair","إصلاح المكيفات"),(8,3,"ac-maintenance","AC maintenance","صيانة دورية للمكيفات"),
        (9,4,"home-deep-cleaning","Home deep cleaning","تنظيف منزلي شامل"),(10,5,"washing-machine-repair","Washing machine repair","إصلاح الغسالات"),
        (11,5,"refrigerator-repair","Refrigerator repair","إصلاح الثلاجات"),(12,6,"interior-painting","Interior painting","دهان داخلي")]
SV = {s[0]: s for s in svcs}
prov_services = {1:[(1,5),(2,5),(3,8)], 2:[(4,5),(5,4),(6,6)], 3:[(7,6),(8,5)], 4:[(9,0)], 5:[(1,4),(2,4),(4,4)], 6:[(10,5),(11,5),(7,5)], 7:[(4,4),(5,3)]}
prov_cats = {1:[1],2:[2],3:[3],4:[4],5:[1,2],6:[5,3],7:[2]}
areas = {1:[("amman","Sweifieh"),("amman","Abdoun"),("amman","Jabal Amman")], 2:[("amman","Khalda"),("amman","Tla Al-Ali"),("amman","Sweifieh")],
         3:[("amman","Jubeiha"),("amman","Khalda")], 4:[("amman","Abdoun"),("amman","Jubeiha"),("amman","Sweifieh")],
         5:[("irbid","Al-Hashmi"),("irbid","University Street")], 6:[("irbid","University Street"),("irbid","Hakama")], 7:[("irbid","Al-Hashmi")]}

# job: (n, customer, provider, service, final_status, created, description)
T = lambda d, h, m=0: datetime(2026, 9, d, h, m)
jobs = [
 (1, 1,1,1,"REQUESTED",       T(30,10), "Water is leaking under the kitchen sink and the cabinet floor is wet."),
 (2, 2,2,4,"ACCEPTED",        T(30, 9,30), "Lights flicker and the breaker trips when the oven is on."),
 (3, 3,3,7,"EN_ROUTE",        T(30,11), "Split AC is running but not cooling the living room."),
 (4, 1,2,5,"INSPECTION",      T(29,14), "Need three wall sockets installed in the home office."),
 (5, 2,1,3,"QUOTE_SENT",      T(29,10), "Water heater trips and gives only lukewarm water."),
 (6, 4,5,2,"AWAITING_PAYMENT",T(28,12), "Bathroom drain is blocked and water drains very slowly."),
 (7, 3,4,9,"PAID",            T(27, 9), "Deep clean for a 3-bedroom apartment before moving in."),
 (8, 4,6,10,"IN_PROGRESS",    T(28,16), "Washing machine does not drain and shows an error code."),
 (9, 1,1,2,"COMPLETED",       T(15,10), "Kitchen drain keeps clogging."),
 (10,2,3,8,"COMPLETED",       T(10,13), "Annual maintenance for two split AC units."),
 (11,3,2,6,"DECLINED",        T(20,15), "Install four ceiling lights in the hallway."),
 (12,1,4,9,"CANCELLED",       T(22, 8,30), "Deep clean for a small apartment."),
 (13,3,3,7,"DISPUTED",        T(24,11), "AC compressor makes a loud noise and trips."),
 (14,4,5,1,"EXPIRED",         T(25,10), "Pipe leak in the balcony."),
]
PATH = {"REQUESTED":["REQUESTED"],"ACCEPTED":["REQUESTED","ACCEPTED"],"EN_ROUTE":["REQUESTED","ACCEPTED","EN_ROUTE"],
 "INSPECTION":["REQUESTED","ACCEPTED","EN_ROUTE","ARRIVED","INSPECTION"],
 "QUOTE_SENT":["REQUESTED","ACCEPTED","EN_ROUTE","ARRIVED","INSPECTION","QUOTE_SENT"],
 "AWAITING_PAYMENT":["REQUESTED","ACCEPTED","EN_ROUTE","ARRIVED","INSPECTION","QUOTE_SENT","AWAITING_PAYMENT"],
 "PAID":["REQUESTED","ACCEPTED","EN_ROUTE","ARRIVED","INSPECTION","QUOTE_SENT","AWAITING_PAYMENT","PAID"],
 "IN_PROGRESS":["REQUESTED","ACCEPTED","EN_ROUTE","ARRIVED","INSPECTION","QUOTE_SENT","AWAITING_PAYMENT","PAID","IN_PROGRESS"],
 "COMPLETED":["REQUESTED","ACCEPTED","EN_ROUTE","ARRIVED","INSPECTION","QUOTE_SENT","AWAITING_PAYMENT","PAID","IN_PROGRESS","COMPLETED"],
 "DECLINED":["REQUESTED","DECLINED"],"CANCELLED":["REQUESTED","ACCEPTED","CANCELLED"],"EXPIRED":["REQUESTED","EXPIRED"],
 "DISPUTED":["REQUESTED","ACCEPTED","EN_ROUTE","ARRIVED","INSPECTION","QUOTE_SENT","AWAITING_PAYMENT","PAID","IN_PROGRESS","DISPUTED"]}
OFF = dict(REQUESTED=0,ACCEPTED=5,EN_ROUTE=10,ARRIVED=35,INSPECTION=40,QUOTE_SENT=70,AWAITING_PAYMENT=100,PAID=105,IN_PROGRESS=180,COMPLETED=300,DECLINED=4,CANCELLED=25,EXPIRED=16,DISPUTED=330)
ACTOR = dict(REQUESTED="customer",ACCEPTED="provider",DECLINED="provider",EN_ROUTE="provider",ARRIVED="provider",INSPECTION="provider",QUOTE_SENT="provider",
             AWAITING_PAYMENT="customer",PAID="customer",IN_PROGRESS="provider",COMPLETED="provider",CANCELLED="customer",DISPUTED="customer",EXPIRED="system")
# quotes: job -> (visit_fee, discount, status, [(kind, desc, qty, unit_price)])
quotes = {
 5: (D("5.000"),D("0"),"sent",[("labor","Heating element replacement labor",D(1),D("25.000")),("parts","Heating element 2kW",D(1),D("40.000"))]),
 6: (D("5.000"),D("0"),"approved",[("labor","Drain clearing labor",D(1),D("20.000")),("additional","Drain cleaning chemicals",D(1),D("5.000"))]),
 7: (D("0.000"),D("0"),"approved",[("labor","Deep cleaning team (3 people, 4 hours)",D(1),D("45.000"))]),
 8: (D("4.000"),D("0"),"approved",[("labor","Pump replacement labor",D(1),D("18.000")),("parts","Drain pump",D(1),D("22.500"))]),
 9: (D("5.000"),D("0"),"approved",[("labor","Drain clearing labor",D(1),D("20.000"))]),
 10:(D("5.000"),D("2.000"),"approved",[("labor","Maintenance of AC units",D(2),D("15.000")),("parts","Filter cleaning kit",D(1),D("12.000"))]),
 13:(D("5.000"),D("0"),"approved",[("labor","Compressor replacement labor",D(1),D("35.000")),("parts","Compressor",D(1),D("60.000"))]),
}
insp = {4:("Existing wiring is safe; wall cavity is accessible.","Install 3 sockets with new 2.5mm cable run.",2),
        5:("Heating element burnt out; thermostat OK.","Replace heating element.",1),
        6:("Hair and grease blockage in the trap.","Mechanical clearing of the trap.",1),
        7:("Standard 3-bedroom, light dust and kitchen grease.","Full deep clean.",4),
        8:("Drain pump blocked and worn.","Replace drain pump.",2),
        9:("Grease buildup in the kitchen drain line.","Clear the drain line.",1),
        10:("Dirty filters on both units; refrigerant pressure normal.","Clean filters and service both units.",2),
        13:("Compressor bearing noise; capacitor weak.","Replace compressor.",3)}
photos = {4:2, 9:1, 10:1}

L = []
add = L.append
add("-- seed.sql — GENERATED by tools/generate_seed.py. DEV/DEMO ONLY (fictional data). Do NOT run in production.\n-- Deterministic: fixed UUIDs and timestamps. Requires migrations 0001-0006 applied to an EMPTY database.\n-- Seed users have a DEV-ONLY password (see docs/BACKEND_HANDOFF.md) and may need auth.identities rows to log in via password.\nbegin;\nselect set_config('app.bypass_job_rules', 'on', true);  -- trusted seed session only; clients can never use this (auth.uid() must be null)\n")

# --- auth users + profiles
au_cols = ["instance_id","id","aud","role","email","phone","encrypted_password","email_confirmed_at","phone_confirmed_at","raw_app_meta_data","raw_user_meta_data","created_at","updated_at","confirmation_token","recovery_token","email_change","email_change_token_new"]
users = [(C[i], f"customer{i}@seed.example.test", customers[i][1]) for i in C] + [(P[i], f"provider{i}@seed.example.test", providers[i][1]) for i in P] + [(ADMIN, "admin@seed.example.test", "+962792000001")]
base = datetime(2026, 8, 1, 9)
rows = []
for uid, email, phone in users:
    rows.append(["00000000-0000-0000-0000-000000000000", uid, "authenticated", "authenticated", email, phone.lstrip("+"),
                 "__CRYPT__", base, base, '{"provider":"email","providers":["email"]}', "{}", base, base, "", "", "", ""])
sql = ins("auth.users", au_cols, rows).replace("'__CRYPT__'", "extensions.crypt('DemoPass#2026', extensions.gen_salt('bf'))")
add(sql + "\n")  # no ON CONFLICT: seed expects an empty DB

prof_rows  = [[C[i], "customer", customers[i][1], f"customer{i}@seed.example.test", customers[i][0], "ar", "active", base, base] for i in C]
prof_rows += [[P[i], "provider", providers[i][1], f"provider{i}@seed.example.test", providers[i][0], "ar", "active", base, base] for i in P]
prof_rows += [[ADMIN, "admin", "+962792000001", "admin@seed.example.test", "Admin Demo", "en", "active", base, base]]
add(ins("profiles", ["id","role","phone","email","full_name","preferred_language","status","created_at","updated_at"], prof_rows) + "\n")
add(ins("customer_profiles", ["user_id","default_city","default_neighborhood","default_address","default_lat","default_lng"],
        [[C[i], customers[i][2], customers[i][3], customers[i][4], customers[i][5], customers[i][6]] for i in C]) + "\n")
add(ins("categories", ["id","slug","name_en","name_ar","icon","sort_order"], [[u(CAT, c[0]), c[1], c[2], c[3], c[4], c[0]*10] for c in cats]) + "\n")
add(ins("services", ["id","category_id","slug","name_en","name_ar","sort_order"], [[u(SVC, s[0]), u(CAT, s[1]), s[2], s[3], s[4], s[0]*10] for s in svcs]) + "\n")

completed_count = {1:1, 3:1}
add(ins("provider_profiles", ["user_id","bio","years_experience","verification_status","verified_at","completed_jobs","city","base_lat","base_lng","service_radius_km","is_available","created_at","updated_at"],
        [[P[i], providers[i][6], providers[i][5], providers[i][7], (base if providers[i][7]=="approved" else None), completed_count.get(i,0),
          providers[i][2], providers[i][3], providers[i][4], D("15.0"), providers[i][7]=="approved", base, base] for i in P]) + "\n")
add(ins("provider_specialties", ["provider_id","category_id","years_experience"], [[P[i], u(CAT, c), providers[i][5]] for i in P for c in prov_cats[i]]) + "\n")
add(ins("provider_service_areas", ["id","provider_id","city","neighborhood"], [[u("72000000", k), P[i], c, n] for k, (i, c, n) in enumerate([(i,c,n) for i in P for (c,n) in areas[i]], 1)]) + "\n")
avail = []
k = 1
for i in P:
    for wd in range(0, 5): avail.append([u("71000000", k), P[i], wd, "08:00", "18:00"]); k += 1
avail.append([u("71000000", k), P[4], 6, "09:00", "15:00"])
add(ins("provider_availability", ["id","provider_id","weekday","start_time","end_time"], avail) + "\n")
add(ins("provider_services", ["provider_id","service_id","base_visit_fee"], [[P[i], u(SVC, s), D(f) .quantize(D("0.001"))] for i in P for (s, f) in prov_services[i]]) + "\n")
add(ins("provider_portfolio", ["id","provider_id","title","description","image_path","work_date"],
        [[u("61000000",1), P[1], "Kitchen sink repipe", "Replaced old supply lines under a kitchen sink.", f"{P[1]}/seed-portfolio-1.jpg", datetime(2026,8,12)],
         [u("61000000",2), P[3], "Split AC full service", "Cleaned and serviced a 24k BTU split unit.", f"{P[3]}/seed-portfolio-1.jpg", datetime(2026,8,20)],
         [u("61000000",3), P[4], "Apartment deep clean", "Move-in deep clean for a 3-bedroom apartment.", f"{P[4]}/seed-portfolio-1.jpg", datetime(2026,8,25)]]) + "\n")

# --- jobs, history
job_rows, hist_rows, ts_of = [], [], {}
for (n, c, p, s, st, created, desc) in jobs:
    path = PATH[st]; ts = {x: created + timedelta(minutes=OFF[x]) for x in path}; ts_of[n] = ts
    last = ts[path[-1]]
    cust = customers[c]
    job_rows.append([u(JOB, n), C[c], P[p], u(SVC, s), desc, cust[2], cust[3], cust[4], cust[5], cust[6], st,
                     ts.get("ACCEPTED"), ts.get("COMPLETED"), ts.get("CANCELLED"), (C[c] if st=="CANCELLED" else None),
                     ("Customer found another provider" if st=="CANCELLED" else None), created, last])
    prev = None
    for x in path:
        actor = ACTOR[x]; by = None if actor == "system" else (C[c] if actor == "customer" else P[p])
        hist_rows.append([u(JOB, n), prev, x, by, actor, ts[x]]); prev = x
add(ins("jobs", ["id","customer_id","provider_id","service_id","problem_description","city","neighborhood","address_text","lat","lng","status","accepted_at","completed_at","cancelled_at","cancelled_by","cancellation_reason","created_at","updated_at"], job_rows) + "\n")
add(ins("job_status_history", ["job_id","from_status","to_status","changed_by","actor_role","created_at"], hist_rows) + "\n")

# --- inspections / photos
insp_rows, ph_rows = [], []
for n, (f, r, h) in insp.items():
    insp_rows.append([u("11000000", n), u(JOB, n), f, r, h*60, ts_of[n]["INSPECTION"] + timedelta(minutes=10)])
    for k in range(1, photos.get(n, 0) + 1):
        ph_rows.append([u("12000000", n*10 + k), u("11000000", n), f"{u(JOB, n)}/{u('11000000', n)}/seed-photo-{k}.jpg", f"Photo {k}", "image/jpeg", 245000 + k*1000, ts_of[n]["INSPECTION"] + timedelta(minutes=12)])
add(ins("inspections", ["id","job_id","findings","recommended_work","estimated_duration_minutes","created_at"], insp_rows) + "\n")
add(ins("inspection_photos", ["id","inspection_id","storage_path","caption","content_type","size_bytes","created_at"], ph_rows) + "\n")

# --- quotes / items / payments / invoices (with arithmetic assertions)
q_rows, qi_rows, pay_rows, pe_rows, inv_rows, il_rows = [], [], [], [], [], []
totals = {}
for n, (vf, disc, qs, items) in quotes.items():
    sub = sum(q3(qty*price) for (_, _, qty, price) in items); total = vf + sub - disc; totals[n] = (vf, sub, disc, total)
    sent_at = ts_of[n]["QUOTE_SENT"]; appr = ts_of[n].get("AWAITING_PAYMENT") if qs == "approved" else None
    q_rows.append([u("e0000000", n), u(JOB, n), qs, vf, disc, D("0.0000"), datetime(2030,1,1), sent_at, appr, sent_at - timedelta(minutes=20), sent_at])
    for k, (kind, d_, qty, price) in enumerate(items, 1):
        qi_rows.append([u("e1000000", n*10 + k), u("e0000000", n), kind, d_, qty, price, k])
    if qs == "approved":
        paid = "PAID" in ts_of[n]
        pid = u("21000000", n)
        pay_rows.append([pid, u(JOB, n), u("e0000000", n), "prototype", "paid" if paid else "pending", total, D("0.0000"), D("0.000"), total,
                         (f"seed-pay-{n:08d}" if paid else None), ("demo" if paid else None), (f"DEMO-{pid[:8]}" if paid else None),
                         (ts_of[n]["PAID"] if paid else None), appr, appr])
        if paid: pe_rows.append([pid, "payment.succeeded", '{"simulated":true}', ts_of[n]["PAID"]])
for n, num in ((9, 1), (10, 2)):
    vf, sub, disc, total = totals[n]; qs_items = quotes[n][3]
    lines = ([("visit_fee", "Visit / inspection fee", D(1), vf)] if vf > 0 else []) + [(k_, d_, qty, q3(qty*pr)) for (k_, d_, qty, pr) in qs_items] + ([("discount", "Discount", D(1), -disc)] if disc > 0 else [])
    assert sum(l[3] for l in lines) == total == (vf + sub) - disc, f"invoice lines mismatch job {n}"
    inv_rows.append([u("22000000", n), f"INV-2026-{num:06d}", u(JOB, n), C[jobs[n-1][1]], P[jobs[n-1][2]], u("21000000", n), "paid", vf + sub, disc, total, ts_of[n]["COMPLETED"], ts_of[n]["PAID"]])
    for k, (kd, ds, qty, amt) in enumerate(lines, 1): il_rows.append([u("23000000", n*10 + k), u("22000000", n), kd, ds, qty, amt, k])
add(ins("quotes", ["id","job_id","status","visit_fee","discount","commission_rate","expires_at","sent_at","approved_at","created_at","updated_at"], q_rows) + "\n")
add(ins("quote_items", ["id","quote_id","kind","description","quantity","unit_price","sort_order"], qi_rows) + "\n")
add(ins("payments", ["id","job_id","quote_id","mode","status","amount","commission_rate","platform_commission","provider_earnings","idempotency_key","gateway_name","gateway_reference","paid_at","created_at","updated_at"], pay_rows) + "\n")
add(ins("payment_events", ["payment_id","event_type","payload","created_at"], pe_rows) + "\n")
add(ins("invoices", ["id","invoice_number","job_id","customer_id","provider_id","payment_id","status","subtotal","discount","total","issued_at","paid_at"], inv_rows) + "\n")
add(ins("invoice_line_items", ["id","invoice_id","kind","description","quantity","amount","sort_order"], il_rows) + "\n")
add("select setval('invoice_number_seq', 2);  -- next generated invoice is INV-<year>-000003\n")

# --- reviews, disputes, notifications, audit
c9, c10 = ts_of[9]["COMPLETED"], ts_of[10]["COMPLETED"]
add(ins("reviews", ["id","job_id","reviewer_id","reviewee_id","score","comment","created_at"],
 [[u("31000000",1), u(JOB,9), C[1], P[1], 5, "Fixed quickly and cleaned up afterwards.", c9 + timedelta(hours=3)],
  [u("31000000",2), u(JOB,9), P[1], C[1], 5, "Clear description of the problem, easy to coordinate.", c9 + timedelta(hours=5)],
  [u("31000000",3), u(JOB,10), C[2], P[3], 4, "Good service, arrived a little late.", c10 + timedelta(hours=2)]]) + "\n")
add(ins("disputes", ["id","kind","job_id","opened_by","reason","details","status","created_at"],
 [[u("51000000",1), "job_dispute", u(JOB,13), C[3], "Work not completed as agreed", "Compressor still makes noise after the visit.", "open", ts_of[13]["DISPUTED"]]]) + "\n")
nots = [(1,P[1],"new_request","New service request","New Pipe leak repair request in Amman.",1,False),
        (2,C[2],"request_accepted","Request accepted","Your Wiring fault repair request was accepted.",2,True),
        (3,C[3],"provider_en_route","Provider on the way","Your provider is on the way.",3,False),
        (4,C[2],"quote_received","New quote","You received a quote. Review and approve it.",5,False),
        (5,P[5],"quote_approved","Quote approved","The customer approved your quote. Awaiting payment.",6,False),
        (6,P[4],"payment_successful","Payment received","Payment was completed. You can start the work.",7,True),
        (7,C[4],"work_started","Work started","Your provider started the work.",8,False),
        (8,C[1],"work_completed","Work completed","The job is complete. Your invoice is ready.",9,True),
        (9,P[1],"new_review","New review","You received a 5-star review.",9,False),
        (10,P[3],"dispute_opened","Dispute opened","The customer opened a dispute.",13,False),
        (11,C[3],"request_declined","Request declined","Your Lighting installation request was declined. Try another provider.",11,True),
        (12,C[4],"job_expired","Request expired","The request expired.",14,True)]
nrows = []
for (k, rid, ty, ti, me, jn, read) in nots:
    t = ts_of[jn][max(ts_of[jn], key=lambda x: ts_of[jn][x])] + timedelta(minutes=1)
    nrows.append([u("41000000", k), rid, ty, ti, me, u(JOB, jn), (t + timedelta(minutes=30) if read else None), t])
add(ins("notifications", ["id","recipient_id","type","title","message","job_id","read_at","created_at"], nrows) + "\n")
add(ins("audit_logs", ["actor_id","action","entity_type","entity_id","details","created_at"],
        [[ADMIN, "provider.verification", "provider", P[i], '{"status":"approved","note":"seed"}', base] for i in range(1, 7)]) + "\n")
add("commit;\n")

# --- state coverage assertion: one job per state
assert {j[4] for j in jobs} == {"REQUESTED","ACCEPTED","EN_ROUTE","ARRIVED","INSPECTION","QUOTE_SENT","AWAITING_PAYMENT","PAID","IN_PROGRESS","COMPLETED","DECLINED","CANCELLED","EXPIRED","DISPUTED"} - {"ARRIVED"} , "state coverage"
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "seed", "seed.sql")
open(out, "w", encoding="utf-8").write("\n".join(L))
print("wrote", os.path.normpath(out), "| jobs:", len(jobs), "| quotes:", len(quotes), "| totals:", {k: str(v[3]) for k, v in totals.items()})
