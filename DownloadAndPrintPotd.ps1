# PowerShell script to download the 'Photo of the Day' from The Guardian and send it to a local printer

# Define the URL for The Guardian's 'Photo of the Day' page
$photoOfTheDayUrl = 'https://www.theguardian.com/news/series/ten-best-photographs-of-the-day'

# Folder where the photo will be saved locally
$outputFolder = "$env:USERPROFILE\Downloads\PhotoOfTheDay"
$photoFileName = "PhotoOfTheDay.jpg"
$outputFilePath = Join-Path -Path $outputFolder -ChildPath $photoFileName

# Create the output folder if it doesn't exist
if (-Not (Test-Path -Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder -Force
}

function Download-Potd {
    try {
        #retrieve the POTD content
        $htmlContent = Invoke-WebRequest -Uri $photoOfTheDayUrl

        #find link to the Gallery
        $galleryLink = $htmlContent.Links |
            Where-Object { ![String]::IsNullOrEmpty($_.href) } |
            Where-Object { $_.href -like '/news/gallery/*' } |
            Select-Object -First 1

        if (-Not $galleryLink) {
            Write-Error "Failed to find the gallery link on the page."
            return $false
        }

        #construct an absolute URI for it
        $galleryPageUri = [System.Uri]::new([System.Uri]::new($photoOfTheDayUrl), $galleryLink.href)
        
        #retrieve the Gallery content
        $galleryPageContent = Invoke-WebRequest -Uri $galleryPageUri -Headers @{ "referer" = $photoOfTheDayUrl }
        
        #pick one of the images at random
        $galleryImage = $galleryPageContent.Images |
            Sort-Object { $_.width * $_.height } -Descending |
            Select-Object -First 10 |
            #Get-SecureRandom -Shuffle |
            Select-Object -First 1

        if (-Not $galleryImage) {
            Write-Error "Failed to find a gallery image."
            return $false
        }

        #pick one of the images at random
        $galleryImage = $galleryPageContent.Images |
            Sort-Object { $_.width * $_.height } -Descending |
            Select-Object -First 10 |
            Get-SecureRandom -Shuffle |
            Select-Object -First 1

        #build a new URI for 4x the default size
        $imageUri = [System.Uri]::new($galleryImage.src.Replace("&amp;","&"))
        $nvc = [System.Web.HttpUtility]::ParseQueryString($imageUri.Query)
        $query = "?width=" + ([Int32]::Parse($nvc["width"]) * 4) + "&dpr=1&s=none&crop=none"

        $constructedImageUrl = $imageUri.AbsoluteUri.Substring(0, $imageUri.AbsoluteUri.Length - $imageUri.Query.Length) + $query

        #check we constructed one ok
        if (-Not $constructedImageUrl) {
            Write-Error "Failed to build a valid image URL."
            return $false
        }

        #download the image file
        Invoke-WebRequest -Uri $constructedImageUrl -OutFile $outputFilePath -Headers @{ "referer" = $photoOfTheDayUrl }
        Write-Output "Photo downloaded successfully to $outputFilePath."
        return $true
    } catch {
        Write-Error "An error occurred while downloading the photo: $_"
        return $false
    }
}


# Define a function to send the photo to the printer
function Print-Potd {
    try {
        # Check if the photo file exists
        if (-Not (Test-Path -Path $outputFilePath)) {
            Write-Error "Photo file not found: $outputFilePath"
            return $false
        }

        # Use the Windows Print command to print the file
        Start-Process -FilePath "mspaint.exe" -ArgumentList "/p $outputFilePath" -NoNewWindow -Wait
        Write-Output "Photo sent to the printer successfully."
        return $true
    } catch {
        Write-Error "An error occurred while printing the photo: $_"
        return $false
    }
}

# Main execution
Write-Output "Starting the download and print process..."
if (Download-Potd) {
    Print-Potd
} else {
    Write-Output "Failed to download the photo. Process terminated."
}





