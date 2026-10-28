# İndirme Yöneticisi

İndirme Yöneticisi, Windows üzerinde BITS (Background Intelligent Transfer Service) altyapısını kullanan, modern WPF arayüzüne ve Chromium tabanlı tarayıcı eklentisine sahip bir indirme aracıdır.

## Özellikler

- **BITS Tabanlı İndirme:** Bağlantı kesintilerinde indirmeyi bekletir ve bilgisayar yeniden açıldığında kaldığı yerden devam eder.
- **Modern WPF Arayüzü:** İndirme ilerlemesini, durumunu ve ayrıntılarını gösteren XAML tabanlı modern kullanıcı arayüzü.
- **Tarayıcı Entegrasyonu:** Chromium tabanlı tarayıcılarda indirmeleri algılayıp yerel port (47800) ve güvenlik belirteci (token) üzerinden uygulamaya aktaran tarayıcı eklentisi.
- **Eklenti Açma/Kapatma:** Eklenti simgesine tıklanarak indirme yakalama kolayca duraklatılabilir veya etkinleştirilebilir.
- **Tek Kopya Desteği:** Uygulama çalışırken tekrar başlatıldığında mevcut pencereyi öne getirir.
- **C# Başlatıcı:** PowerShell betiğini ve eklenti dosyalarını `%LOCALAPPDATA%\IndirmeYoneticisi` dizinine açıp arka planda yürüten hafif C# başlatıcısı.

## Kullanılan Teknolojiler

- **PowerShell:** Temel uygulama mantığı ve BITS (`BitsTransfer`) yönetimi
- **C# (.NET Framework 4):** Bağımsız yürütülebilir dosya oluşturan başlatıcı (`Launcher.cs`)
- **WPF (Windows Presentation Foundation):** Kullanıcı arayüzü
- **JavaScript:** Tarayıcı uzantısı arka plan betiği (`background.js`)

## Kurulum ve Çalıştırma

### Depoyu Klonlama

```powershell
git clone https://github.com/MustafaCanDere/IndirmeYoneticisi.git
cd IndirmeYoneticisi
```

### Derleme (İsteğe Bağlı)

Uygulamayı tek bir `.exe` dosyası haline getirmek için .NET Framework 4 `csc.exe` derleyicisini çalıştıran `build.ps1` betiğini kullanabilirsiniz:

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

Derleme tamamlandığında çalıştırılabilir dosya `dist\IndirmeYoneticisi.exe` konumunda oluşturulur.

### Doğrudan Çalıştırma

Projeyi derlemeden doğrudan PowerShell üzerinden başlatmak için:

```powershell
powershell -STA -ExecutionPolicy Bypass -File .\IndirmeYoneticisi.ps1
```

*(Gizli modda başlatmak için `-Gizli` parametresi eklenebilir.)*

### Tarayıcı Eklentisinin Yüklenmesi

1. Chromium tabanlı tarayıcınızda (Chrome, Edge vb.) Uzantılar sayfasını (`chrome://extensions`) açın.
2. **Geliştirici modu** seçeneğini etkinleştirin.
3. **Paketlenmemiş öge yükle** seçeneğiyle repo içerisindeki `TarayiciEklentisi` klasörünü seçin.