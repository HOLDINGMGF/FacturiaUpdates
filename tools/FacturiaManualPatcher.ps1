Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

$DefaultPatchUrl = "https://raw.githubusercontent.com/HOLDINGMGF/FacturiaUpdates/main/update-test/facturia-patch-0.6.74-test.zip"
$DefaultVersion = "0.6.74-test"

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Add-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $script:LogBox.AppendText("[$timestamp] $Message`r`n")
    $script:LogBox.SelectionStart = $script:LogBox.Text.Length
    $script:LogBox.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Get-PossibleInstallFolders {
    $folders = @(
        (Join-Path $env:ProgramFiles "Facturia"),
        (Join-Path ${env:ProgramFiles(x86)} "Facturia"),
        (Join-Path $env:LOCALAPPDATA "Programs\Facturia"),
        (Join-Path $env:LOCALAPPDATA "Facturia"),
        (Join-Path $env:APPDATA "Facturia")
    ) | Where-Object { $_ -and $_.Trim().Length -gt 0 } | Select-Object -Unique

    return $folders
}

function Find-FacturiaInstallFolder {
    foreach ($folder in Get-PossibleInstallFolders) {
        if (Test-Path (Join-Path $folder "Facturia.exe")) {
            return $folder
        }
    }
    return ""
}

function Get-PatchRoot {
    param([string]$ExtractFolder)

    if (Test-Path (Join-Path $ExtractFolder "Facturia.exe")) {
        return $ExtractFolder
    }

    $candidate = Get-ChildItem -LiteralPath $ExtractFolder -Recurse -Filter "Facturia.exe" -File |
        Select-Object -First 1
    if ($candidate) {
        return $candidate.Directory.FullName
    }

    throw "Le patch ne contient pas Facturia.exe. Vérifiez que le ZIP sélectionné est bien un patch FACTURIA."
}

function Copy-PatchContent {
    param(
        [string]$Source,
        [string]$Destination
    )

    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        $target = Join-Path $Destination $_.Name
        Copy-Item -LiteralPath $_.FullName -Destination $target -Recurse -Force
    }
}

function Backup-InstallFolder {
    param([string]$InstallFolder)

    $backupRoot = Join-Path $env:LOCALAPPDATA "FacturiaManualPatcher\Backups"
    New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
    $backupFolder = Join-Path $backupRoot ("Facturia-install-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    New-Item -ItemType Directory -Force -Path $backupFolder | Out-Null

    Add-Log "Sauvegarde de l'installation vers : $backupFolder"
    Get-ChildItem -LiteralPath $InstallFolder -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $backupFolder $_.Name) -Recurse -Force
    }

    return $backupFolder
}

function Stop-FacturiaIfRunning {
    $processes = Get-Process -Name "Facturia" -ErrorAction SilentlyContinue
    if (-not $processes) {
        return
    }

    $result = [System.Windows.Forms.MessageBox]::Show(
        "Facturia est actuellement ouvert. Il doit être fermé pour appliquer le patch.`r`n`r`nVoulez-vous le fermer automatiquement ?",
        "Facturia en cours d'exécution",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )

    if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
        throw "Patch annulé : Facturia doit être fermé."
    }

    foreach ($process in $processes) {
        Add-Log "Fermeture de Facturia PID $($process.Id)..."
        Stop-Process -Id $process.Id -Force
    }
    Start-Sleep -Milliseconds 600
}

function Download-Patch {
    param(
        [string]$Url,
        [string]$Destination
    )

    Add-Log "Téléchargement du patch : $Url"
    $script:ProgressBar.Style = "Marquee"
    $client = New-Object System.Net.WebClient
    try {
        $client.DownloadFile($Url, $Destination)
    }
    finally {
        $client.Dispose()
        $script:ProgressBar.Style = "Continuous"
    }
    Add-Log "Patch téléchargé : $Destination"
}

