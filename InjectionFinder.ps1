$name = Read-Host "Enter one Minecraft username"

if ($name -notmatch '^[A-Za-z0-9_]{3,16}$') {
    throw "Username must be 3-16 letters, numbers, or underscores."
}

$url = "https://namemc.com/search?q=$([uri]::EscapeDataString($name))"
Start-Process $url
