# Builds a self-contained Windows release zip that runs on PCs without the
# VC++ redistributable installed. Run from the repo root on Windows:
#   powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1
$ErrorActionPreference = 'Stop'

flutter pub get
flutter build windows --release

# Flutter's Windows runner links the MSVC runtime dynamically; ship the DLLs
# next to the exe so it starts on machines that lack them.
$vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
$crt = Get-ChildItem "$vs\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT" -Directory | Sort-Object FullName -Descending | Select-Object -First 1
$out = 'build\windows\x64\runner\Release'
foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
  Copy-Item "$($crt.FullName)\$dll" $out
}

Remove-Item -Recurse -Force dist -ErrorAction SilentlyContinue
New-Item -ItemType Directory dist | Out-Null
Copy-Item -Recurse $out dist\Quadcraft
Compress-Archive -Path dist\Quadcraft -DestinationPath dist\Quadcraft-windows-x64.zip
Write-Host "Done: dist\Quadcraft-windows-x64.zip"
