<#
  মৌখামার — MySQL query চালানোর সহজ উপায় (viva ও ডেভেলপমেন্টের জন্য)

  ব্যবহার:
    .\db.ps1 "SELECT * FROM hives LIMIT 5"      # সরাসরি query
    .\db.ps1 -File queries\05_triggers.sql      # ফাইল চালানো
    .\db.ps1 -Objects                           # সব table/view/procedure/function/trigger/event দেখাও
    .\db.ps1 -Tables                            # শুধু টেবিল ও সারির সংখ্যা
    .\db.ps1                                    # mysql> prompt খুলবে (interactive)
    .\db.ps1 -NoDb -File sql\00_create_db.sql   # database তৈরির আগে
    .\db.ps1 -Force -File queries\01_...sql     # ভুল হলেও থামবে না (demo ফাইলের জন্য)
    .\db.ps1 -Dump                              # sql\schema_dump.sql নতুন করে বানায়

  পাসওয়ার্ড .env ফাইলের DB_PASSWORD থেকে আসে — command line-এ কখনো লেখা হয় না।
#>
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]] $Query,
    [string] $File,
    [switch] $Objects,
    [switch] $Tables,
    [switch] $NoDb,
    [switch] $Raw,
    [switch] $Force,
    [switch] $Dump
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

# ---- .env পড়া ----
$cfg = @{ DB_NAME = 'moukhamar_db'; DB_USER = 'root'; DB_PASSWORD = ''; DB_HOST = '127.0.0.1'; DB_PORT = '3306' }
$envFile = Join-Path $root '.env'
if (Test-Path $envFile) {
    foreach ($line in (Get-Content $envFile -Encoding UTF8)) {
        $t = $line.Trim()
        if ($t -and -not $t.StartsWith('#') -and $t.Contains('=')) {
            $i = $t.IndexOf('=')
            $cfg[$t.Substring(0, $i).Trim()] = $t.Substring($i + 1).Trim().Trim('"').Trim("'")
        }
    }
}

# ---- mysql.exe খোঁজা ----
$mysql = $null
$found = Get-Command mysql.exe -ErrorAction SilentlyContinue
if ($found) { $mysql = $found.Source }
if (-not $mysql) {
    $candidates = @(
        'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe',
        'C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe',
        'C:\Program Files\MySQL\MySQL Workbench 8.0\mysql.exe'
    )
    foreach ($c in $candidates) { if (Test-Path $c) { $mysql = $c; break } }
}
if (-not $mysql) {
    Write-Host '[!] mysql.exe পাওয়া যায়নি। MySQL Server 8.0 install করা আছে কি দেখুন।' -ForegroundColor Red
    exit 1
}

if (-not $cfg['DB_PASSWORD']) {
    Write-Host '[!] .env ফাইলের DB_PASSWORD খালি। আপনার MySQL root পাসওয়ার্ড ওখানে লিখুন।' -ForegroundColor Yellow
}
$env:MYSQL_PWD = $cfg['DB_PASSWORD']

