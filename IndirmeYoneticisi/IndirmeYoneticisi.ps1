# Indirme Yoneticisi (modern WPF arayuz) - BITS tabanli.
# Internet kesilince bekler, bilgisayar kapanip acilinca kaldigi yerden devam eder.
param([switch]$Gizli)
$script:selfPath = $PSCommandPath
$script:Gizli = $Gizli
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing
Import-Module BitsTransfer

Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

public class DlItem : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler PropertyChanged;
    private void N(string p) { var h = PropertyChanged; if (h != null) h(this, new PropertyChangedEventArgs(p)); }

    private string name = "", status = "", detail = "", pctText = "";
    private double percent;
    private bool paused, indet, done;

    public string Id { get; set; }
    public string Path { get; set; }
    public string Name    { get { return name; }    set { name = value;    N("Name"); } }
    public string Status  { get { return status; }  set { status = value;  N("Status"); } }
    public string Detail  { get { return detail; }  set { detail = value;  N("Detail"); } }
    public string PctText { get { return pctText; } set { pctText = value; N("PctText"); } }
    public double Percent { get { return percent; } set { percent = value; N("Percent"); } }
    public bool Indeterminate { get { return indet; } set { indet = value; N("Indeterminate"); } }
    public bool Done   { get { return done; }   set { done = value; N("Done"); N("NotDone"); N("ToggleVisibility"); } }
    public bool NotDone { get { return !done; } }
    public string ToggleVisibility { get { return done ? "Collapsed" : "Visible"; } }
    public bool Paused { get { return paused; } set { paused = value; N("Paused"); N("Glyph"); N("ToggleTip"); } }
    public string Glyph { get { return paused ? "" : ""; } }
    public string ToggleTip { get { return paused ? "Devam et" : "Duraklat"; } }
}

public static class Dwm
{
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int val, int size);
}
'@

# ---- Tarayici baglantisi: yerel port + gizli anahtar ----
$Port = 47800
$tokenFile = Join-Path $env:APPDATA 'IndirmeYoneticisi.token'
$script:token = $null
try { $script:token = (Get-Content $tokenFile -TotalCount 1 -ErrorAction Stop).Trim() } catch {}
if (-not $script:token) {
    $rb = New-Object byte[] 24
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($rb)
    $script:token = ([BitConverter]::ToString($rb) -replace '-', '').ToLower()
    Set-Content -Path $tokenFile -Value $script:token -Encoding ASCII
}

# Tek kopya: zaten calisiyorsa mevcut pencereyi one getir ve cik
$script:mutex = New-Object System.Threading.Mutex($false, 'Local\IndirmeYoneticisi')
if (-not $script:mutex.WaitOne(0)) {
    try {
        Invoke-WebRequest -Uri "http://127.0.0.1:$Port/show" -Method Post -Headers @{ 'X-Token' = $script:token } -UseBasicParsing -TimeoutSec 3 | Out-Null
    } catch {}
    exit
}

