# Runtime smoke test for the Phase 1 design system (web export). See nav_smoke.py for how to serve dist/.
# Requires: pip install playwright && playwright install chromium
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={'width': 390, 'height': 800})
    errs = []; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('http://localhost:8099/login'); pg.wait_for_selector('text=تسجيل الدخول')

    # RTL + language
    assert pg.evaluate("document.documentElement.dir") == 'rtl', 'html dir is not rtl'
    assert pg.evaluate("document.documentElement.lang") == 'ar'
    # Arabic font actually loaded (not silently falling back)
    pg.wait_for_function("document.fonts.check('16px IBMPlexSansArabic_400Regular')", timeout=10000)
    print('RTL + lang + font OK')

    # Layout truly mirrors: in a flex row, first child should be on the RIGHT. Check via 'Button loading' row (spinner + label).
    pg.get_by_role('button', name='معاينة التصميم').click()
    pg.wait_for_selector('text=نظام التصميم')
    box = pg.get_by_text('نظام التصميم').bounding_box()
    assert box['x'] + box['width'] > 390 / 2, f'title not right-aligned in RTL: {box}'
    print('title aligned to the right (RTL) OK')

    # Toast
    pg.get_by_role('button', name='اطلب الآن').click()
    pg.wait_for_selector('[role=alert]:has-text("تم إرسال الطلب")'); print('toast OK')

    # Disabled/loading buttons not pressable
    assert pg.get_by_role('button', name='غير متاح').get_attribute('aria-disabled') == 'true', 'disabled state not exposed via aria-disabled'
    assert pg.get_by_role('button', name='جارٍ التحميل').get_attribute('aria-busy') == 'true', 'loading state not exposed via aria-busy'
    print('disabled button OK')

    # Error text field shown
    pg.wait_for_selector('text=أدخل رقم هاتف صحيح'); print('field error OK')
    pg.screenshot(path='/tmp/preview1.png')

    # Bottom sheet open + close via backdrop and via button
    pg.get_by_role('button', name='فتح النافذة السفلية').click()
    pg.wait_for_selector('text=اختر وقت الزيارة'); print('sheet opens')
    pg.get_by_role('button', name='إغلاق النافذة').click(force=True)
    pg.wait_for_selector('text=اختر وقت الزيارة', state='detached'); print('sheet closes (backdrop)')
    pg.get_by_role('button', name='فتح النافذة السفلية').click(); pg.wait_for_selector('text=اختر وقت الزيارة')
    pg.locator('[role=button]:has-text("رجوع")').last.click()
    pg.wait_for_selector('text=اختر وقت الزيارة', state='detached'); print('sheet closes (button)')

    # Back to home
    pg.get_by_role('button', name='رجوع').first.click(); pg.wait_for_selector('text=تسجيل الدخول')
    print('page errors:', errs); assert not errs
    b.close()