# ---- -Dump: জমা দেওয়ার জন্য পুরো schema বের করা ----
# টেবিল, ভিউ, function, procedure, trigger আর event — সব এক ফাইলে।
# --no-data দেওয়ায় শুধু গঠন আসে, কোনো সারি নয়।
if ($Dump) {
    $dumpExe = $mysql -replace 'mysql\.exe$', 'mysqldump.exe'
    if (-not (Test-Path $dumpExe)) {
        Write-Host "[!] mysqldump.exe পাওয়া যায়নি: $dumpExe" -ForegroundColor Red
        exit 1
    }

    $target = Join-Path $root 'sql\schema_dump.sql'
    $body = Join-Path $env:TEMP ('mk-dump-' + [guid]::NewGuid().ToString('N') + '.sql')
    $errFile = "$body.err"

    # pipeline দিয়ে নেওয়া যায় না: PowerShell native program-এর output
    # console-এর codepage ধরে string বানায়, তাতে বাংলা বাইট নষ্ট হয়।
    # Start-Process -RedirectStandardOutput সরাসরি বাইট ফাইলে লেখে।
    $ErrorActionPreference = 'Continue'
    $dumpArgs = @('-u', $cfg['DB_USER'], '-h', $cfg['DB_HOST'], '-P', $cfg['DB_PORT'],
                  '--default-character-set=utf8mb4', '--no-data', '--routines',
                  '--triggers', '--events', '--no-tablespaces', '--skip-comments',
                  '--databases', $cfg['DB_NAME'])
    $proc = Start-Process -FilePath $dumpExe -ArgumentList $dumpArgs `
        -RedirectStandardOutput $body -RedirectStandardError $errFile `
        -NoNewWindow -Wait -PassThru

    if ($proc.ExitCode -ne 0) {
        foreach ($line in (Get-Content $errFile -Encoding UTF8 -ErrorAction SilentlyContinue)) {
            if ($line -notmatch 'Using a password') { Write-Host $line -ForegroundColor Yellow }
        }
        Remove-Item $body, $errFile -Force -ErrorAction SilentlyContinue
        $env:MYSQL_PWD = $null
        exit $proc.ExitCode
    }

    $header = @"
-- =====================================================================
-- মৌখামার — পুরো ডাটাবেজের গঠন (mysqldump দিয়ে বের করা)
--
-- এই ফাইলটা হাতে লেখা নয়। `.\db.ps1 -Dump` দিয়ে চলতি ডাটাবেজ থেকে
-- বের করা — তাই এতে যা আছে, ডাটাবেজে ঠিক তাই আছে।
--
-- ভেতরে: টেবিল (PK, FK, UNIQUE, CHECK, INDEX), ভিউ, FUNCTION,
--         PROCEDURE, TRIGGER আর EVENT। কোনো সারি নেই (--no-data)।
--
-- ডাটা আলাদা দুই জায়গা থেকে আসে:
--   sql/10_seed.sql           — ৬৪ জেলা, ৫০১ উপজেলা, রোগ, ফুল
--   manage.py seed_demo       — ডেমো ব্যবহারকারী ও নমুনা খামার
--
-- পড়ার মতো, ভাগ করা SQL চাইলে sql/01…11 ফাইলগুলো দেখুন — ওখানে
-- প্রতিটা অংশের ব্যাখ্যা বাংলায় লেখা আছে।
-- =====================================================================

"@
    # বাইট ধরে জোড়া লাগানো — কোথাও decode/encode হয় না, তাই বাংলা অক্ষত
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $bytes = $utf8.GetBytes($header) + [System.IO.File]::ReadAllBytes($body)
    [System.IO.File]::WriteAllBytes($target, $bytes)

    Remove-Item $body, $errFile -Force -ErrorAction SilentlyContinue
    $env:MYSQL_PWD = $null

    $lines = (Get-Content $target -Encoding UTF8 | Measure-Object -Line).Lines
    Write-Host "→ sql\schema_dump.sql লেখা হয়েছে ($lines লাইন)" -ForegroundColor Green
    exit 0
}

$mysqlArgs = @('-u', $cfg['DB_USER'], '-h', $cfg['DB_HOST'], '-P', $cfg['DB_PORT'], '--default-character-set=utf8mb4')
if (-not $NoDb) { $mysqlArgs += @('--database', $cfg['DB_NAME']) }
if (-not $Raw) { $mysqlArgs += '--table' }
# -Force: একটা statement ভুল হলেও বাকিগুলো চলবে। constraint-এর demo
# ফাইলে ভুল INSERT গুলোই দেখানোর জিনিস, তাই ওখানে এটা দরকার।
if ($Force) { $mysqlArgs += '--force' }

# ---- কী চালাব ঠিক করা ----
$db = $cfg['DB_NAME']
$sql = $null

