#Requires -RunAsAdministrator
# 

$appName="Hyper-V-Manager Web Edition (Alpha) 2025"
# This is a lightweigh web application that can be used to manage the Services and 
# Virtual Machines running the local server. This web application has been implemented
# as a single page web application that can be run as a app or service.

$colors = [enum]::GetValues([System.ConsoleColor])


$banner = @'
  _   _                         __     __  
 | | | |_   _ _ __   ___ _ __   \ \   / /  
 | |_| | | | | '_ \ / _ \ '__|___\ \ / /   
 |  _  | |_| | |_) |  __/ | |_____\ V /    
 |_| |_|\__, | .__/ \___|_|        \_/     
 |  \/  |___/|_| __   __ _  __ _  ___ _ __ 
 | |\/| |/ _` | '_ \ / _` |/ _` |/ _ \ '__|
 | |  | | (_| | | | | (_| | (_| |  __/ |   
 |_|  |_|\__,_|_| |_|\__,_|\__, |\___|_|   
                           |___/         
 ------------------------------------------
 
'@

$lines = $banner -split "`n"

for ($i = 0; $i -lt $lines.Length; $i++) {
    $color = $colors[($colors.Length-1 - $i) % $colors.Length]
    Write-Host $lines[$i] -ForegroundColor $color
}
Write-host "$appName `n`n" -ForegroundColor White


#
# Start Runtime Variables
#
$redirectToJobs=$false 		# Set this to true to redirect to /job/list when a export/archive is submitted
$ClobberZips=$false # Set this to $true to overwrite
$BasePath="C:\temp"

#
# Verify and create local folders
#

Write-Host "Base configuration:" -ForegroundColor Green
If(Test-Path $BasePath -PathType Container) {
    Write-Host "`tBase Path set to: [$BasePath].." -ForegroundColor Green
} else {
    Write-Host "`tCreating Base Path: [$BasePath].." -ForegroundColor Yellow
    New-Item -Path "$BasePath" -ItemType "directory" -ErrorAction SilentlyContinue | Out-Null
}

$ExportPath="$BasePath\Export\"
If(Test-Path $ExportPath -PathType Container) {
    Write-Host "`tExport Path set to: [$ExportPath].." -ForegroundColor Green
} else {
    Write-Host "`tCreating Export Path: [$ExportPath].." -ForegroundColor Yellow
    New-Item -Path "$ExportPath" -ItemType "directory" -ErrorAction SilentlyContinue | Out-null
}

$ArchivePath="$BasePath\Archive\"
If(Test-Path $ArchivePath -PathType Container) {
    Write-Host "`tArchive Path set to: [$ArchivePath].." -ForegroundColor Green
} else {
    Write-Host "`tCreating Archive Path: [$ArchivePath].." -ForegroundColor Yellow
    New-Item -Path "$ArchivePath" -ItemType "directory" -ErrorAction SilentlyContinue | Out-null
}

#
# End Runtime Variables
#

Add-Type -AssemblyName System.Web
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Import necessary functions from Advapi32.dll
Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;

    public class Advapi32 {
        [DllImport("advapi32.dll", SetLastError=true)]
        public static extern bool LogonUser(
            string lpszUsername,
            string lpszDomain,
            string lpszPassword,
            int dwLogonType,
            int dwLogonProvider,
            out IntPtr phToken
        );
    }
"@
#
# Setup a Secure Connection using https
#
# Find the "Hyper-V-Manager" Certificate Thumbprint
$Thumbprint = (Get-ChildItem -Path Cert:\LocalMachine\Root -Recurse | Where-Object {$_.FriendlyName -match "Hyper-V-Manager"}).Thumbprint;
if($Thumbprint.Length -gt 0) {
    Write-Host "`tLoading certificate thumbprint: [$Thumbprint].." -ForegroundColor Green
} else {
    $computername = $($ENV:COMPUTERNAME).ToLower()
    $newCert = New-SelfSignedCertificate -DnsName "$computername","localhost" -CertStoreLocation cert:\LocalMachine\My -NotAfter (Get-Date).AddYears(10) -FriendlyName "Hyper-V-Manager"
    $thumbprint=$newCert.Thumbprint
    Write-Host "`tGenerating new certificate thumbprint: [$Thumbprint].." -ForegroundColor Green
    Move-Item $newCert.pspath Cert:\LocalMachine\Root\

}
$guid = [guid]::NewGuid().toString()
Remove-NetIPHttpsCertBinding
Add-NetIPHttpsCertBinding -IpPort "0.0.0.0:443" -ApplicationId "{$guid}" -CertificateHash "$Thumbprint" -CertificateStoreName "Root" -NullEncryption $false

# Define the URL and port for the server
$listener = New-Object System.Net.HttpListener
$prefixes = @("http://*:80/", "https://*:443/")

ForEach ( $prefix in $prefixes)
{
	Write-host "Listening on: $prefix" -ForegroundColor Green
	$listener.Prefixes.Add($prefix)
}

# Enable Windows Authentication
$listener.AuthenticationSchemes = [System.Net.AuthenticationSchemes]::IntegratedWindowsAuthentication

#
# Start the Web server
#
try {
	$listener.Start()
	$listener.Prefixes
} 
catch {
	
	Write-Host "`nWarning: Check if '$appName' is already running on this system.`n" -ForegroundColor Yellow
	Write-Error "Error: Unable to start web server. Please check ports are free or change port configuration..`nConfigured Prefixes: $prefixes"
	pause
	Exit(1)
}

Write-Host "Server is running. Press <CTRL-C> to stop." -NoNewline

