#Requires -Version 5.1
$ErrorActionPreference = "Stop"

# ============================================================
#  SPRING BOOT LEARNING PROJECT CREATOR
# ============================================================

$JAVA_VERSION      = "21"
$LOMBOK_VERSION    = "1.18.36"
$MAPSTRUCT_VERSION = "1.5.5.Final"

$PG_USER    = "viraj"
$PG_PASS    = "viraj@123"
$MYSQL_USER = "root"
$MYSQL_PASS = "viraj@123"

$profiles = @{
    "1" = @{ Name = "Spring Core";            Deps = "lombok,devtools";                                           Packages = @("config","beans","service","aop","events","utils") }
    "2" = @{ Name = "Spring REST API";        Deps = "web,lombok,devtools,validation";                            Packages = @("controller","service","dto","exception","config","utils") }
    "3" = @{ Name = "Spring MVC + Thymeleaf"; Deps = "web,thymeleaf,lombok,devtools,validation";                  Packages = @("controller","service","model","config","utils") }
    "4" = @{ Name = "Spring Data JPA";        Deps = "web,data-jpa,lombok,devtools,validation";                   Packages = @("controller","service","repository","entity","dto","mapper","exception","config") }
    "5" = @{ Name = "Spring Security";        Deps = "web,security,lombok,devtools,validation";                   Packages = @("controller","service","config","filter","dto","exception","utils") }
    "6" = @{ Name = "Spring AOP";             Deps = "web,aop,lombok,devtools";                                   Packages = @("aspect","service","controller","annotation","config","utils") }
    "7" = @{ Name = "Spring Batch";           Deps = "batch,lombok,devtools";                                     Packages = @("job","step","reader","processor","writer","config","utils") }
    "8" = @{ Name = "Spring Kafka";           Deps = "web,kafka,lombok,devtools";                                 Packages = @("producer","consumer","config","dto","utils") }
    "9" = @{ Name = "Spring Full Stack";      Deps = "web,data-jpa,security,lombok,devtools,validation,actuator"; Packages = @("controller","service","repository","entity","dto","mapper","exception","config","filter","utils") }
}

$dbProfiles = @{
    "1" = @{ Name = "PostgreSQL";     Dep = "postgresql";   Driver = "org.postgresql.Driver";         Dialect = "org.hibernate.dialect.PostgreSQLDialect"; Type = "pg"    }
    "2" = @{ Name = "MySQL";          Dep = "mysql";        Driver = "com.mysql.cj.jdbc.Driver";      Dialect = "org.hibernate.dialect.MySQLDialect";       Type = "mysql" }
    "3" = @{ Name = "MongoDB";        Dep = "data-mongodb"; Driver = "";                              Dialect = "";                                          Type = "mongo" }
    "4" = @{ Name = "H2 (In-Memory)"; Dep = "h2";           Driver = "org.h2.Driver";                 Dialect = "org.hibernate.dialect.H2Dialect";           Type = "h2"    }
    "5" = @{ Name = "No Database";    Dep = "";             Driver = "";                              Dialect = "";                                          Type = "none"  }
}

$quickPresets = @{
    "Q1" = @{ Name = "REST API + PostgreSQL";   ProfileKey = "2"; DbKey = "1" }
    "Q2" = @{ Name = "Full Stack + PostgreSQL"; ProfileKey = "9"; DbKey = "1" }
    "Q3" = @{ Name = "Spring Core + No DB";     ProfileKey = "1"; DbKey = "5" }
    "Q4" = @{ Name = "Data JPA + MySQL";        ProfileKey = "4"; DbKey = "2" }
    "Q5" = @{ Name = "Security + PostgreSQL";   ProfileKey = "5"; DbKey = "1" }
    "Q6" = @{ Name = "Data JPA + PostgreSQL";   ProfileKey = "4"; DbKey = "1" }
    "Q7" = @{ Name = "Spring AOP + No DB";      ProfileKey = "6"; DbKey = "5" }
    "Q8" = @{ Name = "Spring Batch + H2";       ProfileKey = "7"; DbKey = "4" }
}

# ============================================================
#  WRITE FILE — UTF-8 NO BOM, always
# ============================================================
function Write-TextFile {
    param ([string]$Path, [string[]]$Lines)
    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($Path, $Lines, $utf8)
}

