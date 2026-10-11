# İndirme Yöneticisi

İnternet kesilirse bekleyen, bilgisayar kapanıp açılınca **kaldığı yerden devam eden** küçük bir Windows indirme yöneticisi.
Windows'un kendi BITS altyapısını kullanır, ek bir yazılım kurmayı gerektirmez. Tarayıcı eklentisiyle tarayıcıdan başlattığın
indirmeleri otomatik devralır.

![platform](https://img.shields.io/badge/platform-Windows%2010%2F11-blue)
![license](https://img.shields.io/badge/license-MIT-green)

## Özellikler

- **Kesintiye dayanıklı:** internet gidince bekler, gelince devam eder. Bilgisayar kapanıp açılsa da baştan başlamaz.
- **Tarayıcıdan otomatik yakalama:** Chrome, Edge, Brave, Opera, Vivaldi ve diğer Chromium tabanlı tarayıcılar.
- **Arka planda çalışır:** pencereyi kapatınca sistem tepsisinde yaşamaya devam eder.
- **Windows ile başlama** seçeneği (indirmelerin biter bitmez yerine konması için önerilir).
- Duraklat / devam / iptal, indirme hızı, koyu ve açık tema.

## Kurulum

1. [Releases](../../releases) sayfasından `IndirmeYoneticisi.exe` dosyasını indir ve çalıştır.
   Uygulama kendini `%LOCALAPPDATA%\IndirmeYoneticisi` altına açar.
2. Pencerenin sağ altındaki **Tarayıcı eklentisi** düğmesine bas, tarayıcını seç ve **Eklentiyi kur**'a bas.
3. Açılan eklentiler sayfasında: **Geliştirici modu** → **Paketlenmemiş öğe yükle** → `Ctrl+V` → **Klasör seç**.

> Yeni Chrome/Edge sürümleri eklentinin komut satırından yüklenmesine izin vermediği için üçüncü adım elle yapılır.

## Nasıl çalışır?

```
Tarayıcı ──(eklenti)──► 127.0.0.1:47800 ──► İndirme Yöneticisi ──► BITS (Windows servisi)
```

- Eklenti, tarayıcıda başlayan indirmeyi iptal edip adresini uygulamaya iletir.
- Uygulama indirmeyi BITS işi olarak kuyruğa alır. BITS kesintilerde yeniden dener (14 gün) ve oturum açılınca devam eder.
- Uygulama kapalıyken kuyruk BITS'te durur; dosyanın son adına taşınması için uygulama açık olmalıdır
  (bu yüzden "Windows ile başlat" önerilir).

## Sınırlar

- Bilgisayar kapalıyken veya uykudayken indirme ilerlemez; açılınca kaldığı yerden sürer.
- Sunucu yarım indirmeyi sürdürmeyi (HTTP Range) desteklemiyorsa o dosya baştan başlar.
- Firefox ve Firefox tabanlı tarayıcılar desteklenmez (eklenti Chromium içindir).

## Kaynaktan derleme

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

`dist\IndirmeYoneticisi.exe` üretilir. Ek bir araç gerekmez (Windows'ta bulunan .NET Framework 4 derleyicisi kullanılır).

Depo yapısı:

| Dosya | Açıklama |
|---|---|
| `IndirmeYoneticisi.ps1` | Uygulamanın kendisi (PowerShell + WPF) |
| `TarayiciEklentisi/` | Chromium tabanlı tarayıcılar için eklenti (Manifest V3) |
| `Launcher.cs` | Betiği içinde taşıyıp çalıştıran küçük EXE başlatıcı |
| `build.ps1` | EXE derleme betiği |

## Güvenlik

- Eklenti ile uygulama yalnızca `127.0.0.1` üzerinden, ilk çalıştırmada üretilen gizli anahtarla konuşur.
  Anahtar `%APPDATA%\IndirmeYoneticisi.token` dosyasında durur ve depoya girmez.
- EXE, PowerShell betiğini içinde taşıyan küçük bir başlatıcıdır; bazı antivirüsler bu tür dosyaları şüpheli bulabilir.
  Kaynak kodun tamamı bu depoda açıktır, EXE'yi `build.ps1` ile kendin üretebilirsin.

## Lisans

[MIT](LICENSE)
