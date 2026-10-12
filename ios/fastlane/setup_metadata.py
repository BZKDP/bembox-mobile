import os, shutil

ROOT = os.path.dirname(os.path.abspath(__file__))
META = os.path.join(ROOT, "metadata")
RU = os.path.join(META, "ru")
REV = os.path.join(META, "review_information")
SHOTS = os.path.join(ROOT, "screenshots", "ru")
for d in (RU, REV, SHOTS):
    os.makedirs(d, exist_ok=True)

def w(path, text):
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)

DESC = """bembox — быстрая локальная доставка продуктов и услуг к вашей двери.

Что можно заказать:
• продукты из магазина рядом;
• кофе и завтраки;
• питьевую воду;
• вынос мусора и бытовые услуги;
• выдачу посылок через пункт выдачи.

Как это работает: выбираете товар или услугу, указываете адрес — курьер привозит заказ примерно за 15 минут. Оплата картой онлайн, вход по номеру телефона. Доставка по району обслуживания.

bembox — это просто: пара тапов, и заказ уже едет."""

DEMO_USER = os.environ.get("APP_REVIEW_DEMO_USER", "")
DEMO_PASSWORD = os.environ.get("APP_REVIEW_DEMO_PASSWORD", "")
NOTES = ("Вход по номеру телефона. Для проверки используйте тестовые данные, "
         "переданные владельцем App Store Connect. Приложение — "
         "сервис локальной доставки: каталог, корзина, оформление и оплата заказа, "
         "услуги (кофе/вода/мусор), карта адреса. Оплата картой через ЮKassa.")

# ru locale
w(os.path.join(RU, "name.txt"), "bembox")
w(os.path.join(RU, "subtitle.txt"), "доставка за 15 минут")
w(os.path.join(RU, "description.txt"), DESC)
w(os.path.join(RU, "keywords.txt"), "доставка,продукты,еда,кофе,вода,завтрак,15 минут,курьер,магазин,вынос мусора")
w(os.path.join(RU, "promotional_text.txt"), "Продукты, кофе, вода, завтраки и бытовые услуги — привезём к двери за 15 минут.")
w(os.path.join(RU, "release_notes.txt"), "Первый релиз bembox: продукты, кофе, завтраки, вода, вынос мусора и выдача посылок — доставка к двери примерно за 15 минут.")
w(os.path.join(RU, "support_url.txt"), "https://bembox.ru")
w(os.path.join(RU, "marketing_url.txt"), "https://bembox.ru")
w(os.path.join(RU, "privacy_url.txt"), "https://bembox.ru/privacy")

# app-level
w(os.path.join(META, "primary_category.txt"), "FOOD_AND_DRINK")
w(os.path.join(META, "copyright.txt"), "2026 bembox")

# review information
w(os.path.join(REV, "first_name.txt"), os.environ.get("APP_REVIEW_FIRST_NAME", ""))
w(os.path.join(REV, "last_name.txt"), os.environ.get("APP_REVIEW_LAST_NAME", ""))
w(os.path.join(REV, "email_address.txt"), os.environ.get("APP_REVIEW_EMAIL", ""))
w(os.path.join(REV, "phone_number.txt"), os.environ.get("APP_REVIEW_PHONE", ""))
w(os.path.join(REV, "demo_user.txt"), DEMO_USER)
w(os.path.join(REV, "demo_password.txt"), DEMO_PASSWORD)
w(os.path.join(REV, "notes.txt"), NOTES)

# screenshots
SRC = os.environ.get("APP_SCREENSHOTS_DIR", "")
if SRC and os.path.isdir(SRC):
    for fn in sorted(os.listdir(SRC)):
        if fn.lower().endswith(".png"):
            shutil.copy(os.path.join(SRC, fn), os.path.join(SHOTS, fn))

print("metadata + screenshots prepared under", ROOT)
for r, _, fs in os.walk(META):
    for f in fs:
        print(" ", os.path.relpath(os.path.join(r, f), ROOT))
print("screenshots:", os.listdir(SHOTS))
