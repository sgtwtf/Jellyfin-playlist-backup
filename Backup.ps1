###############################################################
###############################################################
###############################################################
$ApiKey = "abc123"
$SourceServer = "https://your-jellyfin-server"
$BackupFolder = "G:\JellyfinPlaylists"
###############################################################




$Headers = @{
    "X-Emby-Token" = $ApiKey
}

New-Item -ItemType Directory -Path $BackupFolder -Force | Out-Null


$Users = Invoke-RestMethod `
    -Uri "$SourceServer/Users" `
    -Headers $Headers

foreach ($User in $Users)
{
    Write-Host "Processing user $($User.Name)..."

    $UserFolder = Join-Path $BackupFolder $User.Name

    New-Item `
        -ItemType Directory `
        -Path $UserFolder `
        -Force | Out-Null

  
    $Playlists = (
        Invoke-RestMethod `
            -Uri "$SourceServer/Users/$($User.Id)/Items?IncludeItemTypes=Playlist&Recursive=true" `
            -Headers $Headers
    ).Items

    foreach ($Playlist in $Playlists)
    {
        Write-Host "  Backing up $($Playlist.Name)"

        $PlaylistItems = (
            Invoke-RestMethod `
                -Uri "$SourceServer/Users/$($User.Id)/Items?ParentId=$($Playlist.Id)" `
                -Headers $Headers
        ).Items

        $Backup = [PSCustomObject]@{
            UserName   = $User.Name
            UserId     = $User.Id
            Playlist   = $Playlist.Name
            PlaylistId = $Playlist.Id
            BackupDate = Get-Date

            Items = @(
                $PlaylistItems |
                ForEach-Object {

                    [PSCustomObject]@{
                        Name            = $_.Name
                        Id              = $_.Id
                        Type            = $_.Type
                        SeriesName      = $_.SeriesName
                        SeasonName      = $_.SeasonName
                        ProductionYear  = $_.ProductionYear
                    }
                }
            )
        }

        $SafeName = $Playlist.Name -replace '[\\/:*?"<>|]', '_'

        $Backup |
            ConvertTo-Json -Depth 10 |
            Set-Content (
                Join-Path $UserFolder "$SafeName.json"
            )
    }
}

Write-Host "Backup completed."
