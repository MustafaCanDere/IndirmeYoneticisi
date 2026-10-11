# IndirmeYoneticisi.exe uretir (.NET Framework 4 derleyicisi, ek arac gerekmez).
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$csc = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $csc)) { throw 'csc.exe bulunamadi (.NET Framework 4 gerekli).' }

$res = @(
    "/resource:$here\IndirmeYoneticisi.ps1,app/IndirmeYoneticisi.ps1"
)
foreach ($f in Get-ChildItem "$here\TarayiciEklentisi" -File) {
    $res += "/resource:$($f.FullName),app/TarayiciEklentisi/$($f.Name)"
}

New-Item -ItemType Directory -Force "$here\dist" | Out-Null
& $csc /nologo /target:winexe /optimize+ /out:"$here\dist\IndirmeYoneticisi.exe" `
    /reference:System.Windows.Forms.dll @res "$here\Launcher.cs"
if ($LASTEXITCODE -ne 0) { throw 'Derleme basarisiz.' }
Write-Host "Hazir: $here\dist\IndirmeYoneticisi.exe"
