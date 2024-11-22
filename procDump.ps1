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

$dumpProcesses = @()
$startTime = Get-Date
while (-not $toolProcess.HasExited) {

    # break after 1 minute as the tool process will likely never exit
    $currentTime = Get-Date
    $elapsedTime = $currentTime - $startTime

    if ($elapsedTime.TotalMinutes -ge 1) {
        Write-Host "Ending, 1 minute has passed."
        break
    }

    $commandLines = Get-CimInstance Win32_Process | Select-Object ProcessId, Name, CommandLine
    foreach ($commandLine in $commandLines) {
        if ($dumpProcesses -contains $commandLine.ProcessId) {
            continue
        }

        if ($commandLine.CommandLine -like "*ModernUOSchemaGenerator.dll*") {
            $dumpProcesses += $commandLine.ProcessId
            Write-Host "Attaching to tool process: $($commandLine.ProcessId), Name: $($commandLine.Name), CommandLine: $($commandLine.CommandLine)"
            $dmp = Run-Process "$procDumpFolder\procdump.exe" "-accepteula -ma -s 5 -n 5 $($commandLine.ProcessId) $procDumpFolder\Tool_PROCESSNAME_YYMMDD_HHMMSS.dmp"

        }
        if ($commandLine.CommandLine -like "*Microsoft.CodeAnalysis.Workspaces.MSBuild.BuildHost.dll*") {
            $dumpProcesses += $commandLine.ProcessId
            Write-Host "Attaching to build host process: $($commandLine.ProcessId), Name: $($commandLine.Name), CommandLine: $($commandLine.CommandLine)"
            $dmp = Run-Process "$procDumpFolder\procdump.exe" "-accepteula -ma -s 5 -n 5 $($commandLine.ProcessId) $procDumpFolder\BuildHost_PROCESSNAME_YYMMDD_HHMMSS.dmp "
        }
    }
    
    Start-Sleep -Seconds 1
}

if (-not $toolProcess.HasExited) {
    $toolProcess.Kill()
}

