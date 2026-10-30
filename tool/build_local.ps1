param([ValidateSet('web','apk','run')][string]$Target='apk')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
  if (!(Test-Path -LiteralPath 'config/firebase.local.json')) { throw 'config/firebase.example.json dosyasını firebase.local.json olarak kopyalayıp kendi Firebase anahtarlarını gir.' }
  if($Target -eq 'web') {
    if (!(Test-Path -LiteralPath 'config/google_maps.local.json')) { throw 'config/google_maps.local.json dosyasını örnek yapılandırmadan oluştur.' }
    node tool/prepare_google_maps.cjs
    if ($LASTEXITCODE -ne 0) { throw 'Google Maps yapılandırması hazırlanamadı.' }
    flutter build web --dart-define-from-file=config/firebase.local.json --no-wasm-dry-run
  } elseif($Target -eq 'apk') {
    if (!(Test-Path -LiteralPath 'android/app/google-services.json')) { throw 'Firebase Console üzerinden Android google-services.json dosyasını indirip android/app içine yerleştir.' }
    flutter build apk --debug --dart-define-from-file=config/firebase.local.json
  } else {
    flutter run --dart-define-from-file=config/firebase.local.json
  }
  if($LASTEXITCODE -ne 0) { throw 'Flutter işlemi başarısız oldu.' }
} finally { Pop-Location }