# ============================================================
#  DEPENDENCY XML BUILDER
#  Builds each <dependency> block as a List[string] — NO angle
#  brackets inside hashtable values (PS parses < as operator)
# ============================================================
function Get-DepXml {
    param ([string]$Key)

    $L = [System.Collections.Generic.List[string]]::new()

    switch ($Key) {
        "web" {
            $L.Add("        <dependency>")
            $L.Add("            <groupId>org.springframework.boot</groupId>")
            $L.Add("            <artifactId>spring-boot-starter-web</artifactId>")
            $L.Add("        </dependency>")
        }
        "data-jpa" {
            $L.Add("        <dependency>")
            $L.Add("            <groupId>org.springframework.boot</groupId>")
            $L.Add("            <artifactId>spring-boot-starter-data-jpa</artifactId>")
            $L.Add("        </dependency>")
        }
        "security" {
            $L.Add("        <dependency>")
            $L.Add("            <groupId>org.springframework.boot</groupId>")
            $L.Add("            <artifactId>spring-boot-starter-security</artifactId>")
            $L.Add("        </dependency>")
        }
        "validation" {
            $L.Add("        <dependency>")
            $L.Add("            <groupId>org.springframework.boot</groupId>")
            $L.Add("            <artifactId>spring-boot-starter-validation</artifactId>")
            $L.Add("        </dependency>")
        }
        "thymeleaf" {
            $L.Add("        <dependency>")
            $L.Add("            <groupId>org.springframework.boot</groupId>")
            $L.Add("            <artifactId>spring-boot-starter-thymeleaf</artifactId>")
            $L.Add("        </dependency>")
        }
        "actuator" {
            $L.Add("        <dependency>")
            $L.Add("            <groupId>org.springframework.boot</groupId>")
            $L.Add("            <artifactId>spring-boot-starter-actuator</artifactId>")
            $L.Add("        </dependency>")
        }
        "batch" {
            $L.Add("        <dependency>")
            $L.Add("            <groupId>org.springframework.boot</groupId>")
            $L.Add("            <artifactId>spring-boot-starter-batch</artifactId>")
            $L.Add("        </dependency>")
        }
        "kafka" {
            $L.Add("        <dependency>")
            $L.Add("            <groupId>org.springframework.kafka</groupId>")
            $L.Add("            <artifactId>spring-kafka</artifactId>")
            $L.Add("        </dependency>")
        }
        "aop" {
            $L.Add("        <dependency>")
            $L.Add("            <groupId>org.springframework.boot</groupId>")
            $L.Add("            <artifactId>spring-boot-starter-aop</artifactId>")
            $L.Add("        </dependency>")
        }
        "data-mongodb" {
            $L.Add("        <dependency>")
            $L.Add("            <groupId>org.springframework.boot</groupId>")
            $L.Add("            <artifactId>spring-boot-starter-data-mongodb</artifactId>")
            $L.Add("        </dependency>")
        }
        "mysql" {
            $L.Add("        <dependency>")
            $L.Add("            <groupId>com.mysql</groupId>")
            $L.Add("            <artifactId>mysql-connector-j</artifactId>")
            $L.Add("            <scope>runtime</scope>")
            $L.Add("        </dependency>")
        }
        "postgresql" {
            $L.Add("        <dependency>")
            $L.Add("            <groupId>org.postgresql</groupId>")
            $L.Add("            <artifactId>postgresql</artifactId>")
            $L.Add("            <scope>runtime</scope>")
            $L.Add("        </dependency>")
        }
        "h2" {
            $L.Add("        <dependency>")
            $L.Add("            <groupId>com.h2database</groupId>")
            $L.Add("            <artifactId>h2</artifactId>")
            $L.Add("            <scope>runtime</scope>")
            $L.Add("        </dependency>")
        }
    }

    return $L
}

# ============================================================
#  DISPLAY HELPERS
# ============================================================
function Show-Header {
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Magenta
    Write-Host "       SPRING BOOT LEARNING PROJECT CREATOR" -ForegroundColor Magenta
    Write-Host "       Java: $JAVA_VERSION  |  Lombok: $LOMBOK_VERSION  |  Auto-DB" -ForegroundColor Magenta
    Write-Host "  ============================================================" -ForegroundColor Magenta
    Write-Host ""
}

