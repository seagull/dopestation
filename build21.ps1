# SEAGULL
# ================================================
$varBuildString = "Dopestation v3.0.21: July 2018 by seagull"
$varScriptDir = split-path -parent $MyInvocation.MyCommand.Definition
$varScriptName = $MyInvocation.MyCommand.Name
$ErrorActionPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# Cosmetics
[console]::WindowWidth=95
[console]::BufferWidth=[console]::WindowWidth
[console]::WindowHeight=25
$progressPreference = 'silentlyContinue'
$Host.UI.RawUI.BackgroundColor = 'Black'
$Host.UI.RawUI.ForegroundColor = 'Gray'
clear-host

# BIG-BOY ZONE (function area)
# ============================

Function Get-FileName($varScriptDir) {
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $varScriptDir
    $OpenFileDialog.filter = "All Files (*.*)| *.*"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

function makeSettings {
    write-host " $varBuildString" -ForegroundColor red
    write-host "════════════════════════════════════════════"
    write-host " Generating a settings file..." -ForegroundColor Red
    write-host " Working directory is $varScriptDir`."
    write-host "════════════════════════════════════════════"

    #produce an XML file
    [xml]$varDatabase = New-Object System.Xml.XmlDocument
    $varDatabase.AppendChild($varDatabase.CreateXmlDeclaration("1.0","UTF-8",$null)) | out-null
    $varDatabaseRoot = $varDatabase.CreateNode("element","seagull",$null)

    #write the build string to it
    $varDatabaseApp = $varDatabase.CreateNode("element","node",$null)
    $varDatabaseApp.SetAttribute("name","version")
    $varDatabaseApp.InnerText = $varBuildString
    $varDatabaseRoot.AppendChild($varDatabaseApp) | out-null

    # IRC CLIENT

    $Host.UI.RawUI.FlushInputBuffer()
    $choiceInput = Read-Host "1. Do you use either Discord or an IRC client? (Y/N)"
    switch ($choiceInput) {
        default {
            write-host " - Setting marked as NO."
        }

        y {
            write-host " - Please locate your preferred chat client executable. " -ForegroundColor Cyan -NoNewline
            cmd /c pause

            $varXMLIRCClient = Get-Filename

            if (!$varXMLIRCClient) {
                write-host "   ERROR: No file selected. Setting marked to NO."
            } else {
                #write this information to the database
                $varDatabaseApp = $varDatabase.CreateNode("element","node",$null)
                $varDatabaseApp.SetAttribute("name","IRC")
                $varDatabaseApp.InnerText = $varXMLIRCClient
                $varDatabaseRoot.AppendChild($varDatabaseApp) | out-null
                write-host " + Setting saved!" -ForegroundColor Green
            }
        }
    }

    # MEDIA PLAYER

    write-host `r
    
    $Host.UI.RawUI.FlushInputBuffer()
    $choiceInput = Read-Host "2: Would you like to nominate a media player? (Y/N)"
    switch ($choiceInput) {
        default {
            $varMediaDeclined=$true
        }

        y {
            write-host " - Please locate media player executable. " -ForegroundColor Cyan -NoNewline
            cmd /c pause
            $varXMLMediaPlayer = Get-Filename

            if (!$varXMLMediaPlayer) {
                write-host "   ERROR: No file selected."
                $varMediaDeclined=$true
            } else {
                #write this information to the database
                $varDatabaseApp = $varDatabase.CreateNode("element","node",$null)
                $varDatabaseApp.SetAttribute("name","media")
                $varDatabaseApp.InnerText = $varXMLMediaPlayer
                $varDatabaseRoot.AppendChild($varDatabaseApp) | out-null
                write-host " + Setting saved!" -ForegroundColor Green
            }
        }
    }

    if ($varMediaDeclined) {
        write-host `r
        write-host " - Setting marked as NO: Streamlink will use the default media player (VLC)."

        #make sure VLC is actually installed
        $varVLCFailureCount = 0
        try {$varVLCInstallStatus=((Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\VLC media player" -Name Publisher -ErrorAction Stop).Publisher)}
        catch [System.Exception] {
            $varVLCFailureCount++
        }
        try {$varVLCInstallStatus=((Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\VLC media player" -Name Publisher -ErrorAction Stop).Publisher)}
        catch [System.Exception] {
            $varVLCFailureCount++
        }

        if ($varVLCFailureCount -ge 2) {
            write-host " - ERROR: VLC Media Player is not installed on this device." -ForegroundColor Red
            $choiceInput = Read-Host "   Download and install it now? (Y/N)"
            switch -regex ($choiceInput) {
                '^(y|Y)$' {
                    write-host " - Downloading/Installing VLC..."
                    (New-Object System.Net.WebClient).DownloadFile("http://download.videolan.org/pub/videolan/vlc/3.0.0/win32/vlc-3.0.0-win32.exe", "$varScriptDir\videolan-install.exe")
                    Start-Process videolan-install.exe -Wait
                    write-host " - VLC installed."
                    Remove-Item videolan-install.exe
                }

                default {
                    write-host " - No media player is configured for watching Dopestation streams."
                    write-host "   Script will not be usable until this is resolved."
                    write-host "   Press any key to quit."
                    cmd /c pause
                    exit
                }
            }
        }
    }

    # STREAMER BLACKLIST

    write-host `r

    $Host.UI.RawUI.FlushInputBuffer()
    $choiceInput = Read-Host "3: Are there any streamers whose streams you would rather miss? (Y/N)"
    switch ($choiceInput) {
        default {
            write-host " - Setting marked as NO."
        }

        y {
            write-host " - Please produce a list of streamers to blacklist, separated by commas." -ForegroundColor Cyan
            write-host "   For example:" -NoNewline
            write-host " JBMX,SeamusOMallon,Fig_Wolf" -ForegroundColor Green
            $varXMLStreamerBlacklist = Read-Host " - Input"

            if (!$varXMLStreamerBlacklist) {
                write-host " - ERROR: No streamers presented."
            } else {
                #write this information to the database
                $varDatabaseApp = $varDatabase.CreateNode("element","node",$null)
                $varDatabaseApp.SetAttribute("name","blacklist")
                $varDatabaseApp.InnerText = $varXMLStreamerBlacklist
                $varDatabaseRoot.AppendChild($varDatabaseApp) | out-null
                write-host " + Setting saved!" -ForegroundColor Green
            }
        }
    }

    # DESKTOP SHORTCUT
    write-host `r
    $Host.UI.RawUI.FlushInputBuffer()
    $choiceInput = Read-Host "4: Place a shortcut to this script on your desktop? (Y/N)"
    switch -regex ($choiceInput) {
        '^(y|Y)$' {
            $WshShell = New-Object -comObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut("$Home\Desktop\Dopestation.lnk")
            $Shortcut.TargetPath = """C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"""
            $argA = """-file"""
            $argB = """`"$varScriptDir\$varScriptName`""""
            $Shortcut.Arguments = $argA + " " + $argB
            $Shortcut.Save()
            write-host " + Shortcut produced!" -ForegroundColor Green
        }

        default {
            write-host "   Righto then" -ForegroundColor Cyan
        }
    }

    # STREAMLINK CHECK

    # check to see if streamlink is installed
    $varStreamlinkCheck=streamlink --version
    if (!$varStreamlinkCheck) {
        write-host `r
        write-host "5: Check to ensure Streamlink is installed on this system"
        write-host " - ERROR: Streamlink was not found on this system."
        $Host.UI.RawUI.FlushInputBuffer()
        $choiceInput = Read-Host "   Download and install it now? (Y/N)"
        switch -regex ($choiceInput) {
            '^(y|Y)$' {
                write-host " - Downloading/Installing Streamlink (give it a moment)..."
                $varStreamlinkLatest = Invoke-WebRequest https://github.com/streamlink/streamlink/releases/latest -Headers @{"Accept"="application/json"}
                $varStreamlinkLatest= ($varStreamlinkLatest.content | ConvertFrom-Json | select tag_name).tag_name
                (New-Object System.Net.WebClient).DownloadFile("https://github.com/streamlink/streamlink/releases/download/$varStreamlinkLatest/streamlink-$varStreamlinkLatest.exe", "$varScriptDir\streamlink.exe")
                Start-Process streamlink.exe -Wait
                write-host " - Streamlink installed."
                remove-item streamlink.exe
            }

            default {
                write-host " - Without Streamlink, this script is useless."
                write-host "   Press any key to quit."
                cmd /c pause
                exit
            }
        }
    }

    #drink plum juice by force
    $varDatabase.AppendChild($varDatabaseRoot) | out-null
    $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    $varXMLOutput = New-Object System.IO.StreamWriter("$varScriptDir\settings.xml", $false, $utf8WithoutBom)
    $varDatabase.Save($varXMLOutput)

    write-host `r
    write-host "Settings file was saved locally as " -NoNewline -ForegroundColor Cyan
    write-host "Settings.xml." -ForegroundColor Green
    write-host `r
    write-host "Script will now exit. " -NoNewline
    cmd /c pause
    exit
}

Function IRC {
    clearVariables
    write-host '- Selected: ' -NoNewline -ForegroundColor Gray
    write-host 'IRC' -ForegroundColor White

    try {Get-Process $varXMLIRCClientExecutable -ErrorAction Stop | out-null}
    catch [System.Exception] {
    #do nothing
    }

    if ($?) {
        write-host "* IRC client already running. Ignoring..." -ForegroundColor Red
    } else {
        Start-Process "$varXMLIRCClient"
    }
    dl-NL
}

Function dl-NL {
    while ($true) {
        clearVariables
        write-host '- Selected: ' -NoNewline -ForegroundColor Gray
        write-host 'Dopelives NL' -ForegroundColor White
        liveCheck
        streamerCheck
        streamlink -l info rtmp://nl.vacker.tv/live/live best $varXMLMediaPlayer
        write-host `r
    }
}

Function dl-DE {
    while ($true) {
        clearVariables
        write-host '- Selected: ' -NoNewline -ForegroundColor Gray
        write-host 'Dopelives DE' -ForegroundColor White
        liveCheck
        streamerCheck
        streamlink -l info rtmp://de.vacker.tv/live/live best $varXMLMediaPlayer
        write-host `r
    }
}

Function dl-LQ {
    while ($true) {
        clearVariables
        write-host '- Selected: ' -NoNewline -ForegroundColor Gray
        write-host 'Dopelives NL (Low Quality)' -ForegroundColor White
        liveCheck
        streamerCheck
        streamlink -l info rtmp://nl.vacker.tv/live_low/live_low worst $varXMLMediaPlayer
        write-host `r
    }
}

Function twitch {
    write-host '- ' -NoNewline -ForegroundColor Gray
    write-host 'Twitch Configuration' -ForegroundColor White
    write-host `r
    write-host 'Channel Name' -NoNewline -ForegroundColor White
    $varTwitchChannel = Read-Host "?"
    while ($true) {
        clear-host
        write-host " $varBuildString" -ForegroundColor red
        write-host "════════════════════════════════════════════"
        write-host '- Selected: ' -NoNewline -ForegroundColor Gray
        write-host "Twitch Channel ($varTwitchChannel)" -ForegroundColor White
        write-host `r
        streamlink twitch.tv/$varTwitchChannel best $varXMLMediaPlayer
        write-host `r
        write-host "No active stream found; retrying in 10 seconds..."
        start-sleep 10
    }
}

function youTube {
    while ($true) {
        clear-host
        write-host " $varBuildString" -ForegroundColor red
        write-host "════════════════════════════════════════════"
        write-host '- Selected: ' -NoNewline -ForegroundColor Gray
        write-host "Dopelives`' YouTube Channel" -ForegroundColor White
        write-host `r
        streamlink https://www.youtube.com/user/Dopelives best $varXMLMediaPlayer
        write-host `r
        write-host "No active stream found; retrying in 10 seconds..."
        start-sleep 10
    }
}

Function liveCheck {
    try {$json=(invoke-webrequest http://vacker.tv/json.php | convertfrom-json)} catch {$_.Exception.Response.StatusCode.Value__}
    if (!($json.live.live)) {write-host `r}
    while (!($json.live.live)) {
        $liveChecks++
        $wasOffline=$true
        write-host "`rVackerTV is not live. Last update: $(get-date); Total checks: $liveChecks" -NoNewline
        start-sleep -seconds 10
        try {$json=(invoke-webrequest http://vacker.tv/json.php | convertfrom-json)} catch {$_.Exception.Response.StatusCode.Value__}
    }
    if ($wasOffline) {write-host "`n";[System.Media.SystemSounds]::Hand.Play()} else {write-host "`r"}
}

Function streamerCheck {
    try {$streamer=(invoke-webrequest http://goalitium.kapsi.fi/dopelives_status3)} catch {$_.Exception.Response.StatusCode.Value__}

    $StreamerIdentity = ($streamer.content -split '\n')[0]
    foreach ($iteration in $varXMLStreamerBlacklist.split(',')) {
        while ($streamerIdentity -ilike "*$iteration*") {
            if ([console]::KeyAvailable) {
                $readKey=[Console]::ReadKey()
                switch -Exact ($readKey.key){
                    'q' {$StreamerIdentity = $null
                        write-host "`rStreamer filter overridden.                                                            " -ForegroundColor Cyan
                    }
                }
            } else {
                $liveChecks++
                write-host "`rStreamer rejected (Press Q to override). Last update: $(get-date)" -ForegroundColor Red -NoNewline
                start-sleep -seconds 10
                $wasBlocked=$true
                try {$streamer=(invoke-webrequest http://goalitium.kapsi.fi/dopelives_status3)} catch {$_.Exception.Response.StatusCode.Value__}
                $StreamerIdentity = ($streamer.content -split '\n')[0] 
            }
        }
    }

    if ($wasBlocked) {
        $wasBlocked=$null
        $wasOffline=$null
        $liveChecks=0
        liveCheck
    }

    $HOST.UI.RawUI.Flushinputbuffer()

    $StreamerContent = ($streamer.content -split '\n')[0]
    while ($StreamerContent -ilike '*Game:*') {
        if ($justChecking) {
            write-host "Nobody is currently streaming." -ForegroundColor Red
            return
        } else {
            if ([console]::KeyAvailable) {
                $readKey=[Console]::ReadKey()
                switch -Exact ($readKey.key){
                    'q' {
                    $StreamerContent = $null
                    write-host "`rNo Streamer or Content metadata could be found.                                                       " -NoNewline -ForegroundColor Cyan
                    }
                }
            } else {
                $liveChecks++
                if ($liveChecks -eq 1) {write-host "Waiting for topic data (Press Q to skip)." -ForegroundColor Red -NoNewline}
                start-sleep -seconds 5
                $wasOffline=$true
                try {$streamer=(invoke-webrequest http://goalitium.kapsi.fi/dopelives_status3)} catch {$_.Exception.Response.StatusCode.Value__}
                $StreamerContent = ($streamer.content -split '\n')[0]
            }
        }
    }

    if ($wasOffline) {write-host "`r";$wasOffline=$false;liveCheck}

    if ($StreamerContent.length -eq 0) {
        #do nothing
    } else {
        write-host "Streamer is " -NoNewline
        write-host ($streamer.content -split '\n')[0] -ForegroundColor White -NoNewline
        if (($streamer.content -split '\n')[1] -match "Game: ") {
            write-host ", Game is " -NoNewline
        } else {
            write-host ", Movie is " -NoNewline
        }
        write-host (($streamer.content -split '\n')[1] -replace "^(.*?)\: ",'') -ForegroundColor White
    }
}

Function clearVariables {
    $HOST.UI.RawUI.FlushInputBuffer()
    $json=$null
    $liveChecks=0
    $wasOffline=$false
    $streamer=$null
    $wasBlocked=$null
    $StreamerContent=$null
    $StreamerIdentity=$null
    $justChecking=$null
}

Function begin {
    write-host 'Input' -NoNewline -ForegroundColor White
    $Host.UI.RawUI.FlushInputBuffer()
    $choiceInput = Read-Host "?"
    write-host `r

    switch -regex ($choiceInput) {
        '$^' {
            IRC
        }

        '^(q|Q)$' { 
            dl-NL
        }

        '^(a|A)$' { 
            dl-DE
        }

        '^(z|Z)$' {
            youTube
        }

        '^(x|X)$' { 
            twitch
        }

        '^(w|W)$' {
            dl-LQ
        }

        '^(s|S)$' {
            $justChecking=$true
            streamerCheck
            write-host "`r"
            cmd /c pause
            clear-host
            clearvariables
        }

        '^seagull$' {
            write-host "dopestation: a powershell-based dopelives streaming utility" -ForegroundColor Yellow
            write-host "created and maintained by seagull 2016-2018."
            write-host "follow me on twttr: @seagull | www.seagull.io"
            write-host `r
            cmd /c pause
        }

        default {
            continue
        }
    }
}

#gather .XML information
if (test-path "$varScriptDir\settings.xml") {
    [xml]$varXMLContent = get-content "$varScriptDir\settings.xml"
    $varXMLVersion = $varXMLContent.seagull.node | where-object {$_.Name -match "version" } | select-object "#text" | foreach {$_."#text"}
    if (!$varXMLVersion) {
        write-host "XML is corrupted. Script will now re-generate it."
        cmd /c pause
        Remove-Item "$varScriptDir\settings.xml" -Force
        clear-host
        makeSettings
    }
    $varXMLIRCClient = $varXMLContent.seagull.node | where-object {$_.Name -match "IRC" } | select-object "#text" | foreach {$_."#text"}
    $varXMLIRCClientExecutable = ($varXMLIRCClient.split('\')[-1] -replace ".{4}$")
    $varXMLMediaPlayer = $varXMLContent.seagull.node | where-object {$_.Name -match "media" } | select-object "#text" | foreach {$_."#text"}
    if ($varXMLMediaPlayer) {
        $varXMLMediaPlayer = "-p" + $varXMLMediaPlayer
    }
    $varXMLStreamerBlacklist = $varXMLContent.seagull.node | where-object {$_.Name -match "blacklist" } | select-object "#text" | foreach {$_."#text"}
} else {
    makeSettings
}

while ($true) {
    clear-host
    # beginning preamble
    write-host " $varBuildString" -ForegroundColor red
    write-host "════════════════════════════════════════════╦══───---"
    write-host ' Press: ' -NoNewline
    if ($varXMLIRCClient) {
        write-host '[' -ForegroundColor White -NoNewline; write-host 'ENT' -ForegroundColor Cyan -NoNewline; write-host  '] DopeNL ' -ForegroundColor White -NoNewline;
        write-host 'and ' -NoNewline; write-host 'Launch Chat Client' -ForegroundColor White -NoNewline

    } else {
        write-host '                                   ' -NoNewline
    }
    write-host ' ║ ' -NoNewline; write-host "Use [CTRL] + [C] to exit." -ForegroundColor Cyan
    write-host '          [' -ForegroundColor white -NoNewline; write-host 'Q' -ForegroundColor Cyan -NoNewline; write-host '] DopeNL  ·  [' -ForegroundColor white -NoNewline
    write-host 'W' -NoNewline -ForegroundColor Cyan; Write-Host '] Lower Bitrate' -ForegroundColor White -NoNewline; write-host "  ║"
    write-host '          [' -ForegroundColor white -NoNewline; write-host 'A' -ForegroundColor Cyan -NoNewline; write-host '] DopeDE  ·  [' -ForegroundColor White -NoNewline
    write-host 'S' -NoNewline -ForegroundColor Cyan ; write-host '] Check Stream' -ForegroundColor White -NoNewline; write-host '   ║ Donate to Dopelives:'
    write-host '          [' -ForegroundColor white -NoNewline ; write-host 'Z' -NoNewline -ForegroundColor Cyan ; write-host '] YouTube ·  [' -ForegroundColor White -NoNewline
    write-host 'X' -ForegroundColor Cyan -NoNewline; write-host '] Twitch (Any)' -ForegroundColor White -NoNewline; write-host "   ║ " -NoNewline; write-host "https://patreon.com/vackersimon" -ForegroundColor Green
    write-host '════════════════════════════════════════════╩══───---'
    begin
}