param(
    [Parameter(Mandatory = $true)]
    [string]$InputSvg,

    [Parameter(Mandatory = $true)]
    [string]$OutputPng,

    [int]$Size = 1280
)

$ErrorActionPreference = 'Stop'

if ($Size -lt 1) {
    throw 'Size must be a positive integer.'
}

if (-not (Test-Path -LiteralPath $InputSvg -PathType Leaf)) {
    throw "SVG input was not found: $InputSvg"
}

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

[xml]$document = Get-Content -LiteralPath $InputSvg -Raw
$namespace = New-Object System.Xml.XmlNamespaceManager($document.NameTable)
$namespace.AddNamespace('svg', 'http://www.w3.org/2000/svg')
$paths = @($document.SelectNodes('//svg:path', $namespace))
if ($paths.Count -eq 0) {
    throw 'SVG contains no path elements to render.'
}

function Get-InheritedAttribute([System.Xml.XmlNode]$Node, [string]$Name) {
    $current = $Node
    while ($current) {
        $attribute = if ($current.Attributes) { $current.Attributes.GetNamedItem($Name) } else { $null }
        if ($attribute -and -not [string]::IsNullOrWhiteSpace($attribute.Value)) {
            return $attribute.Value
        }
        $current = $current.ParentNode
    }
    return $null
}

function Get-Translation([System.Xml.XmlNode]$Node) {
    [double]$x = 0
    [double]$y = 0
    $current = $Node.ParentNode
    while ($current) {
        $transformAttribute = if ($current.Attributes) { $current.Attributes.GetNamedItem('transform') } else { $null }
        $transform = if ($transformAttribute) { $transformAttribute.Value } else { $null }
        if ($transform -match 'translate\(\s*([-+]?\d*\.?\d+)\s*(?:[,\s]+\s*([-+]?\d*\.?\d+))?\s*\)') {
            $x += [double]::Parse($matches[1], [Globalization.CultureInfo]::InvariantCulture)
            if ($matches[2]) {
                $y += [double]::Parse($matches[2], [Globalization.CultureInfo]::InvariantCulture)
            }
        }
        $current = $current.ParentNode
    }
    return [Windows.Vector]::new($x, $y)
}

$visual = New-Object Windows.Media.DrawingVisual
$context = $visual.RenderOpen()
try {
    foreach ($path in $paths) {
        $data = $path.GetAttribute('d')
        $fill = Get-InheritedAttribute $path 'fill'
        if ([string]::IsNullOrWhiteSpace($data) -or [string]::IsNullOrWhiteSpace($fill) -or $fill -eq 'none') {
            continue
        }

        $geometry = [Windows.Media.Geometry]::Parse($data)
        $translation = Get-Translation $path
        if ($translation.X -ne 0 -or $translation.Y -ne 0) {
            $geometry = $geometry.Clone()
            $geometry.Transform = [Windows.Media.TranslateTransform]::new($translation.X, $translation.Y)
        }

        $brush = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString($fill))
        $brush.Freeze()
        $context.DrawGeometry($brush, $null, $geometry)
    }
} finally {
    $context.Close()
}

$bitmap = [Windows.Media.Imaging.RenderTargetBitmap]::new(
    $Size,
    $Size,
    96,
    96,
    [Windows.Media.PixelFormats]::Pbgra32
)
$bitmap.Render($visual)

$outputDirectory = Split-Path -Parent $OutputPng
if ($outputDirectory) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
$stream = [IO.File]::Open($OutputPng, [IO.FileMode]::Create, [IO.FileAccess]::Write)
try {
    $encoder.Save($stream)
} finally {
    $stream.Dispose()
}

Write-Host "Rendered SVG source: $InputSvg"
Write-Host "Transparent PNG: $OutputPng"
