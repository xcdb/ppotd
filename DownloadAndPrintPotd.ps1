
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

# Define a function to download the photo
function Download-PhotoOfTheDay {
    try {
        # Use Invoke-WebRequest to retrieve the HTML content
        $htmlContent = Invoke-WebRequest -Uri $photoOfTheDayUrl

        # Extract the 'Gallery' link (look for an <a> tag with href beginning with '/news/gallery/')
        $galleryLink = $htmlContent.Links |
            Where-Object { ![String]::IsNullOrEmpty($_.href) } |
            Where-Object { $_.href -like '/news/gallery/*' } |
            Select-Object -First 1

        if (-Not $galleryLink) {
            Write-Error "Failed to find the 'Gallery' link on the page."
            return $false
        }


        #build the uri
        $galleryPageUri = [System.Uri]::new([System.Uri]::new($photoOfTheDayUrl), $galleryLink.href)
        
        # Follow the 'Gallery' link
        $galleryPageContent = Invoke-WebRequest -Uri $galleryPageUri #-Headers @{ "referer" = "https://www.theguardian.com/" }
        
        # Find the image with the largest dimensions
        $largestImage = $galleryPageContent.Images |
            Sort-Object { $_.width * $_.height } -Descending |
            Select-Object -First 1



        $largestImageUri = [System.Uri]::new($largestImage.src.Replace("&amp;","&"))
            $nvc = [System.Web.HttpUtility]::ParseQueryString($largestImageUri.Query)
            $query = "?width=" + ([Int32]::Parse($nvc["width"]) * 4) + "&dpr=1&s=none&crop=none"

       $largestImageUrl = $largestImageUri.AbsoluteUri.Substring(0, $largestImageUri.AbsoluteUri.Length - $largestImageUri.Query.Length) + $query
        


       # Validate the image URL
       if (-Not $largestImageUrl) {
           Write-Error "Failed to find a valid image URL in the gallery."
           return $false
       }

               # Download the image file
       Invoke-WebRequest -Uri $largestImageUrl -OutFile $outputFilePath -Headers @{ "referer" = $photoOfTheDayUrl }
       Write-Output "Photo downloaded successfully to $outputFilePath."        return $true
    } catch {
        Write-Error "An error occurred while downloading the photo: $_"
        return $false
    }
}

# Define a function to send the photo to the printer
function Print-Photo {
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
if (Download-PhotoOfTheDay) {
    Print-Photo
} else {
    Write-Output "Failed to download the photo. Process terminated."
}





