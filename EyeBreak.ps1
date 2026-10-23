# 20-20-20 Eye Break - background app (Windows, nothing extra to install)
# Loop forever: 20:00 countdown in a tiny corner chip -> full-screen "Look away" for 20s -> resets to 20:00 -> repeat.

$WorkMin  = 20
$BreakSec = 20

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'Global\EyeBreak202020', [ref]$created)
if (-not $created) { exit }

$script:phase      = 'work'
$script:paused     = $false
$script:end        = [DateTime]::Now.AddMinutes($WorkMin)
$script:remain     = [TimeSpan]::Zero
$script:lastTick   = [DateTime]::Now
$script:drag       = $false
$script:userHidden = $false

function C($r, $g, $b) { [System.Drawing.Color]::FromArgb($r, $g, $b) }

# ---- Tray icon ----
$icon = New-Object System.Windows.Forms.NotifyIcon
$icon.Icon    = [System.Drawing.SystemIcons]::Information
$icon.Visible = $true

# ---- Tiny corner chip (draggable) ----
$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = 'None'
$form.TopMost         = $true
$form.ShowInTaskbar   = $false
$form.StartPosition   = 'Manual'
$form.Size            = New-Object System.Drawing.Size(46, 16)
$form.BackColor       = C 30 41 59
$form.Opacity         = 0.8
$wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.Location = New-Object System.Drawing.Point(($wa.Right - 54), ($wa.Bottom - 25))

$lbl = New-Object System.Windows.Forms.Label
$lbl.AutoSize  = $false
$lbl.Location  = New-Object System.Drawing.Point(0, 0)
$lbl.Size      = New-Object System.Drawing.Size(46, 16)
$lbl.TextAlign = 'MiddleCenter'
$lbl.Font      = New-Object System.Drawing.Font('Segoe UI', 7, [System.Drawing.FontStyle]::Bold)
$lbl.ForeColor = C 56 189 248
$form.Controls.Add($lbl)
# Windows enforces a minimum window size (~136x39), so clip the window to just the chip.
$form.Region = New-Object System.Drawing.Region((New-Object System.Drawing.Rectangle(0, 0, 46, 16)))

$lbl.Add_MouseDown({ if ($_.Button -eq 'Left') { $script:drag = $true; $script:dx = $_.X; $script:dy = $_.Y } })
$lbl.Add_MouseMove({
    if ($script:drag) {
        $p = [System.Windows.Forms.Cursor]::Position
        $form.Location = New-Object System.Drawing.Point(($p.X - $script:dx), ($p.Y - $script:dy))
    }
})
$lbl.Add_MouseUp({ $script:drag = $false })

# ---- Full-screen "look away" overlay (covers all monitors) ----
$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
$ps = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$ov = New-Object System.Windows.Forms.Form
$ov.FormBorderStyle = 'None'
$ov.StartPosition   = 'Manual'
$ov.Bounds          = $vs
$ov.TopMost         = $true
$ov.ShowInTaskbar   = $false
$ov.BackColor       = C 6 20 30
$ov.Opacity         = 0.96
$ov.KeyPreview      = $true

function AddOvLabel($text, $size, $color, $top, $height, $bold) {
    $l = New-Object System.Windows.Forms.Label
    $l.AutoSize  = $false
    $l.TextAlign = 'MiddleCenter'
    $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $l.Font      = New-Object System.Drawing.Font('Segoe UI', $size, $style)
    $l.ForeColor = $color
    $l.Text      = $text
    $l.Left      = $ps.X - $vs.X
    $l.Width     = $ps.Width
    $l.Top       = ($ps.Y - $vs.Y) + [int]($ps.Height * $top)
    $l.Height    = $height
    $ov.Controls.Add($l)
    return $l
}
$null = AddOvLabel 'LOOK AWAY' 64 (C 52 211 153) 0.18 130 $true
$null = AddOvLabel 'Rest your eyes. Look at something 20 feet (6 m) away.' 24 (C 203 213 225) 0.36 60 $false
$ovCount = AddOvLabel '20' 120 (C 255 255 255) 0.46 210 $true
$null = AddOvLabel 'or press Esc' 13 (C 100 116 139) 0.84 40 $false