function Show-ProfileMenu {
    Write-Host "  QUICK LAUNCH PRESETS" -ForegroundColor Yellow
    Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
    foreach ($key in ($quickPresets.Keys | Sort-Object)) {
        Write-Host "  [$key] $($quickPresets[$key].Name)" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "  CUSTOM PROFILES" -ForegroundColor Yellow
    Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
    foreach ($key in ($profiles.Keys | Sort-Object)) {
        Write-Host "  [$key] $($profiles[$key].Name)" -ForegroundColor Cyan
    }
    Write-Host ""
}

function Show-DbMenu {
    Write-Host "  SELECT DATABASE" -ForegroundColor Yellow
    Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
    foreach ($key in ($dbProfiles.Keys | Sort-Object)) {
        Write-Host "  [$key] $($dbProfiles[$key].Name)" -ForegroundColor Cyan
    }
    Write-Host ""
}

# ============================================================
#  NAME HELPERS
# ============================================================
function Get-SafeName {
    param ([string]$Raw)
    $s = $Raw.Trim().ToLower()
    $s = $s -replace '[^a-z0-9]', ''
    return $s
}

function Get-DbName {
    param ([string]$SafeName)
    return "${SafeName}_db"
}

# ============================================================
#  SPRING BOOT VERSION PROBE
# ============================================================
function Get-BootVersion {
    Write-Host "  Probing Spring Boot version..." -ForegroundColor DarkGray
    $candidates = @("3.5.4","3.5.3","3.4.5","3.4.4","4.0.0","4.1.0")
    foreach ($v in $candidates) {
        try {
            $p = "type=maven-project&language=java&javaVersion=21&bootVersion=${v}&groupId=com.test&artifactId=test&name=test&packageName=com.test&dependencies=web"
            $u = "https://start.spring.io/starter.zip?${p}"
            $t = [System.IO.Path]::GetTempFileName() + '.zip'
            Invoke-WebRequest -Uri $u -OutFile $t -ErrorAction Stop -TimeoutSec 15
            $sz = (Get-Item $t).Length
            Remove-Item $t -Force -ErrorAction SilentlyContinue
            if ($sz -gt 5000) {
                Write-Host "  Spring Boot version: $v" -ForegroundColor DarkGreen
                return $v
            }
        }
        catch { }
    }
    try {
        $meta = Invoke-RestMethod -Uri "https://start.spring.io/metadata/client" -ErrorAction Stop
        $v    = $meta.bootVersion.default
        Write-Host "  Spring Boot version (API fallback): $v" -ForegroundColor Yellow
        return $v
    }
    catch {
        Write-Host "  WARNING: Could not probe version. Using 3.3.5 as fallback." -ForegroundColor Yellow
        return "3.3.5"
    }
}

# ============================================================
#  DATABASE CREATION
# ============================================================
function New-PostgresDatabase {
    param ([string]$DbName)

    Write-Host "  Creating PostgreSQL database: $DbName" -ForegroundColor Cyan

    $psqlExe = Get-Command psql -ErrorAction SilentlyContinue
    if (-not $psqlExe) {
        Write-Host "  WARNING: psql not found in PATH." -ForegroundColor Yellow
        Write-Host "  Run manually: CREATE DATABASE $DbName;" -ForegroundColor Yellow
        return
    }

    # Write SQL to C:\Temp — no spaces in path, no psql argument splitting
    $safeDir = "C:\Temp"
    if (-not (Test-Path $safeDir)) {
        New-Item -ItemType Directory -Path $safeDir -Force | Out-Null
    }
    $sqlFile = "$safeDir\create_db.sql"
    $utf8    = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($sqlFile, "CREATE DATABASE `"${DbName}`";`n", $utf8)

    # Set PGPASSWORD directly in current PS session env before spawning psql.
    # Use Start-Process WITHOUT RedirectStandard* so env IS inherited by child.
    # Capture output by writing to files in C:\Temp (no spaces).
    $env:PGPASSWORD = $PG_PASS

    $outFile = "$safeDir\psql_out.txt"
    $errFile = "$safeDir\psql_err.txt"

    $proc = Start-Process -FilePath $psqlExe.Source `
        -ArgumentList "-U", $PG_USER, "-h", "localhost", "-d", "postgres", "-f", $sqlFile `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $outFile `
        -RedirectStandardError  $errFile

    $env:PGPASSWORD = ""

    $outText = (Get-Content $outFile -ErrorAction SilentlyContinue) -join " "
    $errText = (Get-Content $errFile -ErrorAction SilentlyContinue) -join " "
    Remove-Item $sqlFile, $outFile, $errFile -Force -ErrorAction SilentlyContinue

    Write-Host "  [DEBUG] exit : $($proc.ExitCode)" -ForegroundColor DarkGray
    Write-Host "  [DEBUG] out  : $outText" -ForegroundColor DarkGray
    Write-Host "  [DEBUG] err  : $errText" -ForegroundColor DarkGray

    if ($outText -match "CREATE DATABASE") {
        Write-Host "  PostgreSQL database ready: $DbName" -ForegroundColor Green
    }
    elseif ($errText -match "already exists" -or $outText -match "already exists") {
        Write-Host "  Already exists, skipping: $DbName" -ForegroundColor DarkGreen
    }
    else {
        Write-Host "  WARNING: Could not auto-create database." -ForegroundColor Yellow
        Write-Host "  Run manually in psql: CREATE DATABASE $DbName;" -ForegroundColor Yellow
        if ($errText) { Write-Host "  Detail: $errText" -ForegroundColor DarkGray }
    }
}

function New-MySqlDatabase {
    param ([string]$DbName)

    $msg = "Creating MySQL database: $DbName"
    Write-Host "  $msg" -ForegroundColor Cyan

    $mysqlExe = Get-Command mysql -ErrorAction SilentlyContinue
    if (-not $mysqlExe) {
        Write-Host "  WARNING: mysql CLI not found in PATH. Create manually." -ForegroundColor Yellow
        return
    }

    $tmpOut = [System.IO.Path]::GetTempFileName()
    $tmpErr = [System.IO.Path]::GetTempFileName()

    $sqlCmd = "CREATE DATABASE IF NOT EXISTS ``${DbName}``;"

    $proc = Start-Process -FilePath "mysql" `
        -ArgumentList "-u", $MYSQL_USER, "-p${MYSQL_PASS}", "-e", $sqlCmd `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $tmpOut `
        -RedirectStandardError  $tmpErr

    $errText = (Get-Content $tmpErr -ErrorAction SilentlyContinue) -join " "
    Remove-Item $tmpOut, $tmpErr -Force -ErrorAction SilentlyContinue

    if ($proc.ExitCode -eq 0) {
        Write-Host "  MySQL database ready: $DbName" -ForegroundColor Green
    }
    else {
        Write-Host "  WARNING: Could not auto-create MySQL database." -ForegroundColor Yellow
        Write-Host "  Run manually: CREATE DATABASE IF NOT EXISTS ${DbName};" -ForegroundColor Yellow
        if ($errText) { Write-Host "  mysql error: $errText" -ForegroundColor DarkGray }
    }
}

# ============================================================
#  POM.XML
# ============================================================
function Build-PomXml {
    param (
        [string]$ProjectName,
        [string]$SafeName,
        [string]$BootVersion,
        [string]$ProfileDeps,
        [string]$DbDep
    )

    $seen    = @{}
    $allKeys = ($ProfileDeps -split ",") + ($DbDep -split ",") | Where-Object { $_ -ne "" }
    $depLines = [System.Collections.Generic.List[string]]::new()

    foreach ($d in $allKeys) {
        $d = $d.Trim()
        if ($d -eq "lombok" -or $d -eq "devtools") { continue }
        if ($seen.ContainsKey($d)) { continue }
        $seen[$d] = $true
        $block = Get-DepXml -Key $d
        if ($block.Count -gt 0) {
            if ($depLines.Count -gt 0) { $depLines.Add("") }
            foreach ($bl in $block) { $depLines.Add($bl) }
        }
    }

    $L = [System.Collections.Generic.List[string]]::new()
    $L.Add('<?xml version="1.0" encoding="UTF-8"?>')
    $L.Add('<project xmlns="http://maven.apache.org/POM/4.0.0"')
    $L.Add('         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"')
    $L.Add('         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">')
    $L.Add('    <modelVersion>4.0.0</modelVersion>')
    $L.Add('')
    $L.Add('    <parent>')
    $L.Add('        <groupId>org.springframework.boot</groupId>')
    $L.Add('        <artifactId>spring-boot-starter-parent</artifactId>')
    $L.Add("        <version>$BootVersion</version>")
    $L.Add('        <relativePath/>')
    $L.Add('    </parent>')
    $L.Add('')
    $L.Add('    <groupId>com.learn</groupId>')
    $L.Add("    <artifactId>$SafeName</artifactId>")
    $L.Add('    <version>0.0.1-SNAPSHOT</version>')
    $L.Add("    <name>$ProjectName</name>")
    $L.Add('')
    $L.Add('    <properties>')
    $L.Add("        <java.version>$JAVA_VERSION</java.version>")
    $L.Add("        <maven.compiler.source>$JAVA_VERSION</maven.compiler.source>")
    $L.Add("        <maven.compiler.target>$JAVA_VERSION</maven.compiler.target>")
    $L.Add("        <maven.compiler.release>$JAVA_VERSION</maven.compiler.release>")
    $L.Add("        <lombok.version>$LOMBOK_VERSION</lombok.version>")
    $L.Add("        <mapstruct.version>$MAPSTRUCT_VERSION</mapstruct.version>")
    $L.Add('    </properties>')
    $L.Add('')
    $L.Add('    <dependencies>')
    $L.Add('')
    foreach ($dl in $depLines) { $L.Add($dl) }
    $L.Add('')
    $L.Add('        <!-- Lombok -->')
    $L.Add('        <dependency>')
    $L.Add('            <groupId>org.projectlombok</groupId>')
    $L.Add('            <artifactId>lombok</artifactId>')
    $L.Add('            <version>${lombok.version}</version>')
    $L.Add('            <optional>true</optional>')
    $L.Add('        </dependency>')
    $L.Add('')
    $L.Add('        <!-- DevTools -->')
    $L.Add('        <dependency>')
    $L.Add('            <groupId>org.springframework.boot</groupId>')
    $L.Add('            <artifactId>spring-boot-devtools</artifactId>')
    $L.Add('            <scope>runtime</scope>')
    $L.Add('            <optional>true</optional>')
    $L.Add('        </dependency>')
    $L.Add('')
    $L.Add('        <!-- Test -->')
    $L.Add('        <dependency>')
    $L.Add('            <groupId>org.springframework.boot</groupId>')
    $L.Add('            <artifactId>spring-boot-starter-test</artifactId>')
    $L.Add('            <scope>test</scope>')
    $L.Add('        </dependency>')
    $L.Add('')
    $L.Add('    </dependencies>')
    $L.Add('')
    $L.Add('    <build>')
    $L.Add('        <plugins>')
    $L.Add('')
    $L.Add('            <plugin>')
    $L.Add('                <groupId>org.springframework.boot</groupId>')
    $L.Add('                <artifactId>spring-boot-maven-plugin</artifactId>')
    $L.Add('                <configuration>')
    $L.Add('                    <excludes>')
    $L.Add('                        <exclude>')
    $L.Add('                            <groupId>org.projectlombok</groupId>')
    $L.Add('                            <artifactId>lombok</artifactId>')
    $L.Add('                        </exclude>')
    $L.Add('                    </excludes>')
    $L.Add('                </configuration>')
    $L.Add('            </plugin>')
    $L.Add('')
    $L.Add('            <plugin>')
    $L.Add('                <groupId>org.apache.maven.plugins</groupId>')
    $L.Add('                <artifactId>maven-compiler-plugin</artifactId>')
    $L.Add('                <version>3.13.0</version>')
    $L.Add('                <configuration>')
    $L.Add("                    <source>$JAVA_VERSION</source>")
    $L.Add("                    <target>$JAVA_VERSION</target>")
    $L.Add("                    <release>$JAVA_VERSION</release>")
    $L.Add('                    <annotationProcessorPaths>')
    $L.Add('                        <path>')
    $L.Add('                            <groupId>org.projectlombok</groupId>')
    $L.Add('                            <artifactId>lombok</artifactId>')
    $L.Add("                            <version>$LOMBOK_VERSION</version>")
    $L.Add('                        </path>')
    $L.Add('                    </annotationProcessorPaths>')
    $L.Add('                </configuration>')
    $L.Add('            </plugin>')
    $L.Add('')
    $L.Add('        </plugins>')
    $L.Add('    </build>')
    $L.Add('')
    $L.Add('</project>')

    return $L.ToArray()
}

# ============================================================
#  MAIN APPLICATION CLASS
# ============================================================
function Build-MainClass {
    param ([string]$ProjectName, [string]$BasePackage)

    $className = "${ProjectName}Application"
    $L = [System.Collections.Generic.List[string]]::new()
    $L.Add("package ${BasePackage};")
    $L.Add("")
    $L.Add("import org.springframework.boot.SpringApplication;")
    $L.Add("import org.springframework.boot.autoconfigure.SpringBootApplication;")
    $L.Add("")
    $L.Add("@SpringBootApplication")
    $L.Add("public class ${className} {")
    $L.Add("")
    $L.Add("    public static void main(String[] args) {")
    $L.Add("        SpringApplication.run(${className}.class, args);")
    $L.Add("    }")
    $L.Add("")
    $L.Add("}")
    return $L.ToArray()
}

# ============================================================
#  SKELETON CLASS — package + imports, empty body
# ============================================================
function Build-SkeletonClass {
    param ([string]$BasePackage, [string]$PkgName)

    $L = [System.Collections.Generic.List[string]]::new()
    $L.Add("package ${BasePackage}.${PkgName};")
    $L.Add("")

    switch ($PkgName) {
        "controller" {
            $L.Add("import org.springframework.web.bind.annotation.*;")
            $L.Add("import org.springframework.http.ResponseEntity;")
        }
        "service" {
            $L.Add("import org.springframework.stereotype.Service;")
        }
        "repository" {
            $L.Add("import org.springframework.data.jpa.repository.JpaRepository;")
            $L.Add("import org.springframework.stereotype.Repository;")
        }
        "entity" {
            $L.Add("import jakarta.persistence.*;")
            $L.Add("import lombok.*;")
        }
        "dto" {
            $L.Add("import lombok.*;")
        }
        "mapper" {
            $L.Add("import org.mapstruct.*;")
        }
        "config" {
            $L.Add("import org.springframework.context.annotation.*;")
            $L.Add("import org.springframework.stereotype.Component;")
        }
        "exception" {
            $L.Add("import org.springframework.web.bind.annotation.*;")
            $L.Add("import org.springframework.http.ResponseEntity;")
        }
        "filter" {
            $L.Add("import jakarta.servlet.*;")
            $L.Add("import jakarta.servlet.http.*;")
            $L.Add("import java.io.IOException;")
        }
        "aspect" {
            $L.Add("import org.aspectj.lang.annotation.*;")
            $L.Add("import org.aspectj.lang.*;")
            $L.Add("import org.springframework.stereotype.Component;")
        }
        "annotation" {
            $L.Add("import java.lang.annotation.*;")
        }
        "producer" {
            $L.Add("import org.springframework.kafka.core.KafkaTemplate;")
            $L.Add("import org.springframework.stereotype.Service;")
        }
        "consumer" {
            $L.Add("import org.springframework.kafka.annotation.KafkaListener;")
            $L.Add("import org.springframework.stereotype.Component;")
        }
        "model" {
            $L.Add("import lombok.*;")
        }
        "beans" {
            $L.Add("import org.springframework.context.annotation.*;")
        }
        "events" {
            $L.Add("import org.springframework.context.event.*;")
            $L.Add("import org.springframework.stereotype.Component;")
        }
        "job" {
            $L.Add("import org.springframework.batch.core.*;")
            $L.Add("import org.springframework.stereotype.Component;")
        }
        "step" {
            $L.Add("import org.springframework.batch.core.*;")
            $L.Add("import org.springframework.stereotype.Component;")
        }
        "reader" {
            $L.Add("import org.springframework.batch.item.*;")
            $L.Add("import org.springframework.stereotype.Component;")
        }
        "processor" {
            $L.Add("import org.springframework.batch.item.*;")
            $L.Add("import org.springframework.stereotype.Component;")
        }
        "writer" {
            $L.Add("import org.springframework.batch.item.*;")
            $L.Add("import org.springframework.stereotype.Component;")
        }
    }

    $L.Add("")
    $first  = $PkgName.Substring(0, 1).ToUpper()
    $rest   = $PkgName.Substring(1)
    $cName  = "${first}${rest}Sample"
    $L.Add("public class ${cName} {")
    $L.Add("")
    $L.Add("}")

    return $L.ToArray()
}

# ============================================================
#  APPLICATION.PROPERTIES
# ============================================================
function Build-AppProperties {
    param (
        [string]$ProjectName,
        [string]$SafeName,
        [string]$DbKey,
        [string]$DbName,
        $SelectedDb
    )

    $L = [System.Collections.Generic.List[string]]::new()
    $L.Add("# ============================================================")
    $L.Add("#  $ProjectName")
    $L.Add("# ============================================================")
    $L.Add("")
    $L.Add("# SERVER")
    $L.Add("server.port=8080")
    $L.Add("spring.application.name=${SafeName}")
    $L.Add("")

    if ($DbKey -eq "1") {
        $jdbcUrl = "jdbc:postgresql://localhost:5432/${DbName}"
        $L.Add("# DATABASE - PostgreSQL")
        $L.Add("spring.datasource.url=${jdbcUrl}")
        $L.Add("spring.datasource.username=${PG_USER}")
        $L.Add("spring.datasource.password=${PG_PASS}")
        $L.Add("spring.datasource.driver-class-name=$($SelectedDb.Driver)")
        $L.Add("")
        $L.Add("# JPA / HIBERNATE")
        $L.Add("spring.jpa.hibernate.ddl-auto=update")
        $L.Add("spring.jpa.show-sql=true")
        $L.Add("spring.jpa.properties.hibernate.format_sql=true")
        $L.Add("spring.jpa.database-platform=$($SelectedDb.Dialect)")
    }
    elseif ($DbKey -eq "2") {
        $mysqlBase   = "jdbc:mysql://localhost:3306/${DbName}"
        $mysqlParams = "useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true&createDatabaseIfNotExist=true"
        $jdbcUrl     = "${mysqlBase}?${mysqlParams}"
        $L.Add("# DATABASE - MySQL")
        $L.Add("spring.datasource.url=${jdbcUrl}")
        $L.Add("spring.datasource.username=${MYSQL_USER}")
        $L.Add("spring.datasource.password=${MYSQL_PASS}")
        $L.Add("spring.datasource.driver-class-name=$($SelectedDb.Driver)")
        $L.Add("")
        $L.Add("# JPA / HIBERNATE")
        $L.Add("spring.jpa.hibernate.ddl-auto=update")
        $L.Add("spring.jpa.show-sql=true")
        $L.Add("spring.jpa.properties.hibernate.format_sql=true")
        $L.Add("spring.jpa.database-platform=$($SelectedDb.Dialect)")
    }
    elseif ($DbKey -eq "3") {
        $L.Add("# DATABASE - MongoDB")
        $L.Add("spring.data.mongodb.host=localhost")
        $L.Add("spring.data.mongodb.port=27017")
        $L.Add("spring.data.mongodb.database=${DbName}")
    }
    elseif ($DbKey -eq "4") {
        $L.Add("# DATABASE - H2 In-Memory")
        $L.Add("spring.datasource.url=jdbc:h2:mem:${DbName}")
        $L.Add("spring.datasource.driver-class-name=$($SelectedDb.Driver)")
        $L.Add("spring.datasource.username=sa")
        $L.Add("spring.datasource.password=")
        $L.Add("spring.h2.console.enabled=true")
        $L.Add("spring.h2.console.path=/h2-console")
        $L.Add("")
        $L.Add("# JPA / HIBERNATE")
        $L.Add("spring.jpa.hibernate.ddl-auto=update")
        $L.Add("spring.jpa.show-sql=true")
        $L.Add("spring.jpa.properties.hibernate.format_sql=true")
        $L.Add("spring.jpa.database-platform=$($SelectedDb.Dialect)")
    }

    $L.Add("")
    $L.Add("# LOGGING")
    $L.Add("logging.level.root=INFO")
    $L.Add("logging.level.com.learn=DEBUG")

    return $L.ToArray()
}

# ============================================================
#  GITIGNORE
# ============================================================
function Build-Gitignore {
    return @(
        "target/"
        ".idea/"
        "*.iml"
        "*.class"
        "*.jar"
        "*.war"
        ".DS_Store"
        "*.log"
        ".mvn/"
        "mvnw"
        "mvnw.cmd"
    )
}

# ============================================================
#  INTELLIJ OPENER — dynamic search, no hardcoded version
# ============================================================
function Open-InIntelliJ {
    param ([string]$FolderPath)

    $roots = @("C:\Program Files\JetBrains","C:\Program Files (x86)\JetBrains")
    $exe   = $null

    foreach ($root in $roots) {
        if (Test-Path $root) {
            $exe = Get-ChildItem -Path $root -Recurse -Filter "idea64.exe" -ErrorAction SilentlyContinue |
                   Sort-Object LastWriteTime -Descending |
                   Select-Object -First 1
            if ($exe) { break }
        }
    }

    if ($exe) {
        Write-Host "  Opening: $($exe.FullName)" -ForegroundColor DarkGray
        Start-Process -FilePath $exe.FullName -ArgumentList "`"$FolderPath`""
    }
    else {
        try   { Start-Process "idea64.exe" -ArgumentList "`"$FolderPath`"" }
        catch {
            Write-Host "  Could not open IntelliJ automatically." -ForegroundColor Yellow
            Write-Host "  Open manually: $FolderPath" -ForegroundColor Yellow
        }
    }
}

# ============================================================
#  VALIDATION
# ============================================================
function Assert-ProjectName {
    param ([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-Host "  ERROR: Project name cannot be empty." -ForegroundColor Red
        exit 1
    }
    $safe = Get-SafeName -Raw $Name
    if ($safe.Length -lt 2) {
        Write-Host "  ERROR: Name too short or contains only special characters." -ForegroundColor Red
        exit 1
    }
    if ($safe -match '^\d') {
        Write-Host "  ERROR: Name cannot start with a digit (invalid Java package)." -ForegroundColor Red
        exit 1
    }
    if ($safe.Length -gt 40) {
        Write-Host "  WARNING: Name is long. Windows path limit may be hit." -ForegroundColor Yellow
    }
}

# ============================================================
#  MAIN
# ============================================================
Show-Header

# --- Project name ---
$projectName = Read-Host "  Enter project name"
Assert-ProjectName -Name $projectName

$safeName    = Get-SafeName -Raw $projectName
$basePackage = "com.learn.${safeName}"
$dbName      = Get-DbName  -SafeName $safeName

Write-Host ""
Write-Host "  Safe name : $safeName"    -ForegroundColor DarkGray
Write-Host "  Package   : $basePackage" -ForegroundColor DarkGray
Write-Host "  DB name   : $dbName"      -ForegroundColor DarkGray
Write-Host ""

# --- Profile / preset selection ---
Show-ProfileMenu
$profileInput = (Read-Host "  Choose [1-9] or [Q1-Q8]").ToUpper().Trim()

$profileKey = $null
$dbKey      = $null

if ($quickPresets.ContainsKey($profileInput)) {
    $preset     = $quickPresets[$profileInput]
    $profileKey = $preset.ProfileKey
    $dbKey      = $preset.DbKey
    Write-Host "  Preset selected: $($preset.Name)" -ForegroundColor Green
}
elseif ($profiles.ContainsKey($profileInput)) {
    $profileKey = $profileInput
    Write-Host ""
    Show-DbMenu
    $dbKey = (Read-Host "  Choose database [1-5]").Trim()
    if (-not $dbProfiles.ContainsKey($dbKey)) {
        Write-Host "  ERROR: Invalid database choice." -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "  ERROR: Invalid selection." -ForegroundColor Red
    exit 1
}

$selectedProfile = $profiles[$profileKey]
$selectedDb      = $dbProfiles[$dbKey]

# --- Probe Spring Boot version ---
Write-Host ""
$bootVersion = Get-BootVersion

# --- Create database ---
Write-Host ""
if     ($selectedDb.Type -eq "pg")    { New-PostgresDatabase -DbName $dbName }
elseif ($selectedDb.Type -eq "mysql") { New-MySqlDatabase    -DbName $dbName }
elseif ($selectedDb.Type -eq "h2")    { Write-Host "  H2 in-memory: no pre-creation needed." -ForegroundColor DarkGray }
elseif ($selectedDb.Type -eq "mongo") { Write-Host "  MongoDB: no pre-creation needed." -ForegroundColor DarkGray }
elseif ($selectedDb.Type -eq "none")  { Write-Host "  No database selected." -ForegroundColor DarkGray }

# --- Build paths ---
$baseOutputDir = $PWD.Path
$projectDir    = Join-Path $baseOutputDir $safeName
Write-Host "  [DEBUG] Output dir: $baseOutputDir" -ForegroundColor DarkGray
$packagePath   = $basePackage -replace '\.', '\'
$mainJavaPath  = Join-Path $projectDir "src\main\java\$packagePath"
$testJavaPath  = Join-Path $projectDir "src\test\java\$packagePath"
$resourcesPath = Join-Path $projectDir "src\main\resources"

# --- Conflict check ---
if (Test-Path $projectDir) {
    Write-Host ""
    Write-Host "  WARNING: Folder already exists: $projectDir" -ForegroundColor Yellow
    $choice = (Read-Host "  Overwrite? [Y/N]").ToUpper()
    if ($choice -ne "Y") { Write-Host "  Aborted." -ForegroundColor Red; exit 0 }
    Remove-Item $projectDir -Recurse -Force
}

# --- Create structure ---
Write-Host ""
Write-Host "  Creating project structure..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $mainJavaPath  -Force | Out-Null
New-Item -ItemType Directory -Path $testJavaPath  -Force | Out-Null
New-Item -ItemType Directory -Path $resourcesPath -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $resourcesPath "static")    -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $resourcesPath "templates") -Force | Out-Null

foreach ($pkg in $selectedProfile.Packages) {
    $pkgPath = Join-Path $mainJavaPath $pkg
    New-Item -ItemType Directory -Path $pkgPath -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $pkgPath ".gitkeep") -Force | Out-Null
    Write-Host "    + $pkg" -ForegroundColor DarkGreen
}

# --- Write files ---
Write-Host ""
Write-Host "  Writing pom.xml ..." -ForegroundColor Cyan
Write-TextFile -Path (Join-Path $projectDir "pom.xml") -Lines (
    Build-PomXml -ProjectName $projectName -SafeName $safeName -BootVersion $bootVersion -ProfileDeps $selectedProfile.Deps -DbDep $selectedDb.Dep
)

Write-Host "  Writing ${projectName}Application.java ..." -ForegroundColor Cyan
Write-TextFile -Path (Join-Path $mainJavaPath "${projectName}Application.java") -Lines (
    Build-MainClass -ProjectName $projectName -BasePackage $basePackage
)

Write-Host "  Writing application.properties ..." -ForegroundColor Cyan
Write-TextFile -Path (Join-Path $resourcesPath "application.properties") -Lines (
    Build-AppProperties -ProjectName $projectName -SafeName $safeName -DbKey $dbKey -DbName $dbName -SelectedDb $selectedDb
)

Write-Host "  Writing .gitignore ..." -ForegroundColor Cyan
Write-TextFile -Path (Join-Path $projectDir ".gitignore") -Lines (Build-Gitignore)

# --- Open IntelliJ ---
Write-Host ""
Write-Host "  Opening IntelliJ IDEA ..." -ForegroundColor Cyan
Open-InIntelliJ -FolderPath $projectDir

# --- Summary ---
Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host "   PROJECT READY" -ForegroundColor Green
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Project     : $projectName"             -ForegroundColor White
Write-Host "  Safe name   : $safeName"                -ForegroundColor White
Write-Host "  Profile     : $($selectedProfile.Name)" -ForegroundColor White
Write-Host "  Database    : $($selectedDb.Name)"      -ForegroundColor White
if ($dbKey -ne "5") {
    Write-Host "  DB Name     : $dbName"              -ForegroundColor White
}
Write-Host "  Package     : $basePackage"             -ForegroundColor White
Write-Host "  Java        : $JAVA_VERSION"            -ForegroundColor White
Write-Host "  Spring Boot : $bootVersion"             -ForegroundColor White
Write-Host "  Packages    : $($selectedProfile.Packages -join ', ')" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. Maven -> Reload Project"                        -ForegroundColor White
Write-Host "  2. File -> Project Structure -> SDK -> Java 21"    -ForegroundColor White
Write-Host "  3. Run -> Edit Configurations -> JRE -> Java 21"   -ForegroundColor White
Write-Host "  4. Hit Run!" -ForegroundColor White
Write-Host ""