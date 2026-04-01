param (
    [string]$HelmTimeout,
    [string]$HelmvaluePath,
    [string]$Namespace,
    [string]$Applicationname,
    [string]$Chart_name,
    [string]$Chart_version,
    [string]$ImageValue,
    [string]$BuildNumber
)
Write-Host "Helm Value Path : "$HelmvaluePath
Write-Host "Namespace : "$Namespace
Write-Host "Applicationname:" $Applicationname
Write-Host "Chart_name:" $Chart_name
Write-Host "Chart_version:" $Chart_version
Write-Host "ImageValue:" $ImageValue
Write-Host "HelmTimeout:" $HelmTimeout
Write-Host "BuildNumber:" $BuildNumber
helm upgrade --install --wait --timeout $HelmTimeout $Applicationname oci://azcontainerregistryprod.azurecr.io/helm/$Chart_name --version $chart_version --values $HelmvaluePath --namespace $Namespace