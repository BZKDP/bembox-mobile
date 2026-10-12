# RuStore Push SDK — не обфусцировать Parcelable-классы VK Push (иначе пуши
# ломаются в release-сборке с включённым R8/minify).
-keep public class com.vk.push.** extends android.os.Parcelable