# Eklentiye anahtari yaz
$extDir = Join-Path $PSScriptRoot 'TarayiciEklentisi'
if (Test-Path $extDir) {
    try { Set-Content -Path (Join-Path $extDir 'config.js') -Value "const PORT = $Port;`nconst TOKEN = '$($script:token)';" -Encoding ASCII } catch {}
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="İndirme Yöneticisi" Width="880" Height="640" MinWidth="620" MinHeight="420"
        Background="{DynamicResource Bg}" FontFamily="Segoe UI" WindowStartupLocation="CenterScreen">
  <Window.Resources>
    <SolidColorBrush x:Key="Bg" Color="#0F1117"/>
    <SolidColorBrush x:Key="Card" Color="#181B24"/>
    <SolidColorBrush x:Key="Text" Color="#FFFFFF"/>
    <SolidColorBrush x:Key="Text2" Color="#C9CFDB"/>
    <SolidColorBrush x:Key="Soft" Color="#5E667A"/>
    <SolidColorBrush x:Key="BtnBg" Color="#262B38"/>
    <SolidColorBrush x:Key="Line" Color="#2A2F3D"/>
    <SolidColorBrush x:Key="Track" Color="#262B38"/>
    <SolidColorBrush x:Key="InputBg" Color="#0F1117"/>
    <SolidColorBrush x:Key="IconDim" Color="#2F3547"/>
    <SolidColorBrush x:Key="Accent" Color="#4F7DF3"/>
    <SolidColorBrush x:Key="Muted" Color="#8A93A6"/>

    <Style x:Key="Btn" TargetType="Button">
      <Setter Property="Foreground" Value="{DynamicResource Text}"/>
      <Setter Property="Background" Value="{DynamicResource BtnBg}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Padding" Value="14,9"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="9" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Opacity" Value="0.82"/></Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="bd" Property="Opacity" Value="0.65"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="AccentBtn" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="{StaticResource Accent}"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Padding" Value="22,10"/>
    </Style>
    <Style x:Key="IconBtn" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Width" Value="36"/>
      <Setter Property="Height" Value="36"/>
      <Setter Property="Padding" Value="0"/>
      <Setter Property="Margin" Value="8,0,0,0"/>
    </Style>

    <Style TargetType="TextBox">
      <Setter Property="Foreground" Value="{DynamicResource Text}"/>
      <Setter Property="CaretBrush" Value="{DynamicResource Text}"/>
      <Setter Property="Background" Value="{DynamicResource InputBg}"/>
      <Setter Property="Padding" Value="12,10"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TextBox">
            <Border Background="{TemplateBinding Background}" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="9">
              <ScrollViewer x:Name="PART_ContentHost" Margin="{TemplateBinding Padding}"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="Bar" TargetType="ProgressBar">
      <Setter Property="Height" Value="8"/>
      <Setter Property="Maximum" Value="100"/>
      <Setter Property="Foreground" Value="{StaticResource Accent}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ProgressBar">
            <Grid>
              <Border Background="{DynamicResource Track}" CornerRadius="4"/>
              <Border x:Name="PART_Track"/>
              <Border x:Name="PART_Indicator" HorizontalAlignment="Left" Background="{TemplateBinding Foreground}" CornerRadius="4"/>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Grid Margin="28,24,28,20">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <StackPanel Grid.Row="0" Margin="0,0,0,18">
      <TextBlock Text="İndirmeler" Foreground="{DynamicResource Text}" FontSize="28" FontWeight="SemiBold"/>
      <TextBlock Text="İnternet kesilirse bekler, bilgisayar kapanırsa kaldığı yerden devam eder."
                 Foreground="{DynamicResource Muted}" FontSize="13" Margin="0,4,0,0"/>
    </StackPanel>
    <Button x:Name="ThemeBtn" Grid.Row="0" Style="{StaticResource IconBtn}" HorizontalAlignment="Right"
            VerticalAlignment="Top" ToolTip="Temayı değiştir"/>

    <Border Grid.Row="1" Background="{DynamicResource Card}" CornerRadius="14" Padding="16" Margin="0,0,0,18">
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>

        <Grid Grid.Row="0" Grid.Column="0">
          <TextBox x:Name="UrlBox"/>
          <TextBlock Text="İndirme adresini buraya yapıştır…" Foreground="{DynamicResource Soft}" FontSize="14"
                     IsHitTestVisible="False" Margin="14,0,0,0" VerticalAlignment="Center">
            <TextBlock.Style>
              <Style TargetType="TextBlock">
                <Setter Property="Visibility" Value="Collapsed"/>
                <Style.Triggers>
                  <DataTrigger Binding="{Binding Text, ElementName=UrlBox}" Value="">
                    <Setter Property="Visibility" Value="Visible"/>
                  </DataTrigger>
                </Style.Triggers>
              </Style>
            </TextBlock.Style>
          </TextBlock>
        </Grid>
        <Button x:Name="AddBtn" Grid.Row="0" Grid.Column="1" Content="İndir" Style="{StaticResource AccentBtn}" Margin="12,0,0,0"/>

        <Button x:Name="FolderBtn" Grid.Row="1" Grid.Column="0" Grid.ColumnSpan="2" Margin="0,12,0,0"
                Style="{StaticResource Btn}" HorizontalContentAlignment="Left">
          <StackPanel Orientation="Horizontal">
            <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE838;" Foreground="{DynamicResource Muted}" Margin="0,1,10,0"/>
            <TextBlock x:Name="FolderText" Foreground="{DynamicResource Text2}" TextTrimming="CharacterEllipsis"/>
          </StackPanel>
        </Button>
      </Grid>
    </Border>

    <Grid Grid.Row="2">
      <ScrollViewer VerticalScrollBarVisibility="Auto">
        <ItemsControl x:Name="Items">
          <ItemsControl.ItemTemplate>
            <DataTemplate>
              <Border Background="{DynamicResource Card}" CornerRadius="14" Padding="18,16" Margin="0,0,0,10">
                <Grid>
                  <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                  </Grid.ColumnDefinitions>
                  <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                  </Grid.RowDefinitions>

                  <TextBlock Grid.Row="0" Grid.Column="0" Text="{Binding Name}" Foreground="{DynamicResource Text}" FontSize="15"
                             FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
                  <TextBlock Grid.Row="0" Grid.Column="1" Text="{Binding PctText}" Foreground="{StaticResource Accent}"
                             FontSize="18" FontWeight="SemiBold"/>
                  <TextBlock Grid.Row="1" Grid.ColumnSpan="2" Text="{Binding Status}" Foreground="{DynamicResource Muted}"
                             FontSize="12.5" Margin="0,3,0,10"/>
                  <ProgressBar Grid.Row="2" Grid.ColumnSpan="2" Style="{StaticResource Bar}"
                               Value="{Binding Percent}" IsIndeterminate="{Binding Indeterminate}"/>
                  <TextBlock Grid.Row="3" Grid.Column="0" Text="{Binding Detail}" Foreground="{DynamicResource Text2}" FontSize="12.5"
                             VerticalAlignment="Center" Margin="0,12,0,0"/>
                  <StackPanel Grid.Row="3" Grid.Column="1" Orientation="Horizontal" Margin="0,12,0,0">
                    <Button x:Name="ToggleBtn" Tag="{Binding Id}" Content="{Binding Glyph}" ToolTip="{Binding ToggleTip}"
                            Visibility="{Binding ToggleVisibility}"
                            Style="{StaticResource IconBtn}"/>
                    <Button x:Name="RemoveBtn" Tag="{Binding Id}" Content="&#xE74D;" ToolTip="İptal et / listeden kaldır"
                            Style="{StaticResource IconBtn}"/>
                  </StackPanel>
                </Grid>
              </Border>
            </DataTemplate>
          </ItemsControl.ItemTemplate>
        </ItemsControl>
      </ScrollViewer>

      <StackPanel x:Name="EmptyState" VerticalAlignment="Center" HorizontalAlignment="Center">
        <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE896;" FontSize="48" Foreground="{DynamicResource IconDim}" HorizontalAlignment="Center"/>
        <TextBlock Text="Henüz indirme yok" Foreground="{DynamicResource Muted}" FontSize="15" Margin="0,12,0,0" HorizontalAlignment="Center"/>
        <TextBlock Text="Yukarıya bir adres yapıştırıp İndir'e bas." Foreground="{DynamicResource Soft}" FontSize="12.5" Margin="0,4,0,0" HorizontalAlignment="Center"/>
      </StackPanel>
    </Grid>

    <Grid Grid.Row="3" Margin="2,12,0,0">
      <TextBlock x:Name="Footer" Foreground="{DynamicResource Muted}" FontSize="12.5" VerticalAlignment="Center"/>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="BrowsersBtn" Style="{StaticResource Btn}" Padding="12,6" FontSize="12.5" Margin="0,0,8,0"
                Content="Tarayıcı eklentisi" ToolTip="Yüklü tarayıcıları göster ve eklentiyi kur"/>
        <Button x:Name="AutoStartBtn" Style="{StaticResource Btn}" Padding="12,6" FontSize="12.5"
                ToolTip="Tarayıcı indirmelerinin yakalanması için uygulama açık olmalı"/>
      </StackPanel>
    </Grid>
  </Grid>
</Window>
'@

$window = [Windows.Markup.XamlReader]::Parse($xaml)
$urlBox    = $window.FindName('UrlBox')
$addBtn    = $window.FindName('AddBtn')
$folderBtn = $window.FindName('FolderBtn')
$folderTxt = $window.FindName('FolderText')
$itemsCtl  = $window.FindName('Items')
$empty     = $window.FindName('EmptyState')
$footer    = $window.FindName('Footer')
$autoBtn   = $window.FindName('AutoStartBtn')
$browsersBtn = $window.FindName('BrowsersBtn')

$themes = @{
    dark  = @{ Bg='#0F1117'; Card='#181B24'; Muted='#8A93A6'; Text='#FFFFFF'; Text2='#C9CFDB'; Soft='#5E667A'; BtnBg='#262B38'; Line='#2A2F3D'; Track='#262B38'; InputBg='#0F1117'; IconDim='#2F3547' }
    light = @{ Bg='#F3F5F9'; Card='#FFFFFF'; Muted='#667085'; Text='#141821'; Text2='#3A4252'; Soft='#98A2B3'; BtnBg='#E8ECF3'; Line='#D8DEE8'; Track='#E3E8F0'; InputBg='#F7F9FC'; IconDim='#CBD3E0' }
}
$themeFile = Join-Path $env:APPDATA 'IndirmeYoneticisi.theme'
$script:theme = 'dark'
try { if ((Get-Content $themeFile -ErrorAction Stop | Select-Object -First 1) -eq 'light') { $script:theme = 'light' } } catch {}
$script:hwnd = [IntPtr]::Zero
$themeBtn = $window.FindName('ThemeBtn')

function Apply-Theme {
    foreach ($k in $themes[$script:theme].Keys) {
        [System.Windows.Media.Color]$c = [System.Windows.Media.ColorConverter]::ConvertFromString($themes[$script:theme][$k])
        $window.Resources[$k] = [System.Windows.Media.SolidColorBrush]::new($c)
    }
    # dark: gunes ikonu (aydinliga gec), light: ay ikonu
    $themeBtn.Content = if ($script:theme -eq 'dark') { [string][char]0xE706 } else { [string][char]0xE708 }
    if ($script:hwnd -ne [IntPtr]::Zero) {
        $v = if ($script:theme -eq 'dark') { 1 } else { 0 }
        try { [void][Dwm]::DwmSetWindowAttribute($script:hwnd, 20, [ref]$v, 4) } catch {}
    }
}

$Prefix = 'indir:'
$script:dir = Join-Path $env:USERPROFILE 'Downloads'
$script:last = @{}
$script:coll = New-Object 'System.Collections.ObjectModel.ObservableCollection[DlItem]'
$itemsCtl.ItemsSource = $script:coll
$folderTxt.Text = $script:dir

$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = [System.Drawing.SystemIcons]::Information
$tray.Text = 'İndirme Yöneticisi'
$tray.Visible = $true
$script:quitting = $false

function Show-Window {
    $window.Visibility = 'Visible'
    if ($window.WindowState -eq 'Minimized') { $window.WindowState = 'Normal' }
    [void]$window.Activate()
}
$menu = New-Object System.Windows.Forms.ContextMenuStrip
[void]$menu.Items.Add('Aç', $null, { Show-Window })
[void]$menu.Items.Add('Çıkış', $null, { $script:quitting = $true; $window.Close() })
$tray.ContextMenuStrip = $menu
$tray.Add_DoubleClick({ Show-Window })

# ---- Baslangicta otomatik acilma ----
$startupLnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'Indirme Yoneticisi.lnk'
function Update-AutoBtn {
    $autoBtn.Content = 'Windows ile başlat: ' + $(if (Test-Path $startupLnk) { 'Açık' } else { 'Kapalı' })
}
$autoBtn.Add_Click({
    if (Test-Path $startupLnk) {
        [IO.File]::Delete($startupLnk)
    } else {
        $sh = New-Object -ComObject WScript.Shell
        $lnk = $sh.CreateShortcut($startupLnk)
        $lnk.TargetPath = Join-Path $PSHOME 'powershell.exe'
        $lnk.Arguments = '-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $script:selfPath + '" -Gizli'
        $lnk.WorkingDirectory = Split-Path $script:selfPath
        $lnk.Save()
    }
    Update-AutoBtn
})
Update-AutoBtn

# ---- Tarayici eklentisi kurulumu (yuklu tarayicilari listeler) ----
function Get-ExePath([string]$exe, [string[]]$guess) {
    if ($exe) {
        foreach ($root in 'HKLM:', 'HKCU:') {
            foreach ($sub in 'SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths', 'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths') {
                try {
                    $v = (Get-ItemProperty -Path "$root\$sub\$exe" -ErrorAction Stop).'(default)'
                    if ($v) { $v = $v.Trim('"'); if (Test-Path $v) { return $v } }
                } catch {}
            }
        }
    }
    foreach ($g in $guess) { if ($g -and (Test-Path $g)) { return $g } }
    return $null
}

function Get-Browsers {
    $pf = $env:ProgramFiles; $pf86 = ${env:ProgramFiles(x86)}; $la = $env:LOCALAPPDATA; $ra = $env:APPDATA
    $defs = @(
        @{ Name = 'Google Chrome';   Exe = 'chrome.exe';   Url = 'chrome://extensions';  Data = "$la\Google\Chrome\User Data"
           Guess = @("$pf\Google\Chrome\Application\chrome.exe", "$pf86\Google\Chrome\Application\chrome.exe", "$la\Google\Chrome\Application\chrome.exe") },
        @{ Name = 'Microsoft Edge';  Exe = 'msedge.exe';   Url = 'edge://extensions';    Data = "$la\Microsoft\Edge\User Data"
           Guess = @("$pf86\Microsoft\Edge\Application\msedge.exe", "$pf\Microsoft\Edge\Application\msedge.exe") },
        @{ Name = 'Brave';           Exe = 'brave.exe';    Url = 'brave://extensions';   Data = "$la\BraveSoftware\Brave-Browser\User Data"
           Guess = @("$pf\BraveSoftware\Brave-Browser\Application\brave.exe", "$pf86\BraveSoftware\Brave-Browser\Application\brave.exe", "$la\BraveSoftware\Brave-Browser\Application\brave.exe") },
        @{ Name = 'Opera';           Exe = $null;          Url = 'opera://extensions';   Data = "$ra\Opera Software\Opera Stable"
           Guess = @("$la\Programs\Opera\opera.exe", "$pf\Opera\opera.exe", "$pf86\Opera\opera.exe") },
        @{ Name = 'Opera GX';        Exe = $null;          Url = 'opera://extensions';   Data = "$ra\Opera Software\Opera GX Stable"
           Guess = @("$la\Programs\Opera GX\opera.exe", "$pf\Opera GX\opera.exe") },
        @{ Name = 'Vivaldi';         Exe = 'vivaldi.exe';  Url = 'vivaldi://extensions'; Data = "$la\Vivaldi\User Data"
           Guess = @("$la\Vivaldi\Application\vivaldi.exe", "$pf\Vivaldi\Application\vivaldi.exe") },
        @{ Name = 'Mozilla Firefox'; Exe = 'firefox.exe';  Url = $null;                  Data = $null
           Guess = @("$pf\Mozilla Firefox\firefox.exe", "$pf86\Mozilla Firefox\firefox.exe"); Unsupported = $true }
    )
    # Ek Chromium tabanli tarayicilar: ad, eklentiler sayfasi, profil klasoru, olasi exe yollari
    $more = @(
        @('Chrome Beta',        'chrome://extensions',  "$la\Google\Chrome Beta\User Data",   @("$pf\Google\Chrome Beta\Application\chrome.exe", "$pf86\Google\Chrome Beta\Application\chrome.exe")),
        @('Chrome Dev',         'chrome://extensions',  "$la\Google\Chrome Dev\User Data",    @("$pf\Google\Chrome Dev\Application\chrome.exe", "$pf86\Google\Chrome Dev\Application\chrome.exe")),
        @('Chrome Canary',      'chrome://extensions',  "$la\Google\Chrome SxS\User Data",    @("$la\Google\Chrome SxS\Application\chrome.exe")),
        @('Chromium',           'chrome://extensions',  "$la\Chromium\User Data",             @("$la\Chromium\Application\chrome.exe", "$pf\Chromium\Application\chrome.exe")),
        @('Edge Beta',          'edge://extensions',    "$la\Microsoft\Edge Beta\User Data",  @("$pf86\Microsoft\Edge Beta\Application\msedge.exe", "$pf\Microsoft\Edge Beta\Application\msedge.exe")),
        @('Edge Dev',           'edge://extensions',    "$la\Microsoft\Edge Dev\User Data",   @("$pf86\Microsoft\Edge Dev\Application\msedge.exe", "$pf\Microsoft\Edge Dev\Application\msedge.exe")),
        @('Edge Canary',        'edge://extensions',    "$la\Microsoft\Edge SxS\User Data",   @("$la\Microsoft\Edge SxS\Application\msedge.exe")),
        @('Brave Beta',         'brave://extensions',   "$la\BraveSoftware\Brave-Browser-Beta\User Data",    @("$pf\BraveSoftware\Brave-Browser-Beta\Application\brave.exe")),
        @('Brave Nightly',      'brave://extensions',   "$la\BraveSoftware\Brave-Browser-Nightly\User Data", @("$pf\BraveSoftware\Brave-Browser-Nightly\Application\brave.exe")),
        @('Yandex Browser',     'browser://extensions', "$la\Yandex\YandexBrowser\User Data", @("$la\Yandex\YandexBrowser\Application\browser.exe")),
        @('Cốc Cốc',            'coccoc://extensions',  "$la\CocCoc\Browser\User Data",       @("$pf\CocCoc\Browser\Application\browser.exe", "$pf86\CocCoc\Browser\Application\browser.exe")),
        @('Thorium',            'chrome://extensions',  "$la\Thorium\User Data",              @("$la\Thorium\Application\thorium.exe")),
        @('Avast Secure Browser','chrome://extensions', "$la\AVAST Software\Browser\User Data", @("$pf\AVAST Software\Browser\Application\AvastBrowser.exe")),
        @('Comet',              'chrome://extensions',  "$la\Perplexity\Comet\User Data",     @("$la\Perplexity\Comet\Application\comet.exe")),
        @('Epic Privacy Browser','chrome://extensions', "$la\Epic Privacy Browser\User Data", @("$la\Epic Privacy Browser\Application\epic.exe")),
        @('Opera Developer',    'opera://extensions',   "$ra\Opera Software\Opera Developer", @("$la\Programs\Opera Developer\opera.exe"))
    )
    foreach ($m in $more) {
        $defs += @{ Name = $m[0]; Exe = $null; Url = $m[1]; Data = $m[2]; Guess = $m[3] }
    }
    # Firefox ailesi: desteklenmez ama listede gorunsun
    foreach ($m in @(
        @('Waterfox',        "$pf\Waterfox\waterfox.exe"),
        @('LibreWolf',       "$pf\LibreWolf\librewolf.exe"),
        @('Zen Browser',     "$pf\Zen Browser\zen.exe"),
        @('Floorp',          "$pf\Floorp\floorp.exe"),
        @('Firefox Developer Edition', "$pf\Firefox Developer Edition\firefox.exe"),
        @('Firefox Nightly', "$pf\Firefox Nightly\firefox.exe"))) {
        $defs += @{ Name = $m[0]; Exe = $null; Url = $null; Data = $null; Guess = @($m[1]); Unsupported = $true }
    }

    $seen = @{}
    foreach ($d in $defs) {
        $p = Get-ExePath $d.Exe $d.Guess
        if ($p -and -not $seen.ContainsKey($p.ToLower())) {
            $seen[$p.ToLower()] = $true
            $d.Path = $p
            $d
        }
    }

    # Kayit defterine kayitli ama yukaridaki listede olmayan tarayicilar
    foreach ($root in 'HKLM:', 'HKCU:') {
        $sm = "$root\SOFTWARE\Clients\StartMenuInternet"
        if (-not (Test-Path $sm)) { continue }
        foreach ($k in (Get-ChildItem $sm -ErrorAction SilentlyContinue)) {
            try {
                $cmd = (Get-ItemProperty -Path (Join-Path $k.PSPath 'shell\open\command') -ErrorAction Stop).'(default)'
                if (-not $cmd) { continue }
                $exe = if ($cmd -match '^\s*"([^"]+)"') { $Matches[1] } else { ($cmd -split ' ')[0] }
                if (-not (Test-Path $exe)) { continue }
                if ($exe -match 'iexplore\.exe$') { continue }
                if ($seen.ContainsKey($exe.ToLower())) { continue }
                $seen[$exe.ToLower()] = $true
                $nm = (Get-ItemProperty -Path $k.PSPath -ErrorAction SilentlyContinue).'(default)'
                if (-not $nm) { $nm = $k.PSChildName }
                @{ Name = $nm; Path = $exe; Url = 'chrome://extensions'; Data = $null; Unknown = $true }
            } catch {}
        }
    }
}

function Test-ExtInstalled($b) {
    if (-not $b.Data -or -not (Test-Path $b.Data)) { return $false }
    foreach ($f in (Get-ChildItem $b.Data -Directory -ErrorAction SilentlyContinue)) {
        foreach ($n in 'Secure Preferences', 'Preferences') {
            $pp = Join-Path $f.FullName $n
            if (Test-Path $pp) {
                try { if ((Get-Content $pp -Raw -ErrorAction Stop) -like '*IndirmeEklenti*') { return $true } } catch {}
            }
        }
    }
    return $false
}

function Install-Extension($b) {
    $src = Join-Path $PSScriptRoot 'TarayiciEklentisi'
    $target = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'IndirmeEklenti'
    New-Item -ItemType Directory -Force $target | Out-Null
    Copy-Item (Join-Path $src '*') $target -Force
    try { [System.Windows.Clipboard]::SetText($target) } catch {}
    # Bazi tarayicilar bayragi dogrudan kabul eder; kabul etmeyenler sadece eklentiler sayfasini acar.
    Start-Process -FilePath $b.Path -ArgumentList @("--load-extension=`"$target`"", $b.Url)
    return $target
}

function Show-Browsers {
    if ($script:brOpen) { try { [void]$script:brDlg.Activate() } catch {}; return }
    $script:brOpen = $true
    $dlgXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Tarayıcı eklentisi" Width="580" Height="520" MinWidth="460" MinHeight="360"
        Background="{DynamicResource Bg}" FontFamily="Segoe UI" WindowStartupLocation="CenterScreen">
  <Grid Margin="24,20,24,18">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <StackPanel Grid.Row="0" Margin="0,0,0,16">
      <TextBlock Text="Tarayıcılar" Foreground="{DynamicResource Text}" FontSize="24" FontWeight="SemiBold"/>
      <TextBlock Text="Eklenti, indirmeleri bu uygulamaya yönlendirir. Kurmak istediğin tarayıcıyı seç."
                 Foreground="{DynamicResource Muted}" FontSize="13" Margin="0,4,0,0" TextWrapping="Wrap"/>
    </StackPanel>
    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
      <StackPanel x:Name="List"/>
    </ScrollViewer>
    <TextBlock x:Name="Info" Grid.Row="2" Foreground="{DynamicResource Text2}" FontSize="12.5"
               TextWrapping="Wrap" Margin="0,12,0,0"/>
  </Grid>
</Window>
'@
    $dlg = [Windows.Markup.XamlReader]::Parse($dlgXaml)
    foreach ($k in $themes[$script:theme].Keys) {
        [System.Windows.Media.Color]$c = [System.Windows.Media.ColorConverter]::ConvertFromString($themes[$script:theme][$k])
        $dlg.Resources[$k] = [System.Windows.Media.SolidColorBrush]::new($c)
    }
    $dlg.Resources['Accent'] = $window.Resources['Accent']
    foreach ($k in 'Btn', 'AccentBtn') { $dlg.Resources[$k] = $window.Resources[$k] }
    try { $dlg.Owner = $window; $dlg.WindowStartupLocation = 'CenterOwner' } catch {}

    $script:brList = $dlg.FindName('List')
    $script:brInfo = $dlg.FindName('Info')
    $script:brDlg  = $dlg

    $fill = {
        $list = $script:brList
        $list.Children.Clear()
        $found = @(Get-Browsers)
        if ($found.Count -eq 0) {
            $t = New-Object System.Windows.Controls.TextBlock
            $t.Text = 'Yüklü tarayıcı bulunamadı.'
            $t.Foreground = $script:brDlg.FindResource('Muted')
            [void]$list.Children.Add($t)
        }
        foreach ($b in $found) {
            $card = New-Object System.Windows.Controls.Border
            $card.Background = $script:brDlg.FindResource('Card')
            $card.CornerRadius = [System.Windows.CornerRadius]::new(12)
            $card.Padding = [System.Windows.Thickness]::new(16, 12, 16, 12)
            $card.Margin = [System.Windows.Thickness]::new(0, 0, 0, 10)

            $g = New-Object System.Windows.Controls.Grid
            $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::new(1, 'Star')
            $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = [System.Windows.GridLength]::Auto
            [void]$g.ColumnDefinitions.Add($c1); [void]$g.ColumnDefinitions.Add($c2)

            $sp = New-Object System.Windows.Controls.StackPanel
            $name = New-Object System.Windows.Controls.TextBlock
            $name.Text = $b.Name; $name.FontSize = 15; $name.FontWeight = 'SemiBold'
            $name.Foreground = $script:brDlg.FindResource('Text')
            $st = New-Object System.Windows.Controls.TextBlock
            $st.FontSize = 12.5; $st.Margin = [System.Windows.Thickness]::new(0, 3, 0, 0)
            $st.Foreground = $script:brDlg.FindResource('Muted')
            [void]$sp.Children.Add($name); [void]$sp.Children.Add($st)
            [void]$g.Children.Add($sp)

            $btn = New-Object System.Windows.Controls.Button
            $btn.VerticalAlignment = 'Center'
            [System.Windows.Controls.Grid]::SetColumn($btn, 1)
            if ($b.Unsupported) {
                $st.Text = 'Desteklenmiyor (Chromium tabanlı değil)'
                $btn.Content = 'Desteklenmiyor'; $btn.IsEnabled = $false
                $btn.Style = $script:brDlg.FindResource('Btn')
            } else {
                $inst = Test-ExtInstalled $b
                if ($b.Unknown) {
                    $st.Text = 'Tanınmayan tarayıcı (Chromium tabanlıysa çalışır)'
                    $btn.Content = 'Dene'; $btn.Style = $script:brDlg.FindResource('Btn')
                } elseif ($inst) {
                    $st.Text = 'Eklenti yüklü'; $st.Foreground = $script:brDlg.FindResource('Accent')
                    $btn.Content = 'Yeniden kur'; $btn.Style = $script:brDlg.FindResource('Btn')
                } else {
                    $st.Text = 'Eklenti yüklü değil'
                    $btn.Content = 'Eklentiyi kur'; $btn.Style = $script:brDlg.FindResource('AccentBtn')
                }
                $btn.Tag = $b
                $btn.Add_Click({
                    param($s, $e)
                    $br = $s.Tag
                    try {
                        $p = Install-Extension $br
                        $script:brInfo.Text = "$($br.Name) açıldı. Klasör yolu panoya kopyalandı ($p).`nAçılan sayfada: Geliştirici modu'nu aç → Paketlenmemiş öğe yükle → Ctrl+V → Klasör seç."
                    } catch {
                        $script:brInfo.Text = "Kurulum başlatılamadı: $($_.Exception.Message)"
                    }
                })
            }
            [void]$g.Children.Add($btn)
            $card.Child = $g
            [void]$list.Children.Add($card)
        }
    }
    & $fill
    $script:brFill = $fill
    $dlg.Add_Activated({ & $script:brFill })
    try { [void]$dlg.ShowDialog() } finally { $script:brOpen = $false }
}
$browsersBtn.Add_Click({ Show-Browsers })

