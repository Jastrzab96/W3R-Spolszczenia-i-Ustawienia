$RepoZipUrl = "https://github.com/Jastrzab96/W3R-Spolszczenia-i-Ustawienia/archive/refs/heads/main.zip"

$FileName = "Spolszczenia i Ustawienia W3R.zip"
$Dir = Get-Location
$FilePath = Join-Path $Dir $FileName
$DocumentsFolder = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "The Witcher 3"

Write-Host "Pobieranie archiwum ze spolszczeniami, ustawieniami i priorytetami..."
Invoke-WebRequest `
    -Uri $RepoZipUrl `
    -OutFile $FilePath `
    -UseBasicParsing

if (-Not (Test-Path $FilePath)) {
    Write-Error "Nie udalo sie pobrac archiwum ZIP!"
    exit 1
}

#Write-Host "Rozpakowywanie..."
Expand-Archive -Path $FilePath -DestinationPath $Dir -Force

Write-Host "Kopiuje rozpakowane spolszczenia do folderu z gra..."
Copy-Item -Path "$Dir\W3R-Spolszczenia-i-Ustawienia-main\Spolszczenia\*" -Destination $Dir -Recurse -Force

Write-Host "Kopiuje rozpakowane ustawienia do folderu Moje Dokumenty\The Witcher 3..."
Copy-Item -Path "$Dir\W3R-Spolszczenia-i-Ustawienia-main\Documents\*" -Destination $DocumentsFolder -Recurse -Force

#Write-Host "Usuwanie ZIP..."
Remove-Item "$Dir\W3R-Spolszczenia-i-Ustawienia-main" -Recurse -Force
Remove-Item $FilePath

Write-Host "Zrobione!"

pause