if ($Objects) {
    $sql = @"
SELECT 'TABLE' AS ধরন, TABLE_NAME AS নাম, '' AS বিস্তারিত
  FROM information_schema.TABLES  WHERE TABLE_SCHEMA = '$db' AND TABLE_TYPE = 'BASE TABLE'
UNION ALL
SELECT 'VIEW', TABLE_NAME, '' FROM information_schema.VIEWS WHERE TABLE_SCHEMA = '$db'
UNION ALL
SELECT ROUTINE_TYPE, ROUTINE_NAME, '' FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = '$db'
UNION ALL
SELECT 'TRIGGER', TRIGGER_NAME, CONCAT(ACTION_TIMING, ' ', EVENT_MANIPULATION, ' ON ', EVENT_OBJECT_TABLE)
  FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA = '$db'
UNION ALL
SELECT 'EVENT', EVENT_NAME, STATUS FROM information_schema.EVENTS WHERE EVENT_SCHEMA = '$db'
ORDER BY ধরন, নাম;
"@
}
elseif ($Tables) {
    $sql = @"
SELECT TABLE_NAME AS টেবিল, TABLE_ROWS AS 'সারি (আনুমানিক)', ENGINE AS engine, TABLE_COLLATION AS collation
  FROM information_schema.TABLES
 WHERE TABLE_SCHEMA = '$db' AND TABLE_TYPE = 'BASE TABLE'
 ORDER BY TABLE_NAME;
"@
}
elseif ($File) {
    $path = $File
    if (-not [System.IO.Path]::IsPathRooted($path)) { $path = Join-Path $root $File }
    if (-not (Test-Path $path)) {
        Write-Host "[!] ফাইল পাওয়া যায়নি: $path" -ForegroundColor Red
        exit 1
    }
    $sql = 'SOURCE ' + ((Resolve-Path $path).Path).Replace('\','/') + ';'
    Write-Host "→ চালানো হচ্ছে: $File" -ForegroundColor Cyan
}
elseif ($Query) {
    $sql = ($Query -join ' ')
}

# ---- চালানো ----
# mysql ভুলের কথা stderr-এ লেখে। Windows PowerShell 5.1 native program-এর
# stderr-এর প্রতিটা লাইনকে ErrorRecord বানায়, আর ErrorActionPreference
# 'Stop' থাকলে সেখানেই script থেমে যায় — ফলে MySQL-এর আসল ভুলের বার্তা
# দেখাই যায় না। তাই native call-এর আগে এটা 'Continue' করা হলো।
$ErrorActionPreference = 'Continue'

if (-not $sql) {
    Write-Host "→ $db — mysql> prompt (বেরোতে \q)" -ForegroundColor Cyan
    & $mysql @mysqlArgs
    exit $LASTEXITCODE
}

# SQL টা UTF-8 (BOM ছাড়া) ফাইলে লিখে mysql-এর stdin-এ পাঠানো হয়।
# কেন stdin, SOURCE নয়:
#   • PowerShell native program-এ argument পাঠায় system ANSI codepage-এ,
#     তাই argument দিয়ে বাংলা query পাঠালে ভেঙে যায়। ফাইলের বাইট
#     সরাসরি stdin-এ গেলে কিছু বদলায় না।
#   • --force (ভুল হলেও চালিয়ে যাওয়া) SOURCE-এর ভেতরে কাজ করে না,
#     stdin দিয়ে এলে করে — constraint-এর demo ফাইলের জন্য এটা দরকার।
$tmpSql = Join-Path $env:TEMP ('mk-' + [guid]::NewGuid().ToString('N') + '.sql')
$tmpOut = "$tmpSql.out"
$tmpErr = "$tmpSql.err"
try {
    [System.IO.File]::WriteAllText($tmpSql, $sql, (New-Object System.Text.UTF8Encoding($false)))
    $proc = Start-Process -FilePath $mysql -ArgumentList $mysqlArgs `
        -RedirectStandardInput $tmpSql -RedirectStandardOutput $tmpOut `
        -RedirectStandardError $tmpErr -NoNewWindow -Wait -PassThru

    if (Test-Path $tmpOut) { Get-Content $tmpOut -Encoding UTF8 }
    if (Test-Path $tmpErr) {
        foreach ($line in (Get-Content $tmpErr -Encoding UTF8)) {
            if ($line -match 'Using a password') { continue }
            Write-Host $line -ForegroundColor Yellow
        }
    }
    $code = $proc.ExitCode
}
finally {
    Remove-Item $tmpSql, $tmpOut, $tmpErr -Force -ErrorAction SilentlyContinue
    $env:MYSQL_PWD = $null
}
exit $code