function Fmt([double]$b) {
    if ($b -ge 1GB) { '{0:N2} GB' -f ($b / 1GB) }
    elseif ($b -ge 1MB) { '{0:N1} MB' -f ($b / 1MB) }
    else { '{0:N0} KB' -f ($b / 1KB) }
}

function StateText($s) {
    switch ("$s") {
        'Queued'         { 'Sırada' }
        'Connecting'     { 'Bağlanıyor…' }
        'Transferring'   { 'İndiriliyor' }
        'Suspended'      { 'Duraklatıldı' }
        'TransientError' { 'İnternet yok, bağlantı gelince devam edecek' }
        'Error'          { 'Hata oluştu, tekrar deneniyor' }
        default          { "$s" }
    }
}

function Get-Jobs { @(Get-BitsTransfer -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "$Prefix*" }) }

function Start-Download([string]$u, [string]$ad) {
    $uri = $null
    if (-not [uri]::TryCreate($u, 'Absolute', [ref]$uri) -or $uri.Scheme -notin 'http', 'https') {
        throw 'Geçerli bir http/https adresi gir.'
    }
    $ad = (($ad -replace '[\x00-\x1f"<>|*?:]', '_') -split '[\\/]')[-1].Trim()
    if (-not $ad) {
        $ad = [System.Net.WebUtility]::UrlDecode($uri.AbsolutePath)
        $ad = (($ad -replace '[\x00-\x1f"<>|*?:]', '_') -split '[\\/]')[-1].Trim()
    }
    if (-not $ad) { $ad = 'indirilen_dosya' }
    New-Item -ItemType Directory -Force $script:dir | Out-Null
    $yol = Join-Path $script:dir $ad
    $n = 1
    while (Test-Path $yol) {
        $yol = Join-Path $script:dir ('{0} ({1}){2}' -f [IO.Path]::GetFileNameWithoutExtension($ad), $n, [IO.Path]::GetExtension($ad))
        $n++
    }
    Start-BitsTransfer -Source $u -Destination $yol -DisplayName "$Prefix$([IO.Path]::GetFileName($yol))" `
        -Asynchronous -Priority Foreground -RetryInterval 60 -RetryTimeout 1209600 | Out-Null
    return [IO.Path]::GetFileName($yol)
}

function Add-Download {
    try {
        [void](Start-Download $urlBox.Text.Trim() '')
        $urlBox.Text = ''
        Refresh-List
    } catch {
        [void][System.Windows.MessageBox]::Show($_.Exception.Message, 'İndirme başlatılamadı')
    }
}

# ---- Tarayici eklentisinden gelen istekleri dinle (sadece 127.0.0.1, anahtar zorunlu) ----
function Handle-Request($ctx) {
    $req = $ctx.Request
    $res = $ctx.Response
    $code = 403
    try {
        if ($req.HttpMethod -eq 'POST' -and $req.Headers['X-Token'] -eq $script:token) {
            switch ($req.Url.AbsolutePath) {
                '/ping' { $code = 200 }
                '/show' { Show-Window; $code = 200 }
                '/add' {
                    if ($req.ContentLength64 -gt 0 -and $req.ContentLength64 -lt 65536) {
                        $sr = New-Object IO.StreamReader($req.InputStream, [Text.Encoding]::UTF8)
                        $d = $sr.ReadToEnd() | ConvertFrom-Json
                        $ad = Start-Download ([string]$d.url) ([string]$d.filename)
                        $tray.ShowBalloonTip(2500, 'Tarayıcıdan yakalandı', $ad, 'Info')
                        Refresh-List
                        $code = 200
                    } else { $code = 400 }
                }
            }
        }
    } catch { $code = 500 }
    try { $res.StatusCode = $code; $res.Close() } catch {}
}

$script:listener = New-Object System.Net.HttpListener
$script:listener.Prefixes.Add("http://127.0.0.1:$Port/")
$script:pending = $null
try { $script:listener.Start(); $script:pending = $script:listener.GetContextAsync() } catch {}
function Find-Item([string]$id) {
    foreach ($it in $script:coll) { if ($it.Id -eq $id) { return $it } }
    return $null
}

function Refresh-List {
    $seen = @{}
    $totalSpeed = 0.0
    $active = 0
    foreach ($j in (Get-Jobs)) {
        $id = "$($j.JobId)"
        $seen[$id] = $true
        $state = "$($j.JobState)"
        $item = Find-Item $id
        if (-not $item) {
            $item = New-Object DlItem
            $item.Id = $id
            $item.Name = $j.DisplayName.Substring($Prefix.Length)
            try { $item.Path = $j.FileList[0].LocalName } catch {}
            $script:coll.Insert(0, $item)
        }

        if ($state -eq 'Transferred') {
            try { Complete-BitsTransfer $j } catch {}
            $item.Done = $true
            $item.Percent = 100
            $item.PctText = ''
            $item.Indeterminate = $false
            $item.Status = 'Tamamlandı'
            $item.Detail = (Fmt ([double]$j.BytesTransferred))
            $tray.ShowBalloonTip(3000, 'İndirme tamamlandı', $item.Name, 'Info')
            continue
        }
        if ($state -eq 'Error') { try { Resume-BitsTransfer $j -Asynchronous | Out-Null } catch {} }

        $total = [double]$j.BytesTotal
        $done = [double]$j.BytesTransferred
        $known = ($total -gt 0 -and $total -lt 1e15)

        $speedText = ''
        $now = Get-Date
        if ($script:last.ContainsKey($id) -and $state -eq 'Transferring') {
            $dt = ($now - $script:last[$id].t).TotalSeconds
            if ($dt -gt 0) {
                $sp = ($done - $script:last[$id].b) / $dt
                if ($sp -lt 0) { $sp = 0 }
                $totalSpeed += $sp
                $speedText = ' · {0}/sn' -f (Fmt $sp)
            }
        }
        $script:last[$id] = @{ t = $now; b = $done }
        if ($state -eq 'Transferring') { $active++ }

        $item.Paused = ($state -eq 'Suspended')
        $item.Status = StateText $state
        if ($known) {
            $item.Indeterminate = $false
            $item.Percent = [math]::Round(100 * $done / $total, 1)
            $item.PctText = '%{0}' -f [int](100 * $done / $total)
            $item.Detail = ('{0} / {1}{2}' -f (Fmt $done), (Fmt $total), $speedText)
        } else {
            $item.Indeterminate = ($state -eq 'Transferring' -or $state -eq 'Connecting')
            $item.PctText = ''
            $item.Detail = ('{0}{1}' -f (Fmt $done), $speedText)
        }
    }

    # BITS'te artik olmayan ve tamamlanmamis kayitlari kaldir (iptal edilenler)
    for ($i = $script:coll.Count - 1; $i -ge 0; $i--) {
        $it = $script:coll[$i]
        if (-not $it.Done -and -not $seen.ContainsKey($it.Id)) { $script:coll.RemoveAt($i) }
    }

    $empty.Visibility = if ($script:coll.Count -eq 0) { 'Visible' } else { 'Collapsed' }
    if ($active -gt 0) {
        $footer.Text = '{0} aktif indirme · {1}/sn' -f $active, (Fmt $totalSpeed)
    } else {
        $footer.Text = 'Aktif indirme yok'
    }
}

# ---- Olaylar ----
$addBtn.Add_Click({ Add-Download })
$themeBtn.Add_Click({
    $script:theme = if ($script:theme -eq 'dark') { 'light' } else { 'dark' }
    Apply-Theme
    try { Set-Content -Path $themeFile -Value $script:theme -Encoding ASCII } catch {}
})
$urlBox.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Return') { Add-Download } })

$folderBtn.Add_Click({
    $fd = New-Object System.Windows.Forms.FolderBrowserDialog
    $fd.SelectedPath = $script:dir
    if ($fd.ShowDialog() -eq 'OK') { $script:dir = $fd.SelectedPath; $folderTxt.Text = $script:dir }
})

$itemsCtl.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($s, $e)
    $b = $e.OriginalSource -as [System.Windows.Controls.Button]
    if (-not $b -or -not $b.Tag) { return }
    $id = "$($b.Tag)"
    $item = Find-Item $id
    $job = Get-BitsTransfer -ErrorAction SilentlyContinue | Where-Object { "$($_.JobId)" -eq $id } | Select-Object -First 1

    if ($b.Name -eq 'ToggleBtn') {
        if ($job) {
            if ("$($job.JobState)" -eq 'Suspended') { Resume-BitsTransfer $job -Asynchronous | Out-Null }
            else { Suspend-BitsTransfer $job | Out-Null }
        }
    } elseif ($b.Name -eq 'RemoveBtn') {
        if ($item -and $item.Done) {
            [void]$script:coll.Remove($item)
        } else {
            $r = [System.Windows.MessageBox]::Show('Bu indirme iptal edilsin ve yarım dosya silinsin mi?', 'İptal', 'YesNo')
            if ($r -eq 'Yes' -and $job) { Remove-BitsTransfer $job }
        }
    }
    Refresh-List
})

$window.Add_SourceInitialized({
    # Koyu baslik cubugu (Windows 10 20H1+ / 11)
    try {
        $script:hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($window)).Handle
        Apply-Theme
    } catch {}
})

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({ Refresh-List })

$netTimer = New-Object System.Windows.Threading.DispatcherTimer
$netTimer.Interval = [TimeSpan]::FromMilliseconds(250)
$netTimer.Add_Tick({
    for ($n = 0; $n -lt 20 -and $script:pending -and $script:pending.IsCompleted; $n++) {
        $ctx = $null
        try { $ctx = $script:pending.Result } catch {}
        try { $script:pending = $script:listener.GetContextAsync() } catch { $script:pending = $null }
        if ($ctx) { Handle-Request $ctx }
    }
})

$window.Add_Closing({
    param($s, $e)
    if (-not $script:quitting) {
        $e.Cancel = $true
        $window.Visibility = 'Hidden'
        try { $tray.ShowBalloonTip(2000, 'İndirme Yöneticisi', 'Arka planda çalışmaya devam ediyor.', 'Info') } catch {}
    }
})

$window.Add_Loaded({
    Apply-Theme
    $netTimer.Start()
    if ($script:Gizli) { $window.Visibility = 'Hidden' }
    try {
        $c = [System.Windows.Clipboard]::GetText()
        if ($c -match '^https?://\S+$') { $urlBox.Text = $c }
    } catch {}
    # Onceki oturumdan kalan duraklamis isleri devam ettir
    foreach ($j in (Get-Jobs)) {
        if ("$($j.JobState)" -in 'Suspended', 'Error') { try { Resume-BitsTransfer $j -Asynchronous | Out-Null } catch {} }
    }
    Refresh-List
    $timer.Start()
})
$window.Add_Closed({
    $timer.Stop(); $netTimer.Stop()
    try { $script:listener.Stop() } catch {}
    $tray.Visible = $false; $tray.Dispose()
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown()
})

# ShowDialog() pencere gizlenince biter ve program kapanirdi; Show + Dispatcher ile arka planda yasar.
$window.Show()
[System.Windows.Threading.Dispatcher]::Run()
