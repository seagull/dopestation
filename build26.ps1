#requires -version 3

<#
DOPESTREAMER v3.1:

- remove reliance on streamlink if the user is using VLC
- add support for 64-bit builds of VLC
- always download the latest version of vlc
- add US, UK and SG servers; remove DE and replace with Lithuania/LT
- 'default' setting for servers (regular/low quality) and second option which lets user put in their preference
- detect any clashing version string and advise user that it will need to be removed
- add option to clear settings.xml and re-configure
#>

# SEAGULL
# ================================================
$varBuildString = "Dopestation v3.1.26: May 2019 by seagull"
$varScriptDir = split-path -parent $MyInvocation.MyCommand.Definition
$varScriptName = $MyInvocation.MyCommand.Name
$ErrorActionPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Cosmetics
if ($psversiontable.PSversion.build -le 17134) {
    #only manipulate the window size in pre-1809 builds since MS broke powershell, nice work lads
    [console]::WindowWidth=95
    [console]::BufferWidth=[console]::WindowWidth
    [console]::WindowHeight=25
}

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

    # SERVER LOCATION
    pickServer
    $varDatabaseApp = $varDatabase.CreateNode("element","node",$null)
    $varDatabaseApp.SetAttribute("name","server")
    $varDatabaseApp.InnerText = $script:varXMLDefaultServer
    $varDatabaseRoot.AppendChild($varDatabaseApp) | out-null

    write-host `r

    # IRC CLIENT

    $Host.UI.RawUI.FlushInputBuffer()
    $choiceInput = Read-Host ">> Do you use either Discord or an IRC client? (Y/[N])"
    switch -regex ($choiceInput) {
        default {
            write-host " - Setting marked as NO."
        }

        'Y|y' {
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

    write-host `r

    # MEDIA PLAYER

    #check to see if VLC is installed
    $varVLCFailureCount = 0
    try {$varXMLMediaPlayer=((Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\VLC media player" -Name DisplayIcon -ErrorAction Stop).DisplayIcon)}
    catch [System.Exception] {
        $varVLCFailureCount++
    }
    try {$varXMLMediaPlayer=((Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\VLC media player" -Name DisplayIcon -ErrorAction Stop).DisplayIcon)}
    catch [System.Exception] {
        $varVLCFailureCount++
    }

    if ($varVLCFailureCount -ge 2) {
        write-host ">> VLC Media Player was not found to accept streams. You can download it or elect a different media player."
        write-host "   Note: VLC accepts streams natively; other players will require the Streamlink application." -ForegroundColor Cyan
        $choiceInput = Read-Host "   Download and install it now? Select NO to use Streamlink with your own media player. (Y/[N])"
        $Host.UI.RawUI.FlushInputBuffer()
        switch -regex ($choiceInput) {
            '^(y|Y)$' {
                write-host " - Downloading/Installing VLC..."
                if ([intptr]::size -eq 8) {
                    $varArch=64
                } else {
                    $varArch=32
                }
                $varVLC = invoke-webrequest "https://www.mirrorservice.org/sites/videolan.org/vlc/last/win$varArch"
                [string]$varVLC = (($varVLC.links | Where-Object {$_.href -match '.exe$'}).href)
                (New-Object System.Net.WebClient).DownloadFile("https://www.mirrorservice.org/sites/videolan.org/vlc/last/win$varArch/$varVLC", "$varScriptDir\videolan-install.exe")
                Start-Process videolan-install.exe -Wait
                $varXMLMediaPlayer=(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\VLC media player" -Name DisplayIcon -ErrorAction Stop).DisplayIcon
                write-host " - VLC installed."
                Remove-Item videolan-install.exe
            }

            default {
                #do nothing
            }
        }
    } else {
        write-host ">> VLC Media Player was detected on this system."
        write-host "   Provided it's recent enough, you can use VLC without needing the Streamlink application." -ForegroundColor Cyan
        $choiceInput = Read-Host "   Use VLC for Dopestation streams? Select NO to elect a different media player. (Y/[N])"
        $Host.UI.RawUI.FlushInputBuffer()
        switch -regex ($choiceInput) {
            '^(y|Y)$' {
                #do nothing, we've already set the XMLmediaplayer variable to the right data
            }

            default {
                #clear the VLC records from the mediaplayer variable and re-set them in the next section
                clear-variable varXMLMediaPlayer
            }
        }
    }

    if (!$varXMLMediaPlayer) {

        #elect a media player
        while (!$varXMLMediaPlayer) {
            write-host " - Please locate the executable for your preferred player. " -ForegroundColor Cyan -NoNewline
            cmd /c pause
            $varXMLMediaPlayer = Get-Filename
        }

        #check to ensure streamlink is installed
        try {
            $varStreamlinkCheck=streamlink --version
        } catch [System.Management.Automation.CommandNotFoundException] {
            #do nothing
        }

        if (!$varStreamlinkCheck) {
            write-host `r
            $Host.UI.RawUI.FlushInputBuffer()
            $choiceInput = Read-Host " - Streamlink wasn't found. Press ENTER to download and install it."
            cmd /c pause 2>&1>$null
            write-host " - Downloading/Installing Streamlink (give it a moment)..."
            $varStreamlinkLatest = Invoke-WebRequest https://github.com/streamlink/streamlink/releases/latest -Headers @{"Accept"="application/json"}
            $varStreamlinkLatest= ($varStreamlinkLatest.content | ConvertFrom-Json | select tag_name).tag_name
            (New-Object System.Net.WebClient).DownloadFile("https://github.com/streamlink/streamlink/releases/download/$varStreamlinkLatest/streamlink-$varStreamlinkLatest.exe", "$varScriptDir\streamlink.exe")
            Start-Process streamlink.exe -Wait
            write-host " - Streamlink installed."
            remove-item streamlink.exe
        }
    }

    # WRITE MEDIA PLAYER INFORMATION TO THE XML NOW WE 100% HAVE IT

    $varDatabaseApp = $varDatabase.CreateNode("element","node",$null)
    $varDatabaseApp.SetAttribute("name","media")
    $varDatabaseApp.InnerText = $varXMLMediaPlayer
    $varDatabaseRoot.AppendChild($varDatabaseApp) | out-null
    write-host " + Media Player information saved!" -ForegroundColor Green

    # STREAMER BLACKLIST

    write-host `r

    $Host.UI.RawUI.FlushInputBuffer()
    $choiceInput = Read-Host ">> Are there any streamers whose streams you would rather miss? (Y/[N])"
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

    write-host `r

    # DESKTOP SHORTCUT

    $Host.UI.RawUI.FlushInputBuffer()
    $choiceInput = Read-Host ">> Place a shortcut to this script on your desktop? (Y/[N])"
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

    #save the xml
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

FUnCtion pickServer {
    write-host "[1] Europe/" -NoNewline; write-host "United Kingdom" -ForegroundColor Blue -NoNewline; write-host "  (UK)" -ForegroundColor Green
    write-host "[2] Europe/" -NoNewline; write-host "The Netherlands" -ForegroundColor Blue -NoNewline; write-host " (NL)" -ForegroundColor Green
    write-host "[3] Europe/" -NoNewline; write-host "Lithuania" -ForegroundColor Blue -NoNewline; write-host "       (LT)" -ForegroundColor Green
    write-host "[4] America/" -NoNewline; write-host "United States" -ForegroundColor Blue -NoNewline; write-host "  (US)" -ForegroundColor Green
    write-host "[5] Asia/" -NoNewline; write-host "Singapore" -ForegroundColor Blue -NoNewline; write-host "         (SG)" -ForegroundColor Green
    write-host `r
    $Host.UI.RawUI.FlushInputBuffer()
    $choiceInput = Read-Host "Which server is closest to your location?"
    switch -regex ($choiceInput) {

        '^1$' { 
            $script:varXMLDefaultServer="UK"
        }

        '^2$' { 
            $script:varXMLDefaultServer="NL"
        }

        '^3$' {
            $script:varXMLDefaultServer="LT"
        }

        '^4$' {
            $script:varXMLDefaultServer="US"
        }

        '^5$' {
            $script:varXMLDefaultServer="SG"
        }

        default {
            exit
        }
    }
}

Function IRC {
    clearVariables
    write-host '- Selected: ' -NoNewline -ForegroundColor Gray
    write-host 'Chat' -ForegroundColor White

    try {Get-Process $varXMLIRCClientExecutable -ErrorAction Stop | out-null}
    catch [System.Exception] {
    #do nothing
    }

    if ($?) {
        write-host "* IRC client already running. Ignoring..." -ForegroundColor Red
    } else {
        Start-Process "$varXMLIRCClient"
    }
    vacker $script:varXMLDefaultServer Best
}

Function vacker ($script:varXMLDefaultServer, $varQuality, $varService) {
    while ($true) {
        clearVariables
        write-host '- Selected: ' -NoNewline -ForegroundColor Gray
        write-host "VackerTV $script:varXMLDefaultServer, $varQuality quality" -ForegroundColor White
        liveCheck
        streamerCheck
        streamlink -l info "rtmp://$script:varXMLDefaultServer.vacker.tv/$varService/$varService" $varQuality $varXMLMediaPlayer
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
            vacker $script:varXMLDefaultServer Best live
        }

        '^(a|A)$' { 
            pickServer
            vacker $script:varXMLDefaultServer Best live
        }

        '^(z|Z)$' {
            youTube
        }

        '^(x|X)$' { 
            twitch
        }

        '^(w|W)$' {
            vacker $script:varXMLDefaultServer Worst live_low
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
            write-host "created and maintained by seagull 2016-2019."
            write-host "follow me on twttr: @seagull | www.seagull.io"
            write-host `r
            cmd /c pause
        }

        default {
            continue
        }
    }
}

#######################################################################
### SCRIPT BEGINS HERE:

#gather .XML information
if (test-path "$varScriptDir\settings.xml") {
    [xml]$varXMLContent = get-content "$varScriptDir\settings.xml"
    $varXMLVersion = $varXMLContent.seagull.node | where-object {$_.Name -match "version" } | select-object "#text" | foreach {$_."#text"}
    if (!$varXMLVersion) {
        write-host "XML is corrupted. Press any key to initialise."
        cmd /c pause 2>&1>$null
        Remove-Item "$varScriptDir\settings.xml" -Force
        clear-host
        makeSettings
    }

    #check version of settings.xml
    if ($varXMLVersion -notmatch $varBuildString) {
        write-host "ALERT: Settings file for Dopestation is not compatible with this release." -ForegroundColor Red
        write-host "Press any key to initialise."
        cmd /c pause 2>&1>$null
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
    $script:varXMLDefaultServer = $varXMLContent.seagull.node | where-object {$_.Name -match "server" } | select-object "#text" | foreach {$_."#text"}
} else {
    makeSettings
}

#check to ensure streamlink is installed
try {
    $varStreamlinkCheck=streamlink --version
} catch [System.Management.Automation.CommandNotFoundException] {
    #do nothing
}

while ($true) {
    clear-host
    # beginning preamble
    write-host `r
    write-host " $varBuildString" -ForegroundColor red
    write-host "══════════════════════════════════════════════╦══───---"
    
    #line 1: conditional depending on chat preference
    if ($varXMLIRCClient) {
        write-host 'Type: ' -NoNewline
        write-host '[' -ForegroundColor White -NoNewline; write-host 'ENT' -ForegroundColor Cyan -NoNewline; write-host  "] Stream " -ForegroundColor White -NoNewline; write-host "($script:varXMLDefaultServer)" -ForegroundColor Green -NoNewline
        write-host ' and ' -NoNewline; write-host 'open chat client ' -ForegroundColor White -NoNewline; write-host ' ║ '
    }

    #line 2
    write-host '        [' -ForegroundColor white -NoNewline; write-host 'Q' -ForegroundColor Cyan -NoNewline; write-host "] Stream " -NoNewline -ForegroundColor White; write-host "($script:varXMLDefaultServer)" -ForegroundColor Green -NoNewline
    write-host "   · [" -NoNewline -ForegroundColor White; write-host "W" -ForegroundColor Cyan -nonewline; write-host "] In LoRes mode" -ForegroundColor White -NoNewline
    write-host " ║ " -NoNewline; write-host "Use [CTRL] + [C] to exit." -ForegroundColor Cyan

    #line 3
    write-host '        [' -ForegroundColor white -NoNewline; write-host 'A' -ForegroundColor Cyan -NoNewline; write-host '] Stream ' -ForegroundColor White -NoNewline; write-host '(Menu)' -ForegroundColor Green -NoNewline; write-host ' · [' -ForegroundColor White -NoNewline
    write-host 'S' -NoNewline -ForegroundColor Cyan ; write-host '] Check stream' -ForegroundColor White -NoNewline; write-host '  ║ Donate: ' -NoNewline; write-host "https://patreon.com/vackersimon" -ForegroundColor Green

    #line 4: conditional depending on streamlink check
    if ($varStreamlinkCheck) {
        write-host '        [' -ForegroundColor white -NoNewline ; write-host 'Z' -NoNewline -ForegroundColor Cyan ; write-host "] Dopelives`' YT · [" -ForegroundColor White -NoNewline
        write-host 'X' -ForegroundColor Cyan -NoNewline; write-host '] Twitch (Any)' -ForegroundColor White -NoNewline; write-host "  ║ "
    } else {
        write-host '         [' -ForegroundColor DarkGray -NoNewline ; write-host 'Z' -NoNewline -ForegroundColor DarkGray ; write-host "] Dopelives`' YT · [" -ForegroundColor DarkGray -NoNewline
        write-host 'X' -ForegroundColor DarkGray -NoNewline; write-host '] Twitch (Any)' -ForegroundColor DarkGray -NoNewline; write-host "  ║ " -NoNewline; write-host "Disabled: Install Streamlink" -ForegroundColor Red
    }
    write-host '══════════════════════════════════════════════╩══───---'
    begin
}