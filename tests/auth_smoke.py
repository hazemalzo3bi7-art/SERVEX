# Runtime test of the whole auth + role-guard flow on the web export.
# Serve: python3 tests/serve_dist.py /tmp/export-web 8099 &   Run: python3 tests/auth_smoke.py
from playwright.sync_api import sync_playwright

BASE = 'http://localhost:8099'

def btn(pg, name): return pg.get_by_role('button', name=name)
def at(pg, path): assert pg.url == BASE + path, f'expected {path}, at {pg.url}'

def login(pg, phone, code='123456'):
    pg.get_by_test_id('phone-input').fill(phone); btn(pg, 'متابعة').click()
    pg.get_by_test_id('code-input').wait_for(); pg.get_by_test_id('code-input').fill(code); btn(pg, 'تحقق').click()

with sync_playwright() as p:
    b = p.chromium.launch(); ctx = b.new_context(viewport={'width': 390, 'height': 800}); pg = ctx.new_page()
    errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))

    # 1. Fresh visit lands on login (index redirect)
    pg.goto(BASE + '/'); pg.wait_for_selector('text=تسجيل الدخول >> visible=true'); at(pg, '/login'); print('1 fresh visit -> /login OK')

    # 2. Unauthenticated deep link to protected routes is bounced to login
    for path in ('/customer', '/provider', '/admin'):
        pg.goto(BASE + path); pg.wait_for_selector('text=تسجيل الدخول >> visible=true'); assert 'تسجيل الدخول' in pg.inner_text('body')
        assert not pg.get_by_text('مرحباً').count(), f'{path} leaked content'
    print('2 unauthenticated deep links blocked OK')

    # 3. Invalid phone shows an error, nothing navigates
    pg.goto(BASE + '/login'); pg.get_by_test_id('phone-input').fill('123'); btn(pg, 'متابعة').click()
    pg.wait_for_selector('text=أدخل رقم هاتف أردني صحيح >> visible=true'); at(pg, '/login'); print('3 invalid phone error OK')

    # 4. Verify without a request is bounced back to login
    pg.goto(BASE + '/verify'); pg.wait_for_selector('text=تسجيل الدخول >> visible=true'); print('4 /verify without request -> login OK')

    # 5. Wrong code, then right code -> customer home
    pg.get_by_test_id('phone-input').fill('0790000002'); btn(pg, 'متابعة').click()
    pg.get_by_test_id('code-input').wait_for(); pg.get_by_test_id('code-input').fill('000000'); btn(pg, 'تحقق').click()
    pg.wait_for_selector('text=الرمز غير صحيح >> visible=true'); print('5a wrong code error OK')
    pg.get_by_test_id('code-input').fill('123456'); btn(pg, 'تحقق').click()
    pg.wait_for_selector('text=مرحباً، سارة المصري >> visible=true'); print('5b customer signed in:', pg.url)

    # 6. Role guard while signed in: customer client-navigates to /admin and /provider -> not allowed
    for target in ('/admin', '/provider'):
        pg.evaluate(f"history.pushState({{}}, '', '{target}'); window.dispatchEvent(new PopStateEvent('popstate'))")
        pg.wait_for_timeout(700)
        body = pg.inner_text('body')
        assert 'قيد الإنشاء' in body and 'مرحباً، سارة المصري' in body, f'unexpected content at {target}'
        assert 'لوحة الإدارة' not in body and 'تجربة مزوّد' not in body, f'customer saw {target} content'
    print('6 customer cannot reach admin/provider OK (url now %s)' % pg.url)

    # 7. Logout -> login; protected area no longer reachable
    btn(pg, 'تسجيل الخروج').click(); pg.wait_for_selector('text=تسجيل الدخول >> visible=true'); at(pg, '/login'); print('7 logout OK')

    # 8. Admin and provider demo accounts land on their own homes
    login(pg, '0790000001'); pg.wait_for_selector('text=مرحباً، إدارة النظام >> visible=true'); assert 'لوحة الإدارة' in pg.inner_text('body')
    btn(pg, 'تسجيل الخروج').click(); pg.wait_for_selector('text=تسجيل الدخول >> visible=true')
    login(pg, '0790000003'); pg.wait_for_selector('text=مرحباً، محمد العبادي >> visible=true'); assert 'تجربة مزوّد' in pg.inner_text('body')
    btn(pg, 'تسجيل الخروج').click(); pg.wait_for_selector('text=تسجيل الدخول >> visible=true'); print('8 admin + provider homes OK')

    # 9. New user: Arabic digits accepted, register as provider; validation errors first
    login(pg, '٠٧٧١٢٣٤٥٦٧'); pg.wait_for_selector('text=إنشاء حساب >> visible=true'); at(pg, '/register')
    btn(pg, 'إنشاء الحساب').click(); pg.wait_for_selector('text=أدخل اسماً من حرفين على الأقل >> visible=true'); print('9a empty name error OK')
    pg.get_by_test_id('name-input').fill('رنا الخطيب'); btn(pg, 'إنشاء الحساب').click()
    pg.wait_for_selector('text=اختر نوع الحساب >> visible=true'); print('9b missing role error OK')
    pg.get_by_test_id('role-provider').click()
    assert pg.get_by_test_id('role-provider').get_attribute('aria-checked') == 'true'
    btn(pg, 'إنشاء الحساب').click(); pg.wait_for_selector('text=مرحباً، رنا الخطيب >> visible=true'); assert 'تجربة مزوّد' in pg.inner_text('body'); print('9c new provider registered OK')

    # 10. Lockout: 5 wrong codes
    btn(pg, 'تسجيل الخروج').click(); pg.wait_for_selector('text=تسجيل الدخول >> visible=true')
    pg.get_by_test_id('phone-input').fill('0790000002'); btn(pg, 'متابعة').click(); pg.get_by_test_id('code-input').wait_for()
    for i in range(5):
        pg.get_by_test_id('code-input').fill('999999'); btn(pg, 'تحقق').click(); pg.wait_for_timeout(700)
    pg.wait_for_selector('text=محاولات كثيرة >> visible=true'); print('10 lockout message OK')

    print('page errors:', errs); assert not errs
    pg.screenshot(path='/tmp/auth_end.png'); b.close()
print('ALL AUTH RUNTIME CHECKS PASSED')
