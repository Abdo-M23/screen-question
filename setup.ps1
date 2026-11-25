# Run from Windows PowerShell as the account that will use Screen Question.
& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    $installDir = Join-Path $env:LOCALAPPDATA 'ScreenQuestion'
    $codexVersion = '0.172.0'
    $portableDir = Join-Path $env:LOCALAPPDATA "CodexPortable\$codexVersion"
    $portableExe = Join-Path $portableDir 'codex.exe'

    function Set-ScreenQuestionPath([string[]] $Directories) {
        $userEnvironment = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
        try {
            $userPath = [string] $userEnvironment.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
            $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
            $savedEntries = [Environment]::ExpandEnvironmentVariables("$machinePath;$userPath") -split ';' |
                ForEach-Object { $_.Trim().Trim('"').TrimEnd('\') }
            $missing = $Directories | Where-Object { $savedEntries -notcontains $_.TrimEnd('\') }

            if ($missing) {
                # Preserve expandable entries such as %USERPROFILE%\bin as written.
                $kind = [Microsoft.Win32.RegistryValueKind]::ExpandString
                if ($userEnvironment.GetValueNames() -contains 'Path') {
                    $kind = $userEnvironment.GetValueKind('Path')
                }
                $newPath = (@($userPath.TrimEnd(';')) + @($missing) | Where-Object { $_ }) -join ';'
                $userEnvironment.SetValue('Path', $newPath, $kind)
            }
        } finally {
            $userEnvironment.Dispose()
        }

        foreach ($dir in $Directories) {
            $sessionEntries = $env:Path -split ';' | ForEach-Object { $_.Trim().Trim('"').TrimEnd('\') }
            if ($sessionEntries -notcontains $dir.TrimEnd('\')) {
                $env:Path = "$dir;$env:Path"
            }
        }

        if ($missing) {
            # Refresh the environment inherited by new windows opened from Explorer.
            if (-not ('ScreenQuestion.SetupEnvironment' -as [type])) {
                Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace ScreenQuestion {
    public static class SetupEnvironment {
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern IntPtr SendMessageTimeout(IntPtr window, uint message,
            UIntPtr wParam, string lParam, uint flags, uint timeout, out UIntPtr result);

        public static void Refresh() {
            UIntPtr result;
            SendMessageTimeout(new IntPtr(0xffff), 0x001a, UIntPtr.Zero, "Environment", 2, 1000, out result);
        }
    }
}
'@
            }
            [ScreenQuestion.SetupEnvironment]::Refresh()
        }
    }

    function Install-ScreenQuestionCodex {
        $cpu = if ($env:PROCESSOR_ARCHITEW6432) {
            $env:PROCESSOR_ARCHITEW6432
        } else {
            $env:PROCESSOR_ARCHITECTURE
        }

        switch ($cpu) {
            'AMD64' {
                $target = 'x86_64-pc-windows-msvc'
                $sha256 = 'c4292fc0414fc78682e733ff570ddec377922ebe1a29925a6d5bcc5aeff43ea0'
            }
            'ARM64' {
                $target = 'aarch64-pc-windows-msvc'
                $sha256 = '47cbee9581170042bb8cbc946329459933a542abcf4060fa59246316744a60ac'
            }
            default { throw "Unsupported Windows architecture: $cpu" }
        }

        $asset = "codex-$target.exe"
        $zip = Join-Path $env:TEMP ('screen-question-' + [guid]::NewGuid().ToString('N') + '.zip')
        $download = "https://github.com/openai/codex/releases/download/rust-v$codexVersion/$asset.zip"

        try {
            Write-Host "Downloading Codex CLI $codexVersion (about 200 MB)..."
            Invoke-WebRequest -UseBasicParsing -Uri $download -OutFile $zip
            if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne $sha256) {
                throw 'The Codex ZIP did not match its published SHA-256.'
            }

            Expand-Archive -LiteralPath $zip -DestinationPath $portableDir -Force
            $assetExe = Join-Path $portableDir $asset
            $installedVersion = & $assetExe --version
            if ($LASTEXITCODE -ne 0 -or $installedVersion -notlike "codex-cli $codexVersion*") {
                throw 'The extracted Codex CLI did not report the expected version.'
            }
            Move-Item -LiteralPath $assetExe -Destination $portableExe
        } finally {
            Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        }
    }

    function Test-ScreenQuestionLogin([string] $CodexExe) {
        # Codex writes its login status to stderr on some versions.
        $ErrorActionPreference = 'Continue'
        $status = & $CodexExe login status 2>&1
        return $LASTEXITCODE -eq 0 -and ($status -join ' ') -match 'Logged in using ChatGPT'
    }

    [void] [IO.Directory]::CreateDirectory($installDir)
    $lockPath = Join-Path $installDir 'setup.lock'
    try {
        $setupLock = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    } catch [IO.IOException] {
        throw "Could not acquire the setup lock. Close any other Screen Question setup and retry. $($_.Exception.Message)"
    }

    $pendingScript = Join-Path $installDir 'Screen-Question-Hotkey.download'
    try {
        $codexCommand = Get-Command codex.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        $standaloneExe = Join-Path $env:LOCALAPPDATA 'Programs\OpenAI\Codex\bin\codex.exe'
        if ($codexCommand) {
            $codexExe = $codexCommand.Source
        } elseif (Test-Path -LiteralPath $portableExe -PathType Leaf) {
            $codexExe = $portableExe
        } elseif (Test-Path -LiteralPath $standaloneExe -PathType Leaf) {
            $codexExe = $standaloneExe
        } else {
            Install-ScreenQuestionCodex
            $codexExe = $portableExe
        }

        $listenerUrl = 'https://raw.githubusercontent.com/Abdo-M23/screen-question/main/Screen-Question-Hotkey.ps1'
        Invoke-WebRequest -UseBasicParsing -Uri $listenerUrl -OutFile $pendingScript
        $tokens = $null
        $parseErrors = $null
        $listener = [System.Management.Automation.Language.Parser]::ParseFile($pendingScript, [ref] $tokens, [ref] $parseErrors)
        if ($parseErrors -or -not $listener.ParamBlock) {
            throw 'The downloaded listener was not a valid PowerShell script.'
        }
        Unblock-File -LiteralPath $pendingScript
        Move-Item -LiteralPath $pendingScript -Destination (Join-Path $installDir 'Screen-Question-Hotkey.ps1') -Force

        $launcher = @'
@echo off
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0Screen-Question-Hotkey.ps1" %*
'@
        $launcherPath = Join-Path $installDir 'screen-question.cmd'
        [IO.File]::WriteAllText($launcherPath, ($launcher -replace '\r?\n', "`r`n") + "`r`n", [Text.Encoding]::ASCII)
        Set-ScreenQuestionPath @($installDir, (Split-Path -Parent $codexExe))
    } finally {
        Remove-Item -LiteralPath $pendingScript -Force -ErrorAction SilentlyContinue
        $setupLock.Dispose()
    }

    if (-not (Test-ScreenQuestionLogin $codexExe)) {
        Write-Host 'Complete the Codex device sign-in using the link and code below.'
        & $codexExe login --device-auth
        if ($LASTEXITCODE -ne 0 -or -not (Test-ScreenQuestionLogin $codexExe)) {
            Write-Host 'If device sign-in is unavailable, run codex login for browser sign-in.'
            return
        }
    }

    Write-Host 'Ready. Run screen-question to start listening.'
}
