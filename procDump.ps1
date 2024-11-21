param (
    [Parameter(Mandatory=$true)][string]$procDumpFolder
)

function Unzip([string]$zipfile, [string]$outpath) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

function New-Directory([string[]] $path) {
    New-Item -Path $path -Force -ItemType 'Directory' | Out-Null
}

function Run-Process([string]$fileName, [string]$arguments) {
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $fileName
    $processInfo.RedirectStandardError = $true
    $processInfo.RedirectStandardOutput = $true
    $processInfo.UseShellExecute = $false
    $processInfo.Arguments = $arguments
    $processInfo.WorkingDirectory = $PSScriptRoot
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo

    $OutEvent = Register-ObjectEvent -Action {
        Write-Host $Event.SourceEventArgs.Data
    } -InputObject $process -EventName OutputDataReceived
    
    $ErrEvent = Register-ObjectEvent -Action {
        Write-Host $Event.SourceEventArgs.Data
    } -InputObject $process -EventName ErrorDataReceived

    $process.Start() | Out-Null

    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()

    return $process
}

Write-Host "Procdump folder: $procDumpFolder"

$filePath = Join-Path $procDumpFolder "procdump.exe"
if (-not (Test-Path $filePath)) {
    Write-Host "Downloading procdump"
    New-Directory $procDumpFolder
    $zipFilePath = Join-Path $procDumpFolder "procdump.zip"
    Invoke-WebRequest "https://download.sysinternals.com/files/Procdump.zip" -UseBasicParsing -outfile $zipFilePath | Out-Null
    Unzip $zipFilePath $procDumpFolder
}

#$process = Start-Process -FilePath "dotnet.exe" -PassThru -ArgumentList "tool run ModernUOSchemaGenerator -- ModernUO.sln"
$toolProcess = Run-Process "dotnet.exe" "tool run ModernUOSchemaGenerator -- ModernUO.sln"
$dumpProcess = Run-Process "$procDumpFolder\procdump.exe" "-accepteula -ma -s 5 -n 5 $($toolProcess.Id) $procDumpFolder"

while (-not $dumpProcess.HasExited) {
    Start-Sleep -Seconds 1
}

$toolProcess.Kill()

# Start-Sleep -Seconds 30

# $dumpProcess = Run-Process "$procDumpFolder\procdump.exe" "-accepteula -ma -h $($toolProcess.Id) $procDumpFolder"
# $dumpProcess.WaitForExit()

