param(
    [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
    [bool]$DownloadArtifacts=$true
)


# default script values 
$taskName = "task5"

$artifactsConfigPath = "$PWD/artifacts.json"
$resourcesTemplateName = "exported-template.json"
$tempFolderPath = "$PWD/temp"

if ($DownloadArtifacts) { 
    Write-Output "Reading config" 
    $artifactsConfig = Get-Content -Path $artifactsConfigPath | ConvertFrom-Json 

    Write-Output "Checking if temp folder exists"
    if (-not (Test-Path "$tempFolderPath")) { 
        Write-Output "Temp folder does not exist, creating..."
        New-Item -ItemType Directory -Path $tempFolderPath
    }

    Write-Output "Downloading artifacts"

    if (-not $artifactsConfig.resourcesTemplate) { 
        throw "Artifact config value 'resourcesTemplate' is empty! Please make sure that you executed the script 'scripts/generate-artifacts.ps1', and commited your changes"
    } 
    Invoke-WebRequest -Uri $artifactsConfig.resourcesTemplate -OutFile "$tempFolderPath/$resourcesTemplateName" -UseBasicParsing

}

Write-Output "Validating artifacts"
$TemplateFileText = [System.IO.File]::ReadAllText("$tempFolderPath/$resourcesTemplateName")
$TemplateObject = ConvertFrom-Json $TemplateFileText -AsHashtable

$virtualMachine = ( $TemplateObject.resources | Where-Object -Property type -EQ "Microsoft.Compute/virtualMachines" )
if ($virtualMachine) {
    if ($virtualMachine.name.Count -eq 1) { 
        Write-Output "`u{2705} Checked if Virtual Machine exists - OK."
    }  else { 
        Write-Output `u{1F914}
        throw "More than one Virtual Machine resource was found in the VM resource group. Please delete all un-used VMs and try again."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to find Virtual Machine in the task resource group. Please make sure that you created the Virtual Machine and try again."
}

if ($virtualMachine.location -ne "uksouth" ) { 
    Write-Output "`u{2705} Checked Virtual Machine location - OK."
} else { 
    Write-Output `u{1F914}
    throw "Virtual is not deployed to the UK West region. Please migrate VM to another region and try again."
}

$pip = ( $TemplateObject.resources | Where-Object -Property type -EQ "Microsoft.Network/publicIPAddresses")
if ($pip) {
    if ($pip.name.Count -eq 1) { 
        Write-Output "`u{2705} Checked if the Public IP resource exists - OK"
    }  else { 
        Write-Output `u{1F914}
        throw "More than one Public IP resource was found in the VM resource group. Please delete all un-used Public IP address resources and try again."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to find Public IP address resouce. Please make sure that is was migrated and try again."
}

if ($pip.properties.dnsSettings.domainNameLabel) { 
    Write-Output "`u{2705} Checked Public IP DNS label - OK"
} else { 
    Write-Output `u{1F914}
    throw "Unable to verify the Public IP DNS label. Please create the DNS label for your public IP and try again."
}


$nic = ( $TemplateObject.resources | Where-Object -Property type -EQ "Microsoft.Network/networkInterfaces")
if ($nic) {
    if ($nic.name.Count -eq 1) { 
        Write-Output "`u{2705} Checked if the Network Interface resource exists - OK"
    }  else { 
        Write-Output `u{1F914}
        throw "More than one Network Interface resource was found in the VM resource group. Please delete all un-used Network Interface resources and try again."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to find Network Interface resouce. Please make sure it was migrated to the correct resource group and try again."
}

if ($nic.properties.ipConfigurations.Count -eq 1) { 
    if ($nic.properties.ipConfigurations.properties.publicIPAddress -and $nic.properties.ipConfigurations.properties.publicIPAddress.id) { 
        Write-Output "`u{2705} Checked if Public IP assigned to the VM - OK"
    } else { 
        Write-Output `u{1F914}
        throw "Unable to verify Public IP configuratio for the VM. Please make sure that IP configuration of the VM network interface has public IP address configured and try again."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to verify IP configuration of the Network Interface. Please make sure that you have 1 IP configuration of the VM network interface and try again."
}


$nsg = ( $TemplateObject.resources | Where-Object -Property type -EQ "Microsoft.Network/networkSecurityGroups")
if ($nsg) {
    if ($nsg.name.Count -eq 1) { 
        Write-Output "`u{2705} Checked if the Network Security Group resource exists - OK"
    }  else { 
        Write-Output `u{1F914}
        throw "More than one Network Security Group resource was found in the VM resource group. Please delete all un-used Network Security Group resources and try again."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to find Network Security Group resouce. Please re-deploy the VM and try again."
}

$sshNsgRule = ( $nsg.properties.securityRules | Where-Object { ($_.properties.destinationPortRange -eq '22') -and ($_.properties.access -eq 'Allow')} ) 
if ($sshNsgRule)  {
    Write-Output "`u{2705} Checked if NSG has SSH network security rule configured - OK"
} else { 
    Write-Output `u{1F914}
    throw "Unable to fing network security group rule which allows SSH connection. Please check if you configured VM Network Security Group to allow connections on 22 TCP port and try again."
}

$httpNsgRule = ( $nsg.properties.securityRules | Where-Object { ($_.properties.destinationPortRange -eq '8080') -and ($_.properties.access -eq 'Allow')} ) 
if ($sshNsgRule)  {
    Write-Output "`u{2705} Checked if NSG has HTTP network security rule configured - OK"
} else { 
    Write-Output `u{1F914}
    throw "Unable to fing network security group rule which allows HTTP connection. Please check if you configured VM Network Security Group to allow connections on 8080 TCP port and try again."
}

$response = (Invoke-WebRequest -Uri "http://$($pip.properties.dnsSettings.fqdn):8080/api/" -ErrorAction SilentlyContinue) 
if ($response) { 
    Write-Output "`u{2705} Checked if the web application is running - OK"
} else {
    throw "Unable to get a reponse from the web app. Please make sure that the VM and web application are running and try again."
}

Write-Output ""
Write-Output "`u{1F973} Congratulations! All tests passed!"
