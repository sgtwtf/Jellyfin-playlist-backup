#########################################################
#########################################################
#########################################################
$ApiKey = "XYZ987"
$DestServer = "http://your-new-jellyfin-server:8096"
$BackupFile = "D:\JellyfinPlaylists\user1\favs.json"
########################################################
## The user from the soruce needs to match the destintation
## if it does not, decare the destination user on line 27
## etc $User = user1
########################################################



$Headers = @{
    "X-Emby-Token" = $ApiKey
}

Add-Type -AssemblyName System.Web

$Backup = Get-Content $BackupFile -Raw | ConvertFrom-Json

$Users = Invoke-RestMethod `
    -Uri "$DestServer/Users" `
    -Headers $Headers

$User = $Users | Where-Object Name -eq $Backup.UserName

if (-not $User)
{
    throw "User '$($Backup.UserName)' not found."
}

Write-Host ""
Write-Host "User     : $($User.Name)"
Write-Host "Playlist : $($Backup.Playlist)"
Write-Host ""

$MatchedItems = foreach ($Item in $Backup.Items)
{
    Write-Host "Searching for $($Item.Name)"

    $SearchTerm = [System.Web.HttpUtility]::UrlEncode($Item.Name)

    $Results = (
        Invoke-RestMethod `
            -Uri "$DestServer/Users/$($User.Id)/Items?SearchTerm=$SearchTerm&Recursive=true" `
            -Headers $Headers
    ).Items

    $Match = $null

    $Match = $Results |
        Where-Object {
            $_.Name -eq $Item.Name -and
            $_.SeriesName -eq $Item.SeriesName -and
            $_.SeasonName -eq $Item.SeasonName
        } |
        Select-Object -First 1


    if (-not $Match)
    {
        $Match = $Results |
            Where-Object {
                $_.Name -eq $Item.Name -and
                $_.SeriesName -eq $Item.SeriesName
            } |
            Select-Object -First 1
    }

    if (-not $Match)
    {
        $Match = $Results |
            Where-Object {
                $_.Name -eq $Item.Name
            } |
            Select-Object -First 1
    }

    [PSCustomObject]@{
        SourceName    = $Item.Name
        DestinationId = $Match.Id
        Found         = [bool]$Match
    }
}

$FailedMatches = $MatchedItems | Where-Object { -not $_.Found }

Write-Host ""
Write-Host "Validation"
Write-Host "----------"
Write-Host "Matched: $($(($MatchedItems | Where-Object Found).Count))"
Write-Host "Missing: $($FailedMatches.Count)"
Write-Host ""

if ($FailedMatches.Count)
{
    Write-Host "Missing Media"
    Write-Host "-------------"

    $FailedMatches |
        Select-Object SourceName |
        Format-Table -AutoSize

    throw "Validation failed."
}

$ExistingPlaylist = (
    Invoke-RestMethod `
        -Uri "$DestServer/Users/$($User.Id)/Items?IncludeItemTypes=Playlist&Recursive=true" `
        -Headers $Headers
).Items | Where-Object Name -eq $Backup.Playlist

if (-not $ExistingPlaylist)
{
    Write-Host ""
    Write-Host "Playlist does not exist."
    Write-Host ""

    $Response = Read-Host "Create playlist? (Y/N)"

    if ($Response -eq "Y")
    {
        $IdList = $MatchedItems.DestinationId -join ","

        $PlaylistName = [System.Web.HttpUtility]::UrlEncode($Backup.Playlist)

        Invoke-RestMethod `
            -Method Post `
            -Uri "$DestServer/Playlists?Name=$PlaylistName&Ids=$IdList&UserId=$($User.Id)" `
            -Headers $Headers

        Write-Host "Playlist created."
    }

    return
}


$ExistingItems = (
    Invoke-RestMethod `
        -Uri "$DestServer/Users/$($User.Id)/Items?ParentId=$($ExistingPlaylist.Id)" `
        -Headers $Headers
).Items

$BackupIds = $MatchedItems.DestinationId
$ExistingIds = $ExistingItems.Id

$OnlyInBackup = $BackupIds |
    Where-Object { $_ -notin $ExistingIds }

$OnlyInExisting = $ExistingIds |
    Where-Object { $_ -notin $BackupIds }

Write-Host ""
Write-Host "Comparison"
Write-Host "----------"
Write-Host "Backup Items     : $($BackupIds.Count)"
Write-Host "Playlist Items   : $($ExistingIds.Count)"
Write-Host "Need To Add      : $($OnlyInBackup.Count)"
Write-Host "Would Remove     : $($OnlyInExisting.Count)"
Write-Host ""

if (($OnlyInBackup.Count -eq 0) -and ($OnlyInExisting.Count -eq 0))
{
    Write-Host "Playlist already matches backup."
    return
}

Write-Host ""
Write-Host "[A] Add Missing Items"
Write-Host "[R] Replace Playlist"
Write-Host "[S] Skip"
Write-Host ""

$Choice = Read-Host "Choice"

switch ($Choice.ToUpper())
{
    "A"
    {
        if ($OnlyInBackup.Count -eq 0)
        {
            Write-Host "Nothing to add."
            break
        }

        $IdList = $OnlyInBackup -join ","

        Invoke-RestMethod `
            -Method Post `
            -Uri "$DestServer/Playlists/$($ExistingPlaylist.Id)/Items?Ids=$IdList&UserId=$($User.Id)" `
            -Headers $Headers

        Write-Host ""
        Write-Host "$($OnlyInBackup.Count) item(s) added."
    }

    "R"
    {
        Write-Host ""
        Write-Host "Replacing playlist..."

        Invoke-RestMethod `
            -Method Delete `
            -Uri "$DestServer/Items/$($ExistingPlaylist.Id)" `
            -Headers $Headers

        Start-Sleep -Seconds 2

        $IdList = $MatchedItems.DestinationId -join ","

        $PlaylistName = [System.Web.HttpUtility]::UrlEncode($Backup.Playlist)

        Invoke-RestMethod `
            -Method Post `
            -Uri "$DestServer/Playlists?Name=$PlaylistName&Ids=$IdList&UserId=$($User.Id)" `
            -Headers $Headers

        Write-Host "Playlist replaced."
    }

    Default
    {
        Write-Host "Skipped."
    }
}
