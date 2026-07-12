param(
    [Parameter(Mandatory=$true)][string]$CsvPath,
    [Parameter(Mandatory=$true)][string]$TableName
)

Add-Type -AssemblyName "System.Data.SqlClient"
Add-Type -AssemblyName "Microsoft.VisualBasic"

$connStr = "Server=localhost\SQLEXPRESS;Database=HospitalQuality;Integrated Security=True;TrustServerCertificate=True;"
$conn = New-Object System.Data.SqlClient.SqlConnection $connStr
$conn.Open()

$parser = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($CsvPath)
$parser.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
$parser.SetDelimiters(",")
$parser.HasFieldsEnclosedInQuotes = $true

$header = $parser.ReadFields()
$colCount = $header.Count

$bulkCopy = New-Object System.Data.SqlClient.SqlBulkCopy $conn
$bulkCopy.DestinationTableName = $TableName
$bulkCopy.BatchSize = 5000
$bulkCopy.BulkCopyTimeout = 0

$dt = New-Object System.Data.DataTable
for ($i = 0; $i -lt $colCount; $i++) {
    $dt.Columns.Add("col$i") | Out-Null
}

$total = 0
while (-not $parser.EndOfData) {
    $fields = $parser.ReadFields()
    $dt.Rows.Add($fields) | Out-Null
    $total++
    if ($dt.Rows.Count -ge 5000) {
        $bulkCopy.WriteToServer($dt)
        $dt.Rows.Clear()
    }
}
if ($dt.Rows.Count -gt 0) {
    $bulkCopy.WriteToServer($dt)
}

$parser.Close()
$conn.Close()

Write-Host "Imported $total rows into $TableName"
