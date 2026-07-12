param(
    [Parameter(Mandatory=$true)][string]$CsvPath
)

Add-Type -AssemblyName "Microsoft.VisualBasic"

$parser = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($CsvPath)
$parser.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
$parser.SetDelimiters(",")
$parser.HasFieldsEnclosedInQuotes = $true

$header = $parser.ReadFields()
$colCount = $header.Count
$maxLen = New-Object int[] $colCount

while (-not $parser.EndOfData) {
    $fields = $parser.ReadFields()
    for ($i = 0; $i -lt $colCount; $i++) {
        if ($fields[$i] -ne $null -and $fields[$i].Length -gt $maxLen[$i]) {
            $maxLen[$i] = $fields[$i].Length
        }
    }
}
$parser.Close()

for ($i = 0; $i -lt $colCount; $i++) {
    Write-Host "$($i+1). $($header[$i]) -> max $($maxLen[$i])"
}