function Apply-FacturiaPatch {
    param(
        [string]$PatchZip,
        [string]$InstallFolder,
        [bool]$BackupBeforePatch
    )

    if (-not (Test-Path $PatchZip)) {
        throw "Le fichier patch est introuvable."
    }
    if (-not (Test-Path $InstallFolder)) {
        throw "Le dossier d'installation est introuvable."
    }
    if (-not (Test-Path (Join-Path $InstallFolder "Facturia.exe"))) {
        throw "Le dossier sélectionné ne semble pas être une installation Facturia : Facturia.exe introuvable."
    }

    Stop-FacturiaIfRunning

    if ($InstallFolder -like "$env:ProgramFiles*" -and -not (Test-IsAdministrator)) {
        throw "Le dossier est dans Program Files. Relancez cet outil en administrateur puis réessayez."
    }

    if ($BackupBeforePatch) {
        Backup-InstallFolder -InstallFolder $InstallFolder | Out-Null
    }

    $tempRoot = Join-Path $env:TEMP ("FacturiaManualPatch-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

    try {
        Add-Log "Extraction du patch..."
        Expand-Archive -LiteralPath $PatchZip -DestinationPath $tempRoot -Force
        $patchRoot = Get-PatchRoot -ExtractFolder $tempRoot
        Add-Log "Copie des fichiers vers : $InstallFolder"
        Copy-PatchContent -Source $patchRoot -Destination $InstallFolder
        Add-Log "Patch appliqué avec succès."
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "FACTURIA - Outil de patch manuel"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(760, 560)
$form.MinimumSize = New-Object System.Drawing.Size(720, 520)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.BackColor = [System.Drawing.Color]::FromArgb(244, 248, 252)

$title = New-Object System.Windows.Forms.Label
$title.Text = "FACTURIA - Patch manuel"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(0, 68, 116)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(22, 18)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Applique un patch FACTURIA même si le logiciel ne démarre plus. Les bases et sociétés ne sont pas supprimées."
$subtitle.AutoSize = $true
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(85, 101, 120)
$subtitle.Location = New-Object System.Drawing.Point(25, 58)
$form.Controls.Add($subtitle)

$urlLabel = New-Object System.Windows.Forms.Label
$urlLabel.Text = "URL du patch"
$urlLabel.Location = New-Object System.Drawing.Point(25, 96)
$urlLabel.AutoSize = $true
$form.Controls.Add($urlLabel)

$urlBox = New-Object System.Windows.Forms.TextBox
$urlBox.Text = $DefaultPatchUrl
$urlBox.Location = New-Object System.Drawing.Point(25, 118)
$urlBox.Size = New-Object System.Drawing.Size(575, 24)
$form.Controls.Add($urlBox)

$downloadButton = New-Object System.Windows.Forms.Button
$downloadButton.Text = "Télécharger"
$downloadButton.Location = New-Object System.Drawing.Point(615, 116)
$downloadButton.Size = New-Object System.Drawing.Size(110, 28)
$form.Controls.Add($downloadButton)

$zipLabel = New-Object System.Windows.Forms.Label
$zipLabel.Text = "Patch ZIP local"
$zipLabel.Location = New-Object System.Drawing.Point(25, 158)
$zipLabel.AutoSize = $true
$form.Controls.Add($zipLabel)

$zipBox = New-Object System.Windows.Forms.TextBox
$zipBox.Location = New-Object System.Drawing.Point(25, 180)
$zipBox.Size = New-Object System.Drawing.Size(575, 24)
$form.Controls.Add($zipBox)

$browseZipButton = New-Object System.Windows.Forms.Button
$browseZipButton.Text = "Parcourir"
$browseZipButton.Location = New-Object System.Drawing.Point(615, 178)
$browseZipButton.Size = New-Object System.Drawing.Size(110, 28)
$form.Controls.Add($browseZipButton)

$installLabel = New-Object System.Windows.Forms.Label
$installLabel.Text = "Dossier d'installation Facturia"
$installLabel.Location = New-Object System.Drawing.Point(25, 220)
$installLabel.AutoSize = $true
$form.Controls.Add($installLabel)

$installBox = New-Object System.Windows.Forms.TextBox
$installBox.Text = Find-FacturiaInstallFolder
$installBox.Location = New-Object System.Drawing.Point(25, 242)
$installBox.Size = New-Object System.Drawing.Size(575, 24)
$form.Controls.Add($installBox)

$browseInstallButton = New-Object System.Windows.Forms.Button
$browseInstallButton.Text = "Parcourir"
$browseInstallButton.Location = New-Object System.Drawing.Point(615, 240)
$browseInstallButton.Size = New-Object System.Drawing.Size(110, 28)
$form.Controls.Add($browseInstallButton)

$backupCheck = New-Object System.Windows.Forms.CheckBox
$backupCheck.Text = "Créer une sauvegarde de l'installation avant de remplacer les fichiers"
$backupCheck.Checked = $true
$backupCheck.AutoSize = $true
$backupCheck.Location = New-Object System.Drawing.Point(25, 282)
$form.Controls.Add($backupCheck)

$adminButton = New-Object System.Windows.Forms.Button
$adminButton.Text = "Relancer en administrateur"
$adminButton.Location = New-Object System.Drawing.Point(25, 315)
$adminButton.Size = New-Object System.Drawing.Size(180, 32)
$form.Controls.Add($adminButton)

$applyButton = New-Object System.Windows.Forms.Button
$applyButton.Text = "Appliquer le patch"
$applyButton.BackColor = [System.Drawing.Color]::FromArgb(35, 188, 105)
$applyButton.ForeColor = [System.Drawing.Color]::White
$applyButton.FlatStyle = "Flat"
$applyButton.Location = New-Object System.Drawing.Point(545, 315)
$applyButton.Size = New-Object System.Drawing.Size(180, 36)
$form.Controls.Add($applyButton)

$script:ProgressBar = New-Object System.Windows.Forms.ProgressBar
$script:ProgressBar.Location = New-Object System.Drawing.Point(25, 365)
$script:ProgressBar.Size = New-Object System.Drawing.Size(700, 14)
$script:ProgressBar.Style = "Continuous"
$form.Controls.Add($script:ProgressBar)

$script:LogBox = New-Object System.Windows.Forms.TextBox
$script:LogBox.Location = New-Object System.Drawing.Point(25, 395)
$script:LogBox.Size = New-Object System.Drawing.Size(700, 105)
$script:LogBox.Multiline = $true
$script:LogBox.ReadOnly = $true
$script:LogBox.ScrollBars = "Vertical"
$script:LogBox.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($script:LogBox)

$browseZipButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "Patch FACTURIA (*.zip)|*.zip|Tous les fichiers (*.*)|*.*"
    $dialog.Title = "Choisir le patch FACTURIA"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $zipBox.Text = $dialog.FileName
    }
})

$browseInstallButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Choisir le dossier contenant Facturia.exe"
    if ($installBox.Text -and (Test-Path $installBox.Text)) {
        $dialog.SelectedPath = $installBox.Text
    }
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $installBox.Text = $dialog.SelectedPath
    }
})

$downloadButton.Add_Click({
    try {
        $downloadFolder = Join-Path $env:USERPROFILE "Downloads"
        if (-not (Test-Path $downloadFolder)) { $downloadFolder = $env:TEMP }
        $target = Join-Path $downloadFolder "facturia-patch-$DefaultVersion.zip"
        Download-Patch -Url $urlBox.Text.Trim() -Destination $target
        $zipBox.Text = $target
        [System.Windows.Forms.MessageBox]::Show("Patch téléchargé :`r`n$target", "Téléchargement terminé", "OK", "Information") | Out-Null
    }
    catch {
        Add-Log "ERREUR téléchargement : $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Erreur téléchargement", "OK", "Error") | Out-Null
    }
})

$adminButton.Add_Click({
    try {
        $scriptPath = $PSCommandPath
        if (-not $scriptPath) { throw "Chemin du script introuvable." }
        Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
        $form.Close()
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Impossible de relancer en administrateur", "OK", "Error") | Out-Null
    }
})

$applyButton.Add_Click({
    try {
        $applyButton.Enabled = $false
        $script:ProgressBar.Style = "Marquee"
        Add-Log "Préparation de l'application du patch..."
        Apply-FacturiaPatch -PatchZip $zipBox.Text.Trim() -InstallFolder $installBox.Text.Trim() -BackupBeforePatch $backupCheck.Checked
        $script:ProgressBar.Style = "Continuous"
        [System.Windows.Forms.MessageBox]::Show(
            "Patch appliqué avec succès.`r`n`r`nVous pouvez relancer Facturia.",
            "FACTURIA patché",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
    catch {
        $script:ProgressBar.Style = "Continuous"
        Add-Log "ERREUR : $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Erreur patch manuel", "OK", "Error") | Out-Null
    }
    finally {
        $applyButton.Enabled = $true
    }
})

Add-Log "Outil prêt. Version patch par défaut : $DefaultVersion"
if (-not $installBox.Text) {
    Add-Log "Dossier Facturia non détecté automatiquement. Sélectionnez le dossier contenant Facturia.exe."
}
elseif ($installBox.Text -like "$env:ProgramFiles*" -and -not (Test-IsAdministrator)) {
    Add-Log "Installation détectée dans Program Files : lancez en administrateur avant d'appliquer."
}
else {
    Add-Log "Installation détectée : $($installBox.Text)"
}

[void]$form.ShowDialog()
