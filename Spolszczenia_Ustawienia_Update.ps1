
$ErrorActionPreference = "Stop"

# ==========================================
# KONFIGURACJA
# ==========================================

$Url = "https://github.com/Jastrzab96/W3R-Spolszczenia-i-Ustawienia/archive/refs/heads/main.zip"

# Folder, w którym znajduje się skrypt
$ScriptFolder = $PSScriptRoot

# Pliki tymczasowe w folderze systemowym TEMP
$TempFolder = Join-Path $env:TEMP ("W3R-Installer-" + [guid]::NewGuid().ToString())
$ZipPath = Join-Path $TempFolder "repozytorium.zip"
$ExtractPath = Join-Path $TempFolder "wypakowane"

# Docelowy folder Dokumenty\The Witcher 3
$DocumentsFolder = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "The Witcher 3"

try {
    # ==========================================
    # 1. Przygotowanie katalogu tymczasowego
    # ==========================================

    New-Item -Path $TempFolder -ItemType Directory -Force | Out-Null

    Write-Host "Pobieranie repozytorium z GitHuba..." -ForegroundColor Cyan

    # ==========================================
    # 2. Pobieranie archiwum
    # ==========================================

    Invoke-WebRequest -Uri $Url -OutFile $ZipPath

    Write-Host "Pobieranie zakończone." -ForegroundColor Green

    # ==========================================
    # 3. Wypakowanie archiwum
    # ==========================================

    Write-Host "Wypakowywanie archiwum..." -ForegroundColor Cyan

    Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force

    $RepoFolder = Join-Path $ExtractPath "W3R-Spolszczenia-i-Ustawienia-main"
    $RepoFolder = Join-Path $RepoFolder "W3R-Spolszczenia-i-Ustawienia-main"

    if (-not (Test-Path $RepoFolder)) {
        throw "Nie znaleziono oczekiwanego folderu repozytorium: $RepoFolder"
    }

    # ==========================================
    # 4. Kopiowanie spolszczeń do folderu skryptu
    # ==========================================

    $LocalizationSource = Join-Path $RepoFolder "Spolszczenia"

    if (-not (Test-Path $LocalizationSource -PathType Container)) {
        throw "Nie znaleziono folderu Spolszczenia: $LocalizationSource"
    }

    Write-Host "Kopiowanie spolszczeń do folderu skryptu..." -ForegroundColor Cyan

    # Kopiuje zawartość folderu, wymuszając nadpisanie plików
    Copy-Item -Path (Join-Path $LocalizationSource "*") `
              -Destination $ScriptFolder `
              -Recurse -Force

    Write-Host "Spolszczenia zostały skopiowane." -ForegroundColor Green

    # ==========================================
    # 5. Kopiowanie ustawień do Dokumenty\The Witcher 3
    # ==========================================

    $SettingsSource = Join-Path $RepoFolder "Documents"

    if (-not (Test-Path $SettingsSource -PathType Container)) {
        throw "Nie znaleziono folderu Documents: $SettingsSource"
    }

    # Utworzenie katalogu docelowego, jeśli nie istnieje
    New-Item -Path $DocumentsFolder -ItemType Directory -Force | Out-Null

    Write-Host "Kopiowanie ustawień do folderu Dokumenty\The Witcher 3..." -ForegroundColor Cyan

    # Kopiuje zawartość folderu, wymuszając nadpisanie plików
    Copy-Item -Path (Join-Path $SettingsSource "*") `
              -Destination $DocumentsFolder `
              -Recurse -Force

    Write-Host "Ustawienia zostały skopiowane." -ForegroundColor Green

    Write-Host ""
    Write-Host "Instalacja zakończona pomyślnie!" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "Wystąpił błąd: $($_.Exception.Message)" -ForegroundColor Red
    throw
}
finally {
    # ==========================================
    # 6. Sprzątanie plików tymczasowych
    # ==========================================

    if (Test-Path $TempFolder) {
        Write-Host "Usuwanie archiwum i plików tymczasowych..." -ForegroundColor Cyan

        Remove-Item -Path $TempFolder -Recurse -Force -ErrorAction SilentlyContinue

        Write-Host "Sprzątanie zakończone." -ForegroundColor Green
    }
}
