# See LICENSE.md for license.

param (
        [string[]] $dirs, 
        [ScriptBlock]$onChange
      )

Set-Variable -Name MODE_FILE -Value "File" -option Constant;
Set-Variable -Name MODE_DIR -Value "Directory" -option Constant;

function stat-mode {
    param ([string] $path) 
    if (Test-Path -PathType Leaf -Path $path) {
        Write-Output $MODE_FILE;
    } elseif (Test-Path -PathType Container -Path $path) {
        Write-Output $MODE_DIR;
    } else {
        Write-Error "Cannot stat $path";
        exit 1;
    }
}

function stat-size {
    param ([string] $path,
            [string] $mode)
    switch ($mode) {
        $MODE_FILE { Write-Output (Get-Item $path).Length; break; }
        $MODE_DIR { Write-Output (Get-ChildItem $path).Length; break; }
        default { Write-Error "AAAAAHHH"; exit 2 }
    }
}


function stat-path {
    param ([string] $path) 

    $info = Get-Item $path;
    $mode = stat-mode $path;

    Write-Output ([PSCustomObject] @{
        Path=$path
        Modified=$info.LastWriteTime;
        Size=(stat-size $path $mode)
        Mode=$mode;
    })
}

function dir-stat {
    param([string] $dir)

        Write-Output ([PSCustomObject] @{
            Path=$dir;
            Mode="Directory";
            Size=(gci $dir).Length;
            Modified=(gi $dir).LastWriteTime;
        });
}

function ls-r {
    param([string] $dir)
    $results = @()
    $info = stat-path $dir;

    Write-Output (Get-ChildItem $dir | . { 
        begin {
            $path = (gi $dir).FullName;
            if ($info.mode -eq "File") {
                # Will get listed below
            } elseif ($info.mode -eq "Directory") {
                Write-Output (dir-stat $path)
            } else {
                Write-Error "Cannot stat entry $info"
                exit 1
            }
        }
        process {
            if (Test-Path -PathType Leaf -Path $_) {
                Write-Output (stat-path $_.FullName);
            } elseif (Test-Path -PathType Container -Path $_) {
                Write-Output (ls-r $_.FullName)
            }
        }
    });
}

Set-Variable -Name CH_SOME -Value "change.some" -option Constant;
Set-Variable -Name CH_NONE -Value "change.none" -option Constant;

function check-changes {
    param ( [array] $filesAndDirs)
    $filesAndDirs | % {
        $fresh = stat-path $_.Path
        $cmp = $fresh.Modified -eq $_.Modified -and $fresh.Size -eq $_.Size;
        if (-not $cmp) {
            return $CH_SOME;
        }
    }
    return $CH_NONE
}


function run-main {
    param (
        [string[]] $entries,
        [ScriptBlock] $onChange
    )

    try {
        $outputTimer = New-Object System.Timers.Timer;
        $outputTimer.Interval = 100;
        $outputTimer.AutoReset = $true;
        Register-ObjectEvent -InputObject $outputTimer -EventName Elapsed -MessageData "psi/check-output" -SourceIdentifier "psi/check-output"
        $outputTimer.Start();

        $changeTimer = New-Object System.Timers.Timer;
        $changeTimer.Interval = 1000;
        $changeTimer.AutoReset = $true;
        Register-ObjectEvent -InputObject $changeTimer -EventName Elapsed -MessageData "psi/check-changes" -SourceIdentifier "psi/check-changes"
        $changeTimer.Start();


        $bgJob = (Start-ThreadJob -ScriptBlock $onChange);

        $toWatch = $entries | % { ls-r $_ }
        while ($true) {
            $evt = Wait-Event 
            if ($evt.MessageData -ieq "psi/check-changes") {
                Remove-Event -EventIdentifier $evt.EventIdentifier
                $changeType = check-changes -filesAndDirs $toWatch
                if ($changeType -eq $CH_SOME) {
                    $toWatch = $entries | % { ls-r $_ }
                    Stop-Job -Id $bgJob.Id
                    Receive-Job -Id $bgJob.Id
                    Remove-Job -Id $bgJob.Id
                    $bgJob = (Start-ThreadJob -ScriptBlock $onChange);
                }
            } elseif ($evt.MessageData -ieq "psi/check-output") {
                Remove-Event -EventIdentifier $evt.EventIdentifier
                Receive-Job -Id $bgJob.Id
            }
        }
    } finally {
        $changeTimer.Stop();
        $outputTimer.Stop();
        Unregister-Event -SourceIdentifier "psi/check-changes";
        Unregister-Event -SourceIdentifier "psi/check-output"
    }
}

run-main -entries $dirs -onChange $onChange > $null