# Skip button (e.g. while presenting): closes the overlay and restarts the 20:00 timer
$skipBtn = New-Object System.Windows.Forms.Button
$skipBtn.Text      = 'Skip break'
$skipBtn.Font      = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
$skipBtn.Size      = New-Object System.Drawing.Size(220, 56)
$skipBtn.FlatStyle = 'Flat'
$skipBtn.FlatAppearance.BorderColor = C 100 116 139
$skipBtn.BackColor = C 30 41 59
$skipBtn.ForeColor = C 226 232 240
$skipBtn.Cursor    = [System.Windows.Forms.Cursors]::Hand
$skipBtn.Left      = ($ps.X - $vs.X) + [int](($ps.Width - 220) / 2)
$skipBtn.Top       = ($ps.Y - $vs.Y) + [int]($ps.Height * 0.74)
$skipBtn.Add_Click({ StartPhase 'work' })
$ov.Controls.Add($skipBtn)

$ov.Add_KeyDown({ if ($_.KeyCode -eq 'Escape') { StartPhase 'work' } })

function StartPhase($p) {
    $script:phase = $p
    if ($p -eq 'work') { $script:end = [DateTime]::Now.AddMinutes($WorkMin) }
    else               { $script:end = [DateTime]::Now.AddSeconds($BreakSec) }
    $script:paused = $false
    $timer.Start()
    Refresh
}

function Refresh {
    $left = if ($script:paused) { $script:remain } else { $script:end - [DateTime]::Now }
    if ($left.TotalSeconds -lt 0) { $left = [TimeSpan]::Zero }
    $t = '{0:00}:{1:00}' -f [int][math]::Floor($left.TotalMinutes), $left.Seconds
    $inBreak = ($script:phase -eq 'break') -and (-not $script:paused)

    if ($script:paused) { $lbl.Text = $t; $lbl.ForeColor = C 251 191 36 }
    else                { $lbl.Text = $t;      $lbl.ForeColor = C 56 189 248 }

    if ($inBreak) {
        $ovCount.Text = [string][int][math]::Ceiling($left.TotalSeconds)
        if (-not $ov.Visible) { $ov.Show(); $ov.Activate() }
        if ($form.Visible) { $form.Hide() }
    } else {
        if ($ov.Visible) { $ov.Hide() }
        if ((-not $script:userHidden) -and (-not $form.Visible)) { $form.Show() }
    }

    $tip = if ($inBreak) { "20-20-20: look away $($ovCount.Text)s" } else { "20-20-20: break in $t" }
    $icon.Text = if ($tip.Length -gt 63) { $tip.Substring(0, 63) } else { $tip }
    $pauseItem.Text = if ($script:paused) { 'Resume' } else { 'Pause' }
}

# ---- Menu (tray + right-click on the chip) ----
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$pauseItem = $menu.Items.Add('Pause')
$skipItem  = $menu.Items.Add('Break now')
$resetItem = $menu.Items.Add('Restart 20:00')
$showItem  = $menu.Items.Add('Hide timer chip')
$quitItem  = $menu.Items.Add('Quit')
$icon.ContextMenuStrip = $menu
$lbl.ContextMenuStrip  = $menu

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000

$timer.Add_Tick({
    $now = [DateTime]::Now
    $gap = $now - $script:lastTick
    $script:lastTick = $now
    # Laptop slept or was locked for over 2 minutes: eyes rested, start fresh 20:00.
    if ($gap.TotalMinutes -gt 2 -and -not $script:paused) { StartPhase 'work'; return }
    if (-not $script:paused -and $now -ge $script:end) {
        if ($script:phase -eq 'work') {
            [System.Media.SystemSounds]::Exclamation.Play()
            StartPhase 'break'
        } else {
            [System.Media.SystemSounds]::Asterisk.Play()
            StartPhase 'work'
        }
    } else { Refresh }
})

$pauseItem.Add_Click({
    if ($script:paused) { $script:end = [DateTime]::Now + $script:remain; $script:paused = $false }
    else { $script:remain = $script:end - [DateTime]::Now; $script:paused = $true }
    $script:lastTick = [DateTime]::Now
    Refresh
})
$skipItem.Add_Click({ [System.Media.SystemSounds]::Exclamation.Play(); StartPhase 'break' })
$resetItem.Add_Click({ StartPhase 'work' })
$showItem.Add_Click({
    if ($script:userHidden) { $script:userHidden = $false; $showItem.Text = 'Hide timer chip' }
    else { $script:userHidden = $true; $showItem.Text = 'Show timer chip'; $form.Hide() }
    Refresh
})
$quitItem.Add_Click({
    $timer.Stop(); $icon.Visible = $false; $ov.Close(); $form.Close()
    [System.Windows.Forms.Application]::Exit()
})
$icon.Add_DoubleClick({ $script:userHidden = $false; $showItem.Text = 'Hide timer chip'; Refresh })

$timer.Start()
Refresh
[System.Windows.Forms.Application]::Run()
$mutex.ReleaseMutex()