# Define the function to handle incoming requests
function Handle-Request {
    param($context)

    $request = $context.Request
    $response = $context.Response
    $url = $request.Url
    $path = $url.LocalPath

#
# General Icons
#
$HomeIcon=@"
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" style="fill: rgba(252, 252, 252, 1);transform: ;msFilter:;"><path d="M3 13h1v7c0 1.103.897 2 2 2h12c1.103 0 2-.897 2-2v-7h1a1 1 0 0 0 .707-1.707l-9-9a.999.999 0 0 0-1.414 0l-9 9A1 1 0 0 0 3 13zm7 7v-5h4v5h-4zm2-15.586 6 6V15l.001 5H16v-5c0-1.103-.897-2-2-2h-4c-1.103 0-2 .897-2 2v5H6v-9.586l6-6z"></path></svg>
"@
$VirtualMachineIcon=@"
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" style="fill: rgba(252, 252, 252, 1);transform: ;msFilter:;"><path d="M20 17.722c.595-.347 1-.985 1-1.722V5c0-1.103-.897-2-2-2H5c-1.103 0-2 .897-2 2v11c0 .736.405 1.375 1 1.722V18H2v2h20v-2h-2v-.278zM5 16V5h14l.002 11H5z"></path></svg>
"@
$JobIcon=@"
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" style="fill: rgba(252, 252, 252, 1);transform: ;msFilter:;"><path d="m20.145 8.27 1.563-1.563-1.414-1.414L18.586 7c-1.05-.63-2.274-1-3.586-1-3.859 0-7 3.14-7 7s3.141 7 7 7 7-3.14 7-7a6.966 6.966 0 0 0-1.855-4.73zM15 18c-2.757 0-5-2.243-5-5s2.243-5 5-5 5 2.243 5 5-2.243 5-5 5z"></path><path d="M14 10h2v4h-2zm-1-7h4v2h-4zM3 8h4v2H3zm0 8h4v2H3zm-1-4h3.99v2H2z"></path></svg>
"@

#
# Web Page Icon
#
$favicon="AAABAAMAEBAAAAEAIABoBAAANgAAACAgAAABACAAKBEAAJ4EAAAwMAAAAQAgAGgmAADGFQAAKAAAABAAAAAgAAAAAQAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPTt3P/z6c3/8+nN//PozP/z6Mz/8+nN//Ppz//07+P/9fX1//X19f/19fX/9fX1//X19f/w7Or/5dfT/+bZ1f/uxl3/66oB/+uqAf/rqgH/7b5E/+3fyP/YvrT/zKmg/8GUiP/WvLX/qmlX/55UP/+TPyj/jTMa/40zGv+0fG3/7sZd/+y0I//y4bP/8uGz//Poy//Tta3/jTMa/40zGv+NMxr/wJSH/40zGv+NMxr/jTMa/40zGv+NMxr/s3ts/+7GXf/rrg//7sNS/+/DU//w1Ij/07Wt/40zGv+NMxr/jTMa/8CTh/+NMxr/jTMa/40zGv+NMxr/jTMa/7N8bP/txV3/668S/+/IYv/ux2H/8NiW/+DOyf+4g3T/uIN0/7eCdP/WvLT/t4Jz/7eCc/+3gnP/t4Jz/7eCc//Pr6b/7sZd/+uqAf/rqgH/66oB/+7FWv/OraT/jTMa/40zGv+NMxr/v5KF/40zGv+NMxr/jTMa/40zGv+NMxr/tHxt/+7GXf/rqgH/66oB/+uqAf/uxlr/zq2k/40zGv+NMxr/jTMa/7+RhP+NMxr/jTMa/40zGv+NMxr/jTMa/7N7bP/uxl3/66oB/+uqAf/rqgH/78Za/+XY1P/Dl4v/uIR1/61vXv/MqZ//l0Yw/441Hf+NMxr/jTMa/40zGv+zfGz/7sVd/+uqAf/rqgH/66oB/+urBP/ssx3/7bs4/+7DU//vzG//8NeW//X19f/08/P/6+Lg/+DOyf/VurP/3MfB/+7FXf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+yzHf/19fX/9fX1//X19f/19fX/9fX1//X19f/vxl3/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/ssx7/9fX1//T09P/09PT/9fX1//X19f/09PT/7sZd/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/7LMd//X19f/09PT/9fX1//X19f/19fX/9fX1/+3FXP/rrxP/78ln/+7JZv/uyWb/78ln/+/JZv/uyWb/7bky/+yzHf/19fX/9fX1//X19f/19fX/9fX1//X19f/uxV3/664N/+3ASf/uwEn/7sBJ/+3ASf/uwEn/7sBJ/+y0I//ssx3/9fX1//X19f/19fX/9fX1//X19f/19fX/78dg/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/7LMf//X19f/19fX/9fX1//X19f/19fX/9PT0//Pr1f/w1Y7/8NSM//DUjP/w1Iz/8NSM//DUjP/w1Iz/8NSM//Ljuv/19fX/9PT0//T09P/19fX/9fX1//X19f8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKAAAACAAAABAAAAAAQAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPT09P/19fX/9vb2//X19f/19fX/9fX1//X19f/19fX/9fX1//X19f/19fX/9fX1//X19f/29vb/9fX1//T09P/29vb/9fX1//T09P/29vb/9fX1//T09P/29vb/9PT0//T09P/29vb/9PT0//X19f/29vb/9PT0//X19f/29vb/9O/j//Ldpf/y3aX/8duj//LcpP/y3aX/8duj//Ldpf/y3aX/8duj//Ldpf/y3KT/8duj//Lfrf/z5sX/9O7f//b29v/19fX/9fX1//b29v/19fX/9fX1//b29v/19fX/9fX1//b29v/x7ez/5dnV/9vFv//Pr6X/xZuQ/+jd2f/x4bn/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/tx2X/8+Ct//Pnx//z7uH/9vX0//X19f/09PT/9vb2//Dr6v/m29f/8e7t/8ypn//Clon/tX5v/6tsWv+gVkL/lEEp/40zGv+NMxr/jTMa/40zGv+NMxr/28bA//Hiuf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB//Hdqf/19fX/2MC5/8SYi/+0fm//qmlX/59UQP+SPib/jTMa/5pMNv/n3dr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv/axb//8uO6/+uqAf/rqgH/7Lkz//DRgv/w0oL/7tCB//DSgv/w0oL/9OzW//X19f+xdmb/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/mkw2/+bc2f+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/9nEvv/y47r/66oB/+uqAf/uxFf/9PDk//Pw5P/18eX/9PDk//Tw5P/29PH/9fX1/7F2Zf+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+ZSzX/5tzZ/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/2cS+//Ljuv/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB//Lcof/19fX/sXZm/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/5lLNf/m3Nn/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv/ZxL7/8eK5/+uqAf/rqgH/7bs6//LdpP/x3KT/9N6m//LcpP/x3KT/9O3Z//X19f+xdWX/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/mUkz/+fd2v+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/9rFv//w4bj/66oB/+uqAf/tvkT/8+XC//Tmw//x5MD/8+bC//Pmwv/z7+P/9fX1/8Wek/+wdGP/rXFg/65yYf+wdGP/rXFg/65yYv+2gHH/7ebj/61uXP+tbl3/q2xb/61uXf+tbl3/q2xb/61uXf+tblz/q2xb/61uXf+sbVz/5NXR//Dhuf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB//Hgsf/29vb/0LCn/8GThv/BlIf/wZSH/8GThv/BlIf/wZOH/8eglf/u6ef/wZaK/8GWiv/Cl4v/wZaK/8GWiv/Cl4v/wZaK/8GWiv/Cl4v/wZaK/8GXi//r4+D/8OG4/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/8eG0//X19f+oZVP/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/mUs2/+bY1P+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/9vGwP/x4rn/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/y4bT/9fX1/6hmU/+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+aTDb/5djT/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/2sW///Ljuv/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB//LitP/19fX/qGZU/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/5pMNv/k1tL/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv/ZxL7/8uO6/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/8uK0//X19f+oZlT/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/mkw2/+TX0/+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/9nEvv/y47r/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/z4rX/9fX1/7aAcv+WRC3/jTQb/40zGv+NMxr/jTMa/40zGv+aTDb/5NfT/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/2cS+//Liuv/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB//Lhs//19fX/9fX1//X19f/z8fD/6d7b/9/Mx//Sta3/yaOY/8eek//r4+H/p2NR/51RO/+SPSX/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv/axb7/8eG5/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/664N/+y3K//uwEb/7cZg//DRfv/x2Zj/8N+y//Xr0P/08en/9PT0//b29v/19fX/9fX1//X19f/w7Ov/5tnV/9vFv//Rsqn/xp6T/7qJe/+yd2f/pmJP/+LRzP/x4bn/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+qqAf/rrxL/7cVc//X19f/19fX/9vb2//X19f/19fX/9vb2//X19f/19fX/9vb2//T09P/19fX/9fX1//Dhuf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/suzr/9fX1//X19f/29vb/9fX1//X19f/29vb/9fX1//X19f/29vb/9fX1//X19f/29vb/8eG5/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+28Ov/19fX/9fX1//X19f/19fX/9fX1//X19f/19fX/9fX1//b29v/19fX/9fX1//X19f/z47r/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/7bw7//X19f/29vb/9PT0//X19f/19fX/9PT0//b29v/19fX/9fX1//b29v/19fX/9PT0//Ljuv/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/tvDv/9fX1//X19f/09PT/9fX1//X19f/09PT/9fX1//X19f/19fX/9fX1//X19f/09PT/8uO6/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+28Ov/19fX/9fX1//T09P/19fX/9fX1//T09P/19fX/9fX1//X19f/19fX/9fX1//T09P/y47r/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/7bw6//X19f/19fX/9PT0//X19f/29vb/9PT0//X19f/19fX/9fX1//b29v/19fX/9fX1//DhuP/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/suzr/9fX1//X19f/29vb/9fX1//X19f/29vb/9fX1//X19f/29vb/9PT0//X19f/29vb/8OG4/+uqAf/rqgH/7cBI//PozP/06c3/8efK//Ppzf/z6c3/8efK//Tpzf/z6Mz/8efL//Tpzf/z6Mz/8efK//PmxP/qqgH/66oB/+28Ov/19fX/9PT0//b29v/19fX/9fX1//b29v/09PT/9fX1//b29v/09PT/9fX1//b29v/w4bj/66oB/+uqAf/tuTP/8NaS//DWkv/x1pL/8NaS//DWkv/x1pL/8NaS//DWkv/x15L/8NaS//DWkv/x1pL/79SL/+uqAf/rqgH/7Ls6//X19f/19fX/9vb2//X19f/19fX/9vb2//X19f/19fX/9vb2//X19f/19fX/9fX1//Hhuf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/tvDr/9fX1//X19f/19fX/9fX1//X19f/19fX/9fX1//X19f/29vb/9fX1//X19f/29vb/8uO6/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+28Ov/19fX/9vb2//T09P/19fX/9fX1//T09P/29vb/9fX1//X19f/29vb/9fX1//T09P/z58X/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/7b5B//X19f/29vb/9fX1//X19f/19fX/9fX1//b29v/19fX/9fX1//b29v/19fX/9PT0//X19P/uzHT/7bcr/+uzIv/rtCP/67Qj/+uzIv/rtCP/67Qj/+uzIv/rtCP/67Qj/+uzIv/rtCP/67Mi/+qzIv/rtCP/67Qj/+2+QP/x47//9fX1//X19f/09PT/9fX1//X19f/09PT/9fX1//X19f/19fX/9fX1//X19f/09PT/9vb2//X19f/09PT/9vb2//X19f/19fX/9fX1//X19f/19fX/9fX1//X19f/19fX/9vb2//T09P/19fX/9vb2//X19f/19fX/9vb2//X19f/19fX/9vb2//T09P/19fX/9fX1//T09P/29vb/9fX1//X19f/29vb/9fX1//X19f8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKAAAADAAAABgAAAAAQAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPHx8f/39/f/8/Pz//X19f/29vb/9PT0//j4+P/z8/P/+Pj4//Pz8//39/f/9PT0//T09P/39/f/8/Pz//j4+P/z8/P/+Pj4//T09P/29vb/9fX1//Pz8//39/f/8fHx//n5+f/z8/P/+Pj4//X19f/19fX/9/f3//Ly8v/4+Pj/8vLy//j4+P/09PT/9vb2//b29v/09PT/+Pj4//Ly8v/4+Pj/8vLy//f39//19fX/9fX1//j4+P/z8/P/+fn5//b29v/09PT/9vb2//X19f/19fX/9vb2//T09P/29vb/9PT0//b29v/19fX/9vb2//b29v/19fX/9vb2//T09P/29vb/9PT0//b29v/19fX/9fX1//b29v/09PT/9vb2//T09P/29vb/9PT0//X19f/19fX/9fX1//b29v/09PT/9vb2//X19f/29vb/9fX1//X19f/29vb/9fX1//b29v/09PT/9vb2//X19f/19fX/9fX1//T09P/19PT/9PT0//Px6v/y2Zf/7stt//DMb//wzG//78tu//HNcP/uym3/8c1w/+7Lbf/wzG//78tu/+/Lbv/wzG//7stt//HOcP/uy23/8c1w/+/Lbv/vzHH/79KC//Danf/y47n/8+zZ//f39//09PT/9vb2//X19f/19fX/9vb2//T09P/29vb/9PT0//b29v/19fX/9vb2//b29v/19fX/9/b2//Ht7P/n2tb/1r63/82qoP/AkoX/s3tr/6hmU/+0fm//7+nn//bx4//tvUD/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rrQ7/7MFP//HQdv/w1pL/8t+w//Pqzv/08en/9fX1//f39//09PT/9/f3//Pz8//29fX/8e/v//Ds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Gv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+nZVP/8uro//jz5v/tvkD/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/uvTv/9/Hi//Ly8v/eycP/lkQu/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/5E8JP/Nq6L/18G6/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+lY1D/6OHf//Pu4P/svD//66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/tvDr/8+7e//b29v/cxsH/lkQt/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/5E7I//OraT/28S+/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+mZFL/7ebk//Tv4f/svUD/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/tvDr/9O/f//X19f/cx8H/lkQt/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/5E7I//NraP/2sS9/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+mZFH/7OXj//Pu4P/svD//66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/tvDr/9O7f//b29v/dysT/m045/5E6Iv+ONR3/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/5E7I//OraT/28S+/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+nZFL/7ubk//Pu4P/svD//66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/tuzr/8+3e//b29v/t5+b/2b63/8qnnf/FnJD/vo6B/7V/cP+xdWT/p2VT/6JaRv+aSzb/kz4n/5E8Jf/OraT/28W+/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+mZFH/7ebk//n05//tvkH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/uvDn/9/Hi//Hx8f/4+Pj/8fHx//f39//19fX/9PPy//Xy8v/s5+b/8uvp/+Xc2f/s4N3/4dTQ/+PTzv/t5eP/6eLg/72Lff+ucWH/pWBN/5hJM/+POB//jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+NMxr/jTMa/40zGv+lYlD/5+De//Dr3f/ruz7/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqwP/7LMg/+29QP/txVz/8dJ9/+/Ymf/z47n/8+nM//Do0f/38N7/8Ovc//n16//y8Or/+Pf1//X19f/09PT/9/f3//Lx8v/4+Pj/8vLy//j4+P/y8fD/7OPg/+DNyP/Sta3/yaKY/7qJfP+vdGT/pF5L/5xRPP+bTTf/mEgy/5ZDLf+ucF//8evp//Xw4v/svUD/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/6qwJ/+uxGf/tuCz/7b0+/+7CUP/vyWP/7sx0//HUiP/x2Zr/8efL//b29v/19fX/9vb2//T09P/19fX/9fX1//X19f/19fX/9PT0//b29v/19fX/9vb2//Hu7f/r4t//49PP/9vGv//fzMf/8vDv//Tu4f/svD//66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+urBf/rrQv/7sts//X19f/19fX/9fX1//X19f/19fX/9fX1//X19f/19fX/9fX1//X19f/19fX/9fX1//X19f/19fX/9fX1//X19f/19fX/9fX1//Xw4v/svUD/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/7shh//b29v/09PT/9vb2//X19f/19fX/9fX1//X19f/19fX/9fX1//b29v/09PT/9vb2//X19f/19fX/9fX1//T09P/19fX/9PT0//Xw4v/tvUD/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/7shh//b29v/09PT/9vb2//T09P/19fX/9fX1//X19f/19fX/9PT0//b29v/09PT/9vb2//X19f/19fX/9fX1//T09P/29vb/9PT0/+/p3P/ruz7/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/7cZf//Hx8f/4+Pj/8fHx//j4+P/09PT/9vb2//b29v/09PT/+Pj4//Hx8f/4+Pj/8fHx//f39//19fX/9fX1//n5+f/y8vL/+vr6//n05v/uvUD/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/78li//n5+f/z8/P/+vr6//Ly8v/39/f/9PT0//T09P/39/f/8vLy//r6+v/z8/P/+fn5//T09P/29vb/9fX1//Ly8v/4+Pj/8fHx//Pu4P/svD//66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/7cdh//T09P/29vb/9PT0//b29v/09PT/9fX1//X19f/09PT/9vb2//T09P/29vb/9PT0//b29v/19fX/9fX1//b29v/09PT/9vb2//Tv4f/svUD/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/7shh//X19f/19fX/9fX1//X19f/19fX/9fX1//X19f/19fX/9fX1//X19f/19fX/9fX1//X19f/19fX/9fX1//X19f/19fX/9fX1//Pu4P/svD//66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/7sdg//T09P/29vb/9PT0//X19f/19fX/9fX1//X19f/19fX/9fX1//T09P/29vb/9PT0//b29v/19fX/9fX1//b29v/19fX/9vb2//Pu4f/svD//66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/7chg//T09P/29vb/9PT0//X19f/19fX/9fX1//b29v/19fX/9fX1//T09P/29vb/9PT0//b29v/19fX/9fX1//b29v/09PT/9vb2//r05//tvkH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/78li//r6+v/y8vL/+vr6//Ly8v/39/f/9PT0//T09P/39/f/8vLy//r6+v/y8vL/+vr6//Pz8//29vb/9vb2//Hx8f/4+Pj/8PDw/+/p3P/ruz7/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/7MZg//Hx8f/4+Pj/8fHx//n5+f/09PT/9vb2//b29v/09PT/+fn5//Hx8f/4+Pj/8fHx//f39//19fX/9fX1//n5+f/y8vL/+vr6//Xw4v/svD//66oB/+uqAf/rqgH/7bkw//DFVP/swVD/8MVU/+zBUP/uw1P/7cJR/+3CUf/uw1P/7MFQ//DFVP/swVD/8MVU/+3CUf/uw1L/7sNS/+zBUP/vxFP/68BQ//DFU//stSb/66oB/+uqAf/rqgH/7shh//b29v/09PT/9vb2//X19f/29vb/9fX1//X19f/29vb/9fX1//b29v/09PT/9vb2//X19f/19fX/9fX1//T09P/29vb/9PT0//Pu4f/svD//66oB/+uqAf/rqgH/8NOG//Xx6P/08Of/9fHo//Tw5//08ef/9PHn//Tx5//08ef/9PDn//Xx6P/08Of/9fHo//Tw5//08ef/9PHn//Tw5//18ej/8/Dm//Xw5P/uyWn/66oB/+uqAf/rqgH/7shh//X19f/19fX/9fX1//X19f/19fX/9fX1//X19f/19fX/9fX1//X19f/19fX/9fX1//X19f/19fX/9fX1//X19f/19fX/9fX1//Xw4v/svUD/66oB/+uqAf/rqgH/7897//Lq0//17NX/8urT//Tr1P/z6tP/9OvU//Tr1P/z6tP/9OvU//Lq0//17NX/8urT//Ts1f/z69T/9OvU//Ts1f/z6tP/9ezV//Loz//tx2D/66oB/+uqAf/rqgH/7shh//b29v/19fX/9vb2//X19f/19fX/9fX1//X19f/19fX/9fX1//b29v/19fX/9vb2//X19f/19fX/9fX1//T09P/19fX/9PT0//Xw4v/svT//66oB/+uqAf/rqgH/664O/+yxGP/rsBf/7LEY/+uwF//ssRj/7LEY/+yxGP/ssRj/67AX/+yxGP/rsBj/7LEY/+uxGP/rsRj/7LEY/+uwGP/ssRj/67AX/+yxGP/rrQv/66oB/+uqAf/rqgH/7shh//b29v/09PT/9vb2//T09P/19fX/9fX1//X19f/19fX/9PT0//b29v/09PT/9vb2//X19f/19fX/9fX1//T09P/29vb/9PT0/+/p3P/ruz7/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/7cZf//Hx8f/4+Pj/8fHx//j4+P/09PT/9vb2//f39//09PT/+Pj4//Hx8f/4+Pj/8fHx//f39//19fX/9fX1//n5+f/y8vL/+vr6//r05//tvkH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/78li//r6+v/y8vL/+vr6//Ly8v/39/f/9PT0//T09P/39/f/8vLy//r6+v/y8vL/+vr6//Pz8//29vb/9vb2//Hx8f/4+Pj/8PDw//Pu4P/svD//66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/7shg//T09P/29vb/9PT0//b29v/19fX/9fX1//X19f/19fX/9vb2//T09P/29vb/9PT0//b29v/19fX/9fX1//b29v/09PT/9vb2//Tx5//uw1H/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/66oB/+uqAf/rqgH/7810//X19f/29vb/9fX1//b29v/19fX/9fX1//X19f/19fX/9vb2//X19f/29vb/9fX1//b29v/19fX/9fX1//X19f/19fX/9fX1//X19P/w3Kf/7LUn/+yvEf/rrQ3/660M/+utDf/rrQz/660N/+utDP/rrQz/660M/+utDP/rrQz/660M/+utDf/rrQz/660N/+utDP/rrQz/660M/+utDP/rrQz/660M/+utDf/rrQz/664N/+ywE//sujf/8+rS//T09P/19fX/9PT0//X19f/19fX/9fX1//X19f/19fX/9fX1//T09P/19fX/9PT0//b29v/19fX/9fX1//b29v/19fX/9vb2//T09P/19fT/8ejQ//Leqv/x2p7/79ib//Pcn//u15r/89yg/+7Xmv/x2p3/79ic/+/YnP/x2p3/7tea//PcoP/u15r/89yf/+/Ym//w2Z3/8Nmd/+7Wmv/y257/7daZ//TdoP/u15v/89yg//LgsP/z7d3/9vX1//T09P/29vb/9PT0//X19f/19fX/9fX1//X19f/19fX/9fX1//T09P/29vb/9PT0//b29v/19fX/9fX1//b29v/09PT/9vb2//r6+v/y8vL/+fn5//X19f/19fX/9/f3//Hx8f/5+fn/8fHx//j4+P/09PT/9/f3//b29v/09PT/+Pj4//Hx8f/5+fn/8fHx//f39//19fX/9fX1//n5+f/y8vL/+vr6//Dw8P/4+Pj/8fHx//b29v/29vb/8/Pz//r6+v/y8vL/+vr6//Ly8v/39/f/9PT0//T09P/39/f/8vLy//r6+v/y8vL/+vr6//Pz8//29vb/9vb2//Hx8f/4+Pj/8PDw/wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=="
#
# Action Icons
#
$PlayIcon = @"
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" style="fill: rgba(255, 255, 255, 1);transform: ;msFilter:;"><path d="M7 6v12l10-6z"></path></svg>
"@
$ExportIcon = @"
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" style="fill: rgba(255, 255, 255, 1);transform: ;msFilter:;"><path d="M18 22a2 2 0 0 0 2-2v-5l-5 4v-3H8v-2h7v-3l5 4V8l-6-6H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12zM13 4l5 5h-5V4z"></path></svg>
"@
$CheckpointIcon = @"
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" style="fill: rgba(255, 255, 255, 1);transform: ;msFilter:;">
  <!-- Refresh Circular Arrow -->
  <path d="M4 4h3v2H6.4c1.7-1.8 4-3 6.6-3 5 0 9 4 9 9s-4 9-9 9-9-4-9-9h2c0 3.9 3.1 7 7 7s7-3.1 7-7-3.1-7-7-7c-2 0-3.9.8-5.3 2.2V8H4V4z"></path>
  <!-- Checkmark -->
  <path d="M9 12l2 2 4-4" stroke="white" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"></path>
</svg>
"@
$RestoreIcon = @"
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" style="fill: rgba(255, 255, 255, 1);transform: ;msFilter:;">
  <!-- Refresh Circular Arrow -->
  <path d="M4 4h3v2H6.4c1.7-1.8 4-3 6.6-3 5 0 9 4 9 9s-4 9-9 9-9-4-9-9h2c0 3.9 3.1 7 7 7s7-3.1 7-7-3.1-7-7-7c-2 0-3.9.8-5.3 2.2V8H4V4z" ></path>
  <!-- First Triangle -->
  <path d="M12 6L6 12L12 18Z" transform="scale(0.7) translate(5,5)"></path>
  <!-- Second Triangle -->
  <path d="M18 6L12 12L18 18Z" transform="scale(0.7) translate(5,5)"></path></svg>
"@
$StopIcon = @"
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" style="fill: rgba(255, 255, 255, 1);transform: ;msFilter:;"><path d="M7 7h10v10H7z"></path></svg>
"@
$PauseIcon = @"
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" style="fill: rgba(255, 255, 255, 1);transform: ;msFilter:;"><path d="M8 7h3v10H8zm5 0h3v10h-3z"></path></svg>
"@
$OptimizeIcon = @"
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" style="fill: rgba(255, 255, 255, 1);transform: ;msFilter:;"><path d="m21.224 15.543-.813-1.464-1.748.972.812 1.461c.048.085.082.173.104.264a1.024 1.024 0 0 1-.014.5.988.988 0 0 1-.104.235 1 1 0 0 1-.347.352.978.978 0 0 1-.513.137H14v-2l-4 3 4 3v-2h4.601c.278 0 .552-.037.811-.109a2.948 2.948 0 0 0 1.319-.776c.178-.179.332-.38.456-.593a2.992 2.992 0 0 0 .336-2.215 3.163 3.163 0 0 0-.299-.764zM5.862 11.039l-2.31 4.62a3.06 3.06 0 0 0-.261.755 2.997 2.997 0 0 0 .851 2.735c.178.174.376.326.595.453A3.022 3.022 0 0 0 6.236 20H8v-2H6.236a1.016 1.016 0 0 1-.5-.13.974.974 0 0 1-.353-.349 1 1 0 0 1-.149-.468.933.933 0 0 1 .018-.245c.018-.087.048-.173.089-.256l2.256-4.512 1.599.923L8.598 8 4 9.964l1.862 1.075zm12.736 1.925L19.196 8l-1.638.945-2.843-5.117a2.95 2.95 0 0 0-1.913-1.459 3.227 3.227 0 0 0-.772-.083 3.003 3.003 0 0 0-1.498.433A2.967 2.967 0 0 0 9.41 3.944l-.732 1.464 1.789.895.732-1.465c.045-.09.101-.171.166-.242a.933.933 0 0 1 .443-.27 1.053 1.053 0 0 1 .53-.011.963.963 0 0 1 .63.485l2.858 5.146L14 11l4.598 1.964z"></path></svg>
"@
$ArchiveIcon = @"
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" style="fill: rgba(255, 255, 255, 1);transform: ;msFilter:;"><path d="M6 2a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8l-6-6h-3v2H9v2h2v2H9v2h2v8H7v-6h2v-2H7V8h2V6H7V4h2V2H6zm7 2 5 5h-5V4z"></path><path d="M8 15h2v2H8z"></path></svg>
"@
# End General Icons

#
# HTML Fragments
#
$htmlMenu=@"
	<nav>
		<a href="/" class="home" alt="Home"><i class="home"></i></a>
		<a href="/vm/list/" class="vm" alt="Manage VMs"><i class="vm"></i></a>
		<a href="/service/list/" class="service" alt="Manage Services"><i class="service"></i></a>
		<a href="/volumes/list/" class="volumes" alt="View Free Space"><i class="volumes"></i></a>
		<a href="/process/list/" class="process" alt="Process"><i class="process"></i></a>
		<a href="/job/list/" class="job" alt="Manage Jobs"><i class="job"></i></a>
	</nav>

"@
$htmlHead = @"
	<html><head><title>[TITLE]</title>
	<meta http-equiv="refresh" content="600" >
	  <style>
		:root {
			--primary-color: #0078d4;
			--secondary-color: #000;
			--icon-color: #FFFFFF;
			}
		body {      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;}
		body {
			margin-left:50px; /* Add space to fit the nav */
			margin-top:50px;
		}

		table {      border-collapse: collapse;      width: 100%;}
		th, td {      border: 1px solid #dddddd;      text-align: left;      padding: 2px;}
		th {      background-color: #f2f2f2;}
		form { 	display:inline;	}
		
		/* Tiles for Home Page */
		.tile {
			cursor: pointer;
			color: white;
			border-style: solid;
			border-width: 0px;
			width: 20em;
			height: 10em;
			text-align: left;
			list-style-type: none;
			display: inline-block;
			margin: 1.5em 1.5em 1.5em 1.5em;
			position: relative;
			background-color: var(--primary-color);
			background-repeat: no-repeat;
			background-position: right;
			background-size: contain; 
		}
		
		.critical {
			background-color: #D00000;
		}
		.warning {
			background-color: #FF6000;
		}		
		.good {
			background-color: #009000;
		}
		
		.tile a {
			text-decoration: none;
			color: white;
		}

		.tile H1 {
			font-size: 3.5em;
			margin: 10px;
		}
		.tile H2 {
			font-size: 1.5em;
			margin: 10px;
		}

		.tile_description p {
			padding: 5px;
			margin: 0px;
		}

		.tile_description {
			position: absolute;
			bottom: 0;
			width: 100%;
			text-align: right;
			background-color: #000000;
			background-color: rgba(0, 0, 0, 0.5);
			color: #FFFFFF;
			overflow: hidden;
			height: 20%; 
		}

		.tile_description:hover {
			#top: 0px;
			#height:100%;
		}
		
		/* Home Page Tile Icons */
		/*
		 * Navigation
		 */
		nav {
			position: fixed;
			top: 0;
			left: 0;
			z-index: 50;
			display: flex;
			#justify-content: space-around;
			flex-direction: column;/* Vertical */
			flex-direction: row;/* Horizontal */
			height: 100vh; /* Vertical */
			height: 40px; width: 100vh; /* Horizontal */
			width: 100%; /* Horizontal */
			float: right; /* Horizontal */
			background: var(--secondary-color);
			opacity: 1 !important;
			filter: brightness(400%)
		}
		/* Selected Nav Item */
		.[SELECTED] { 
			background-color:#0a0a0a;
			filter: brightness(150%)
		}
		nav a {
			font-size: 40px;
			color: #fff;
			text-decoration: none;
			padding: 20px;
			text-align: center;
			width:10px;
		}

		nav a:hover {
			background-color: #080808;
			fill: rgba(255, 255, 255, 1);
			opacity: 1;
		}

		nav * {
			background-repeat: no-repeat;
			background-position: center;
		}

		/*
		 * Navigation Icons
		 */
		 
		.home {
		  background-image: url('data:image/svg+xml,  <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" style="fill: rgba(100, 100, 100, 0.3);"><path d="M3 13h1v7c0 1.103.897 2 2 2h12c1.103 0 2-.897 2-2v-7h1a1 1 0 0 0 .707-1.707l-9-9a.999.999 0 0 0-1.414 0l-9 9A1 1 0 0 0 3 13zm7 7v-5h4v5h-4zm2-15.586 6 6V15l.001 5H16v-5c0-1.103-.897-2-2-2h-4c-1.103 0-2 .897-2 2v5H6v-9.586l6-6z"></path></svg>');
		}

		.vm {
		  background-image:  url('data:image/svg+xml,  <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" style="fill: rgba(100, 100, 100, 0.3);" ><path d="M20 17.722c.595-.347 1-.985 1-1.722V5c0-1.103-.897-2-2-2H5c-1.103 0-2 .897-2 2v11c0 .736.405 1.375 1 1.722V18H2v2h20v-2h-2v-.278zM5 16V5h14l.002 11H5z"></path></svg>');
		}

        .mem {
          background-image:  url('data:image/svg+xml, <svg xmlns="http://www.w3.org/2000/svg" height="24" width="24" version="1.1" style="fill: rgba(100, 100, 100, 0.3);" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 299.92 299.92" xml:space="preserve" ><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <g> <g> <g> <path d="M293.4,65.2H6.52C2.914,65.2,0,68.114,0,71.72v117.36c0,3.606,2.914,6.52,6.52,6.52h6.52v32.6 c0,3.606,2.914,6.52,6.52,6.52h260.8c3.606,0,6.52-2.914,6.52-6.52v-32.6h6.52c3.606,0,6.52-2.914,6.52-6.52V71.72 C299.92,68.114,297.006,65.2,293.4,65.2z M273.84,221.68h-19.56H228.2h-26.08h-26.08h-26.08h-26.08H97.8H71.72H45.64H26.08V195.6 h19.56h26.08H97.8h26.08h26.08h26.08h26.08h26.08h26.08h19.56V221.68z M286.88,182.56h-6.52H19.56h-6.52V78.24h273.84V182.56z"></path> <path d="M32.6,169.52h39.12c3.606,0,6.52-2.914,6.52-6.52V97.8c0-3.606-2.914-6.52-6.52-6.52H32.6c-3.606,0-6.52,2.914-6.52,6.52 V163C26.08,166.606,28.994,169.52,32.6,169.52z M39.12,104.32H65.2v52.16H39.12V104.32z"></path> <path d="M97.8,169.52h39.12c3.606,0,6.52-2.914,6.52-6.52V97.8c0-3.606-2.914-6.52-6.52-6.52H97.8c-3.606,0-6.52,2.914-6.52,6.52 V163C91.28,166.606,94.194,169.52,97.8,169.52z M104.32,104.32h26.08v52.16h-26.08V104.32z"></path> <path d="M163,169.52h39.12c3.606,0,6.52-2.914,6.52-6.52V97.8c0-3.606-2.914-6.52-6.52-6.52H163c-3.606,0-6.52,2.914-6.52,6.52 V163C156.48,166.606,159.394,169.52,163,169.52z M169.52,104.32h26.08v52.16h-26.08V104.32z"></path> <path d="M228.2,169.52h39.12c3.606,0,6.52-2.914,6.52-6.52V97.8c0-3.606-2.914-6.52-6.52-6.52H228.2 c-3.606,0-6.52,2.914-6.52,6.52V163C221.68,166.606,224.594,169.52,228.2,169.52z M234.72,104.32h26.08v52.16h-26.08V104.32z"></path> <path d="M52.16,215.16v-13.04c0-3.606-2.914-6.52-6.52-6.52c-3.606,0-6.52,2.914-6.52,6.52v13.04c0,3.606,2.914,6.52,6.52,6.52 C49.246,221.68,52.16,218.766,52.16,215.16z"></path> <path d="M78.24,215.16v-13.04c0-3.606-2.914-6.52-6.52-6.52c-3.606,0-6.52,2.914-6.52,6.52v13.04c0,3.606,2.914,6.52,6.52,6.52 C75.326,221.68,78.24,218.766,78.24,215.16z"></path> <path d="M104.32,215.16v-13.04c0-3.606-2.914-6.52-6.52-6.52c-3.606,0-6.52,2.914-6.52,6.52v13.04c0,3.606,2.914,6.52,6.52,6.52 C101.406,221.68,104.32,218.766,104.32,215.16z"></path> <path d="M130.4,215.16v-13.04c0-3.606-2.914-6.52-6.52-6.52c-3.606,0-6.52,2.914-6.52,6.52v13.04c0,3.606,2.914,6.52,6.52,6.52 C127.486,221.68,130.4,218.766,130.4,215.16z"></path> <path d="M156.48,215.16v-13.04c0-3.606-2.914-6.52-6.52-6.52s-6.52,2.914-6.52,6.52v13.04c0,3.606,2.914,6.52,6.52,6.52 S156.48,218.766,156.48,215.16z"></path> <path d="M182.56,215.16v-13.04c0-3.606-2.914-6.52-6.52-6.52c-3.606,0-6.52,2.914-6.52,6.52v13.04c0,3.606,2.914,6.52,6.52,6.52 C179.646,221.68,182.56,218.766,182.56,215.16z"></path> <path d="M208.64,215.16v-13.04c0-3.606-2.914-6.52-6.52-6.52c-3.606,0-6.52,2.914-6.52,6.52v13.04c0,3.606,2.914,6.52,6.52,6.52 C205.726,221.68,208.64,218.766,208.64,215.16z"></path> <path d="M234.72,215.16v-13.04c0-3.606-2.914-6.52-6.52-6.52c-3.606,0-6.52,2.914-6.52,6.52v13.04c0,3.606,2.914,6.52,6.52,6.52 C231.806,221.68,234.72,218.766,234.72,215.16z"></path> <path d="M260.8,215.16v-13.04c0-3.606-2.914-6.52-6.52-6.52c-3.606,0-6.52,2.914-6.52,6.52v13.04c0,3.606,2.914,6.52,6.52,6.52 C257.886,221.68,260.8,218.766,260.8,215.16z"></path> </g> </g> </g> </g></svg>');
        }

		.job {
		  background-image: url('data:image/svg+xml, <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" style="fill: rgba(100, 100, 100, 0.3);"><path d="m20.145 8.27 1.563-1.563-1.414-1.414L18.586 7c-1.05-.63-2.274-1-3.586-1-3.859 0-7 3.14-7 7s3.141 7 7 7 7-3.14 7-7a6.966 6.966 0 0 0-1.855-4.73zM15 18c-2.757 0-5-2.243-5-5s2.243-5 5-5 5 2.243 5 5-2.243 5-5 5z"></path><path d="M14 10h2v4h-2zm-1-7h4v2h-4zM3 8h4v2H3zm0 8h4v2H3zm-1-4h3.99v2H2z"></path></svg>');
		}

		.process {
		  background-image: url('data:image/svg+xml, <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" style="fill: rgba(100, 100, 100, 0.3);"><path d="M19.893 3.001H4c-1.103 0-2 .897-2 2v14c0 1.103.897 2 2 2h15.893c1.103 0 2-.897 2-2V5a2.003 2.003 0 0 0-2-1.999zM8 19.001H4V8h4v11.001zm6 0h-4V8h4v11.001zm2 0V8h3.893l.001 11.001H16z"></path></svg>');
		}

		.volumes {
		  background-image: url('data:image/svg+xml, <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" style="fill: rgba(100, 100, 100, 0.3);"><path d="M12 22c3.976 0 8-1.374 8-4V6c0-2.626-4.024-4-8-4S4 3.374 4 6v12c0 2.626 4.024 4 8 4zm0-2c-3.722 0-6-1.295-6-2v-1.268C7.541 17.57 9.777 18 12 18s4.459-.43 6-1.268V18c0 .705-2.278 2-6 2zm0-16c3.722 0 6 1.295 6 2s-2.278 2-6 2-6-1.295-6-2 2.278-2 6-2zM6 8.732C7.541 9.57 9.777 10 12 10s4.459-.43 6-1.268V10c0 .705-2.278 2-6 2s-6-1.295-6-2V8.732zm0 4C7.541 13.57 9.777 14 12 14s4.459-.43 6-1.268V14c0 .705-2.278 2-6 2s-6-1.295-6-2v-1.268z"></path></svg>');
		}

		.service {
		  background-image: url('data:image/svg+xml, <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" style="fill: rgba(100, 100, 100, 0.3);"><path d="M12 16c2.206 0 4-1.794 4-4s-1.794-4-4-4-4 1.794-4 4 1.794 4 4 4zm0-6c1.084 0 2 .916 2 2s-.916 2-2 2-2-.916-2-2 .916-2 2-2z"></path><path d="m2.845 16.136 1 1.73c.531.917 1.809 1.261 2.73.73l.529-.306A8.1 8.1 0 0 0 9 19.402V20c0 1.103.897 2 2 2h2c1.103 0 2-.897 2-2v-.598a8.132 8.132 0 0 0 1.896-1.111l.529.306c.923.53 2.198.188 2.731-.731l.999-1.729a2.001 2.001 0 0 0-.731-2.732l-.505-.292a7.718 7.718 0 0 0 0-2.224l.505-.292a2.002 2.002 0 0 0 .731-2.732l-.999-1.729c-.531-.92-1.808-1.265-2.731-.732l-.529.306A8.1 8.1 0 0 0 15 4.598V4c0-1.103-.897-2-2-2h-2c-1.103 0-2 .897-2 2v.598a8.132 8.132 0 0 0-1.896 1.111l-.529-.306c-.924-.531-2.2-.187-2.731.732l-.999 1.729a2.001 2.001 0 0 0 .731 2.732l.505.292a7.683 7.683 0 0 0 0 2.223l-.505.292a2.003 2.003 0 0 0-.731 2.733zm3.326-2.758A5.703 5.703 0 0 1 6 12c0-.462.058-.926.17-1.378a.999.999 0 0 0-.47-1.108l-1.123-.65.998-1.729 1.145.662a.997.997 0 0 0 1.188-.142 6.071 6.071 0 0 1 2.384-1.399A1 1 0 0 0 11 5.3V4h2v1.3a1 1 0 0 0 .708.956 6.083 6.083 0 0 1 2.384 1.399.999.999 0 0 0 1.188.142l1.144-.661 1 1.729-1.124.649a1 1 0 0 0-.47 1.108c.112.452.17.916.17 1.378 0 .461-.058.925-.171 1.378a1 1 0 0 0 .471 1.108l1.123.649-.998 1.729-1.145-.661a.996.996 0 0 0-1.188.142 6.071 6.071 0 0 1-2.384 1.399A1 1 0 0 0 13 18.7l.002 1.3H11v-1.3a1 1 0 0 0-.708-.956 6.083 6.083 0 0 1-2.384-1.399.992.992 0 0 0-1.188-.141l-1.144.662-1-1.729 1.124-.651a1 1 0 0 0 .471-1.108z"></path></svg>');
		}

		/* Hyper-V Buttons */
		.start-button, .optimize-button, 
		.restore-button, checkpoint-button,
		.stop-button, .pause-button, 
		.export-button, .exportZip-button {
			border: none;
			color: white;
			align-items: center;
			justify-content: center;
			padding: 4px 8px 4px 8px;
			text-align: center;
			text-decoration: none;
			display: inline-block;
			font-size: 20px;
			margin: 2px 1px 2px 1px;
			cursor: pointer;
		}

		.start-button, .optimize-button, .restore-button {
			background-color: #4CAF50; /* Green */
		}
		.stop-button {
			background-color: #f44336; /* Red */
		}
		.pause-button, .export-button {
			background-color: #0000F0; /* Blue */
		}
		 .exportZip-button {
			background-color: #FFC83D; /* Yellow */
		}
	  </style>
	</head>
	<body>

"@
$htmlHead+=$htmlMenu

$htmlHomePage=@"
<div class="tile vm">
<a href="/vm/list/">
  <h1>[VirtualMachineCount]</h1>
  <h2>Running VMs</h2>
  <div class="tile_description"><p>Manage Virtual Machines..</p></div>
</a>
</div>

<div class="tile mem">
<a href="/vm/list/">
  <h1>[VirtualMachineMemory] GB</h1>
  <h2>VM Memory</h2>
 <div class="tile_description"><p>Manage Virtual Machines..</p></div>
 </a>
 </div>

<div class="tile service">
<a href="/service/list/">
  <h1>[ServicesCount]</h1>
  <h2>Running Services</h2>
 <div class="tile_description"><p>Manage Services..</p></div>
 </a>
 </div>

 <div class="tile process">
 <a href="/process/list/">
  <h1>[ProcessCount]</h1>
  <h2>Processes</h2>
 <div class="tile_description"><p>Monitor Processes..</p></div>
 </a>
 </div>
 
<div class="tile job">
<a href="/job/list/">
  <h1>[RunningJobsCount]</h1>
  <h2>Running Jobs</h2>
 <div class="tile_description"><p>Monitor Jobs..</p></div>
 </a>
 </div>

"@

$htmlDrive=@"
<div class="tile volumes [Status]">
<a href="/volumes/list/">
  <h1>[TotalFreeSpace]</h1>
  <h2>[DriveLetter] Drive Free Space</h2>
 <div class="tile_description"><p>View Volumes..</p></div>
 </a>
 </div>
 
"@

# Virtual Machines Header
$htmlVirtualMachines=@"
					<h1>Hyper-V Virtual Machines</h1>
					<table>  
					<tr>    
						<th>Name</th>    
						<th>State</th>
						<th>Status</th>
						<th>Memory Assigned</th>
						<th>Processor Count</th>
						<th>Actions</th>  
					</tr>
"@

    
	$identity=$context.User.Identity

    # Check if request requires authentication
    if (!$request.IsAuthenticated) {
		Write-Host "`nRecevied Unautenticated request $(get-date) ."
      #  $response.StatusCode = 401
        $response.OutputStream.Close()
        return } 
	else {
		Write-Host "`nRecevied request $(get-date) for $path from $($identity.Name)."
	}

    $queryString = $url.Query
    Write-Debug "Query String: [$queryString]"
    # Parse query parameters
    $queryParameters = [System.Web.HttpUtility]::ParseQueryString($queryString)

    $response.ContentType = "text/html"
	
	Write-host "Request for $path"
	$pattern = "/(.*?)/"
	$selectedUri=($path -split $pattern)[1]
    
	Write-Host "SelectedURI: [$selectedUri]"
	$path=$path.TrimEnd("/")
	$htmlResponse=$htmlHead.Replace("[SELECTED]",$selectedUri)
	
	#
	# Handle URIs
	#
    switch ($path) {
       "/job/list" {
            $htmlResponse=$htmlResponse.Replace("[TITLE]", "Background Jobs")
            # List off current jobs
            Write-Host "`nListing Jobs.."  
            
            Get-Job -State Running
            $htmlResponse +="<h1>Running</h1>"
            $htmlResponse += Get-Job -State Running | Select -Property Id, Name, State | ConvertTo-Html

            $htmlResponse +="<h1>Completed</h1>"
            $htmlResponse += Get-Job -State Completed | Select -Property Id, Name, State | ConvertTo-Html

            $htmlResponse +="<h1>Failed</h1>"
            $htmlResponse += Get-Job -State Failed | Select -Property Id, Name, State | ConvertTo-Html

            $htmlResponse +="<h1>Stopped</h1>"
            $htmlResponse += Get-Job -State Stopped | Select -Property Id, Name, State | ConvertTo-Html
            
            # Send HTML response
            [byte[]]$buffer = [System.Text.Encoding]::UTF8.GetBytes($htmlResponse)
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
      
			$htmlResponse=""
			
            $response.StatusCode = 200
            $response.StatusDescription = "OK"
            #$response.redirect("/vm/list")
            $response.Close()
        }
		"/volumes/list" {
		    $htmlResponse=$htmlResponse.Replace("[TITLE]", "Processes")
            # List off current processes
            Write-Host "`nListing Processes.." -NoNewline 
			$htmlResponse+="<H1>Volumes</H1>"
			$htmlResponse+=get-volume | Select -Property DriveLetter,FileSystemLabel,FileSystemType,HealthStatus,SizeRemaining,Size | ConvertTo-HTML -Fragment
			# Send HTML response
            [byte[]]$buffer = [System.Text.Encoding]::UTF8.GetBytes($htmlResponse)
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            
            $response.StatusCode = 200
            $response.StatusDescription = "OK"
            $response.Close()
			
		}
		"/process/list" {
		    $htmlResponse=$htmlResponse.Replace("[TITLE]", "Processes")
            # List off current processes
            Write-Host "`nListing Processes.." -NoNewline 
			$htmlResponse+="<H1>Running Processes</H1>"
			$htmlResponse+=get-process -IncludeUserName | Select -Property ID,Name,UserName,PagedMemorySize,VirtualMemorySize,Path | ConvertTo-HTML -Fragment
			# Send HTML response
            [byte[]]$buffer = [System.Text.Encoding]::UTF8.GetBytes($htmlResponse)
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            
            $response.StatusCode = 200
            $response.StatusDescription = "OK"
            $response.Close()
			
		}
		"/service/list" {
		    $htmlResponse=$htmlResponse.Replace("[TITLE]", "Services")
            # List off current services
            Write-Host "`nListing Services.."
			$htmlResponse+="<H1>Running</H1>"
			$htmlResponse+=get-service | where {$_.Status -eq "Running"} | Select -Property DisplayName,ServiceName,CanStop,CanShutdown,StartType | ConvertTo-HTML -Fragment
			
			# Send HTML response
            [byte[]]$buffer = [System.Text.Encoding]::UTF8.GetBytes($htmlResponse)
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            
            $response.StatusCode = 200
            $response.StatusDescription = "OK"
            #$response.redirect("/vm/list")
            $response.Close()
		}
		
        "/vm/list" {
            $htmlResponse=$htmlResponse.Replace("[TITLE]", "Virtual Machines")
            $htmlResponse+=$htmlVirtualMachines
            Write-host "`nListing VMs.." -NoNewline
            # Execute command to list Hyper-V virtual machines
            $vmList = Get-VM | Select-Object Name, State, Status, MemoryAssigned, ProcessorCount

			#
            # Construct HTML response
			# 
			# The /vm/list is a little more complex than a HTML table, so we need to constuct the table with buttons, etc
			#
                foreach ($vm in $vmList) {
					$vmCheckpoints = $(Get-VMCheckpoint -vmName $($VM.Name))
					Write-Host "`n`t$($VM.Name) has [$($($vmCheckpoints).Count)] Checkpoints.." -noNewLine
                    $htmlResponse += "<tr><td>$($vm.Name) [$($($vmCheckpoints).Count)]</td>"
                    $htmlResponse += "<td>$($vm.State)</td>"
                    $htmlResponse += "<td>$($vm.Status)</td>"
                    $htmlResponse += "<td>$([int]$($vm.MemoryAssigned/1GB)) GB</td>"
                    $htmlResponse += "<td>$($vm.ProcessorCount)</td><td>"
                    if ($vm.State -eq "Running") {
                        # Add stop button if VM is running
                        $htmlResponse += "<form action='/vm/stop' method='get'><input type='hidden' name='vmName' value='$($vm.Name)'><button title='Stop VM' type='submit' value='&#9209;' class='stop-button'>$($StopIcon)</button></form>"
                        # Add stop button if VM is running
                        $htmlResponse += "<form action='/vm/pause' method='get'><input type='hidden' name='vmName' value='$($vm.Name)'><button title='Pause VM' type='submit' value='&#9209;' class='pause-button'>$($PauseIcon)</button></form>"
  
					} else {
                        # Add start button if VM is not running
                        $htmlResponse += "<form action='/vm/start' method='get'><input type='hidden' name='vmName' value='$($vm.Name)'><button title='Start VM' type='submit' value='&#9205;' class='start-button'>$($PlayIcon)</button></form>"
						
						If($($vmCheckpoints).Count -gt 0) {
							# Add Restore Snamshot button if VM has an export
							$htmlResponse += "<form action='/vm/restore' method='get'><input type='hidden' name='vmName' value='$($vm.Name)'><button title='Restore VM Checkpoint' type='submit' value='&#9205;' class='restore-button'>$($RestoreIcon)</button></form>"
						}
						
						# Add optimise button if VM is not running
                        $htmlResponse += "<form action='/vm/optimize' method='get'><input type='hidden' name='vmName' value='$($vm.Name)'><button title='Optimize VM' type='submit' value='&#9205;' class='optimize-button'>$($OptimizeIcon)</button></form>"

                    }

					# Add Checkpoint button if VM has an export
					$htmlResponse += "<form action='/vm/checkpoint' method='get'><input type='hidden' name='vmName' value='$($vm.Name)'><button title='Checkpoint VM' type='submit' value='&#9205;' class='optimize-button'>$($CheckpointIcon)</button></form>"

                    # Add export button
                    $htmlResponse += "<form action='/vm/export' method='get'><input type='hidden' name='vmName' value='$($vm.Name)'><button title='Export VM' type='submit' value='&#128426;' class='export-button'>$($ExportIcon)</button></form>"

                    # Add export Archive button
                    $htmlResponse += "<form action='/vm/exportarchive' method='get'><input type='hidden' name='vmName' value='$($vm.Name)'><button title='Export Compressed Archive of VM' type='submit' value='&#128426;' class='exportZip-button'>$($ArchiveIcon)</button></form>"
                   
                    $htmlResponse += "</td></tr>"
                }
                $htmlResponse += "</table></body></html>"

                # Send HTML response
                [byte[]]$buffer = [System.Text.Encoding]::UTF8.GetBytes($htmlResponse)
			
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
                $response.Close()
				Write-Host "`nListing VMs complete."
            
        }
        "/vm/start" {
            # Start the specified VM
            $vmName = $queryParameters["vmName"]
            Write-Host "`nStarting VM: $vmName.."
            # Your code to start VMs goes here
            Start-VM $vmName
            $response.StatusCode = 200
            $response.StatusDescription = "OK"
            $response.redirect("/vm/list")
            $response.Close()
        }
        "/vm/stop" {
            # Stop the specified VM
            $vmName = $queryParameters["vmName"]
            Write-Host "`nStopping VM: $vmName.."
            Stop-VM $vmName -Force
            # Your code to stop VMs goes here
            $response.StatusCode = 200
            $response.StatusDescription = "OK"
            $response.redirect("/vm/list")
            $response.Close()
        }
        "/vm/pause" {
            # Stop the specified VM
            $vmName = $queryParameters["vmName"]
            Write-Host "`nPausing VM: $vmName.."
            Stop-VM $vmName -Force -Save
            # Your code to stop VMs goes here
            $response.StatusCode = 200
            $response.StatusDescription = "OK"
            $response.redirect("/vm/list")
            $response.Close()
        }
        "/vm/optimize" {
            # Stop the specified VM
            $vmName = $queryParameters["vmName"]
            Write-Host "`nOptimizing VM: $vmName.."
            optimize-vhd $(Get-vm $vmName).HardDrives.path -Mode full 
            # Your code to stop VMs goes here
            $response.StatusCode = 200
            $response.StatusDescription = "OK"
            $response.redirect("/vm/list")
            $response.Close()
        }
        "/vm/export" {
            # Export the specified VM
            $vmName = $queryParameters["vmName"]
            Write-Host "`nExporting VM: $vmName.." -NoNewline
            Start-Job -Name "Export $vmName" -ScriptBlock {
                Start-Transcript -path "$using:ExportPath\$using:vmName.log" -Force
                $vmName="$using:vmName"
                Write-Host "VMName: [$vmName]"
                $ExportPath="$using:ExportPath"
                Write-Host "Export Path:[$ExportPath]"

			    if (Test-Path "$ExportPath\$vmName"  -PathType Container) {
				    Write-Host "`nRemoving Export Folder $ExportPath\$vmName.." -NoNewline 
				    Remove-Item -Path "$ExportPath\$vmName" -Recurse -Force 
                }
                Write-Host "Exporting VMName: [$vmName] to [$ExportPath]"
                Export-VM -VM (Get-Vm $vmName) -Path "$ExportPath" -Confirm:$false 
            } -ArgumentList $vmName, $ExportPath
            
            # Your code to export VMs goes here
            $response.StatusCode = 200
            $response.StatusDescription = "OK"
			if ($redirectToJobs) {
				$response.redirect("/job/list")
			} else {
				$response.redirect("/vm/list")
			}
            $response.Close()
        }
		"/vm/exportarchive" {
            # Export the specified VM to the $ArchivePath
            $vmName = $queryParameters["vmName"]
            Write-Host "`nExporting Archive Zip VM: $vmName.." 
			if (Test-Path "$ArchivePath\$vmName"  -PathType Container) {
				Write-Host "`nRemoving Export Folder $ArchivePath\$vmName.."  
				Remove-Item -Path "$ArchivePath\$vmName" -Recurse -Force -ErrorAction SilentlyContinue
            }
            Start-Job -Name "Archive $vmName" -ScriptBlock {
                Start-Transcript -path "$using:ArchivePath\$using:vmName.log" -Force
                $vmName="$using:vmName"
                Write-Host "VMName: [$vmName]"
                $ArchivePath="$using:ArchivePath"
                Write-Host "Archive Path:[$ArchivePath]"
                $ArchiveZip="$using:ArchivePath\$using:vmName.zip"
                Write-Host "Archive Zip: [$ArchiveZip]"
                $ClobberZips="$($using:ClobberZips -eq $true)"
                Write-Host "ClobberZips: [$ClobberZips]"

                Add-Type -AssemblyName System.IO.Compression.FileSystem
                Export-VM -VM (Get-Vm $vmName) -Path "$ArchivePath" -Confirm:$false
                
                # Check to see if the zip exists?
                If(Test-Path -Path "$ArchiveZip" -PathType Leaf) {
                    # Check if its ok to overwrite the zip?
                    If($ClobberZips -eq $true) {
                        # Remove the Zip
                        Write-Host "Removing $ArchiveZip.."
                        Remove-Item -Path "$ArchiveZip" -Force
                        Remove-Item -Path "$($ArchiveZip).SHA" -Force -ErrorAction SilentlyContinue
                    } else {
                        # Move it out of the way
                        
                        $file   = [io.path]::GetFileNameWithoutExtension($ArchiveZip)
                        $ext    = [io.path]::GetExtension($ArchiveZip)
                        $Target = "$using:ArchivePath\" + $file +"_" + $(get-date -f yyyy-MM-dd) + $ext
                        Write-Host "Keeping previous zip [$ArchiveZip] as [$Target].."
                        Move-Item $ArchiveZip $Target -Force
                        Move-Item "$ArchiveZip.SHA" "$Target.SHA" -Force
                    }
                }
                Write-Host "Creating Archive Zip: [$ArchiveZip]"

                [IO.Compression.ZipFile]::CreateFromDirectory("$ArchivePath\$vmName\", "$ArchiveZip")
                If(Test-Path -Path "$ArchiveZip" -PathType Leaf) {
                    Write-Host "Zip file created successfully."
                    Set-Content -Value (Get-FileHash "$ArchiveZip" -Algorithm SHA256).Hash -Path "$ArchiveZip.SHA"
                	# Clean up the temp export folder
                    Remove-Item -Path "$ArchivePath\$vmName" -Recurse -Force
                } else {
                    Write-Error "Error creating Archive file.."
                    exit
                }
                Stop-Transcript
            } -ArgumentList $vmName, $ArchivePath, $ClobberZips
            
			
            $response.StatusCode = 200
            $response.StatusDescription = "OK"
            if ($redirectToJobs) {
				$response.redirect("/job/list")
			} else {
				$response.redirect("/vm/list")
			}
            $response.Close()
        }
        "/vm/checkpoint" {
            # Checkpoint the specified VM
            $vmName = $queryParameters["vmName"]
            $CheckpointCount = $(Get-VMCheckpoint -VMName $vmName)
			
			Write-Host "`nCreating Checkpoint VM: $vmName[$CheckpointCount].."
			Start-Job -Name "Checkpoint $vmName" -ScriptBlock {
                $vmName="$using:vmName"
                Write-Host "Starting Checkpoint for VMName: [$vmName]"
				Checkpoint-VM -Name $vmName
            } -ArgumentList $vmName, $ExportPath
				
            $response.StatusCode = 200
            $response.StatusDescription = "OK"
            $response.redirect("/vm/list")
            $response.Close()
        }
		"/favicon.ico" {
			$faviconBytes = [System.Convert]::FromBase64String($favicon)
			$response.ContentType = 'image/x-icon'
			$response.ContentLength64 = $faviconBytes.Length
			$response.OutputStream.Write($faviconBytes, 0, $faviconBytes.Length)
			$response.StatusCode = 200
			$response.Close()
			return
		}
        #
        # Default Home Page
        #
        default {			
			$htmlResponse=$htmlHead.Replace("[TITLE]", "$appName - [$env:COMPUTERNAME]")
			
			$htmlResponse+="<H1>Compute</H1>"
			$htmlHomePage=$htmlHomePage.replace("[VirtualMachineCount]", $(get-vm | Where {$_.State -eq "Running"}).Count)
			$htmlHomePage=$htmlHomePage.replace("[ServicesCount]", $(get-service | Where {$_.Status -eq "Running"}).Count)

			$htmlHomePage=$htmlHomePage.replace("[VirtualMachineMemory]", $($(get-vm | Measure-Object -Property MemoryAssigned -Sum).Sum / 1GB).ToString("#.#"))


			$htmlHomePage=$htmlHomePage.replace("[ProcessCount]", $(Get-Process).count)
			$htmlHomePage=$htmlHomePage.replace("[RunningJobsCount]", $(get-job | Where {$_.State -eq "Running"}).Count)
			
			$htmlResponse+=$htmlHomePage
			
			#
			# Storage
			# 
			
			$htmlResponse+="<H1>Storage</H1>"
			$htmlHomePage=""
			# Find each volume
			Get-Volume | where {$_.DriveLetter -notlike ''} | Sort-Object DriveLetter | % {
				$volume = $(Get-Volume -DriveLetter $_.DriveLetter)
								
				$FreeSpace=[int]$($volume.SizeRemaining / 1GB)
				$FreePercent=$($volume.SizeRemaining / $volume.Size)*100
				# Apply KPIs
				Write-Debug "$FreePercent ($FreePercent -lt 10)"
				Write-Debug "$FreePercent ($FreePercent -in 10..20)"
				Write-Debug "$FreePercent ($FreePercent -gt 20)"
				switch ([int]$FreePercent) {
					{$_ -lt 10} { $Status="critical" }
					{$_ -in 10..20} { $Status="warning" }
					{$_ -gt 20} { $Status="good" }
				}
				Write-host "$($volume.DriveLetter) Drive Status $Status"
				$FreePercent=$FreePercent.toString("#.#")
				#$htmlHomePage+=$($htmlDrive.replace("[TotalFreeSpace]", "$FreeSpace GB" ).replace("[DriveLetter]", $_.DriveLetter))
				$htmlHomePage+=$($htmlDrive.replace("[TotalFreeSpace]", "$FreePercent %" ).replace("[DriveLetter]", $_.DriveLetter).replace("[Status]", $Status)) 
			}
			$htmlResponse+=$htmlHomePage
            # Send HTML response
            [byte[]]$buffer = [System.Text.Encoding]::UTF8.GetBytes($htmlResponse)
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
		    Write-Host "`nListing Default Options complete." -NoNewline
            $response.StatusCode = 200
            $response.StatusDescription = "OK"
            #$response.redirect("/vm/list")
            $response.Close()


            # Handle other requests
        }
    }
}

# Main loop to listen for incoming requests
while (!([console]::KeyAvailable)) {
    Write-host "." -NoNewline
    $context = $listener.GetContext() 
    Handle-Request $context
}

# Clean up
$listener.Stop()
$listener.Close()
remove-NetIPHttpsCertBinding
