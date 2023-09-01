Get-VMHost | Select Name,PowerState, Version,@{N="ManagementIP"; E={Get-VMHostNetworkAdapter -VMHost $_ -VMKernel | ?{$_.ManagementTrafficEnabled} | %{$_.Ip}}},LicenseKey,  @{N='LicenseName';E={$vmhostLM.AssignedLicense.Name | Select-Object -Unique}},@{N='ExpirationDate';E={$_.AssignedLicense.Properties.where{$_.Key -eq 'expirationDate'}.Value }},

    Build,

    @{N="Cluster Name";E={($_ | Get-Cluster).Name}},@{N="Datacenter";E={$datacenter.Name}},

    Manufacturer, Model, ProcessorType,@{Name="SerialNumber";Expression={$esx.ExtensionData.Hardware.SystemInfo.OtherIdentifyingInfo |Where-Object {$_.IdentifierType.Key -eq "Servicetag"} |Select-Object -ExpandProperty IdentifierValue}},

    @{N="NumCPU";E={($_| Get-View).Hardware.CpuInfo.NumCpuPackages}},

    @{N="Cores";E={($_| Get-View).Hardware.CpuInfo.NumCpuCores}},

    @{N="Service Console IP";E={($_|Get-VMHostNetwork).ConsoleNic[0].IP}},

    @{N="vMotion IP";E={($_|Get-VMHostNetwork).VirtualNic[0].IP}},

    @{N="HBA count";E={($_| Get-VMHostHba | where {$_.Type -eq "FibreChannel"}).Count}},

    @{N="DatastoreName(Capacity in GB)";E={[string]::Join(",",( $ _| Get-Datastore | %{$_.Name + "(" + ("{0:f1}" -f ($_.CapacityMB/1KB)) + ")"}))}},

    @{N="FC Device";E={[string]::Join(",",(($ _| Get-View).Config.StorageDevice.HostBusAdapter | where{$_.GetType().Name -eq "HostFibreChannelHba"} | %{$_.Device}))}},

    @{N="FC WWN";E={[string]::Join(",",(($ _| Get-View).Config.StorageDevice.HostBusAdapter | where{$_.GetType().Name -eq "HostFibreChannelHba"} | %{"{0:x}" -f $_.NodeWorldWideName}))}},

    @{N="Physical NICS count";E={($_ | Get-View).Config.Network.Pnic.Count}},

    @{N="vSwitches(Number of Ports)";E={[string]::Join(",",( $ _| Get-VirtualSwitch | %{$_.Name + "(" + $_.NumPorts + ")"}))}},

    @{N="Portgroups";E={[string]::Join(",",( $ _| Get-VirtualPortGroup | %{$_.Name}))}},

    @{N="pNIC MAC";E={[string]::Join(",",($ _| Get-VMHostNetworkAdapter | %{$_.MAC}))}},

    @{N="SC Mem (MB)";E={"{0:f1}" -f (($_| Get-View).Config.ConsoleReservation.ServiceConsoleReserved/1MB)}},

    @{N='vCenter';E={$_.Uid.Split('@')[1].Split(':')[0]}},

    @{N='DNS Server(s)';E={$_.Extensiondata.Config.Network.DnsConfig.Address -join ' , '}},

    @{N='Time';E={(Get-View -Id $_.ExtensionData.ConfigManager.DatetimeSystem).QueryDateTime()}},

    @{N="NTPServer";E={$_ |Get-VMHostNtpServer}}, @{N="ServiceRunning";E={(Get-VmHostService -VMHost $_ | Where-Object {$_.key-eq "ntpd"}).Running}},

    @{N='InstallationDate';E={
 

        $script:esxcli = Get-EsxCli -VMHost $_

        $epoch = $script:esxcli.system.uuid.get().Split('-')[0] 

        [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds([int]"0x$($epoch)"))}},
 

    @{N='UpgradeDate';E={

        $script:esxcli.software.vib.list()  | where{$_.Name -eq 'esx-base'} | select -ExpandProperty InstallDate 

    }},@{N="LockDown";E={$_.Extensiondata.Config.adminDisabled}},

   @{N="SyslogServer";E={$_ |Get-VMHostSyslogServer}},

    @{N = 'HostFQDN'; E = {$esxcli.system.hostname.get.Invoke().FullyQualifiedDomainName}},

    @{N = 'CoreDumpConfigured'; E = {if ($_.Configured) {$_.Configured} else {'None'}}},

    @{N='pNIC';E={(Get-VMHostNetworkAdapter -Physical -VMHost $_).Name -join '|'}},

    @{N = 'linkspeed';E={$spec=Get-VMHostNetworkAdapter -VMHost $_$spec.extensiondata.linkspeed.speedMb -join '|'}},

    @{N="Uptime"; E={New-Timespan -Start $_.ExtensionData.Summary.Runtime.BootTime -End (Get-Date) | Select -ExpandProperty Days}},

    @{N="Last Boot (UTC)";E={$_.ExtensionData.Summary.Runtime.BootTime}},

   @{N="Last Boot (Locale)";E={Convert-UTCtoLocal -UTCTime $_.ExtensionData.Sumary.Runtime.BootTime}},

@{N='PCLI';E={(Get-AdvancedSetting -Entity $_ -Name 'VSAN.ClomRepairDelay').Value}},

  @{N='Scratch';E={(Get-AdvancedSetting -Entity $_ -Name 'ScratchConfig.ConfiguredScratchLocation').Value}},

  @{N='Log';E={(Get-AdvancedSetting -Entity $_ -Name 'Syslog.global.logDir').Value}},

  @{N="HostUUID";E={$_.ExtensionData.hardware.systeminfo.uuid}},

  @{N="HT Available";E={($_).HyperthreadingActive}},

  @{N="HT Active";E={($_ | get-view).Config.HyperThread.Active}},

  @{N=“Speed“;E={"" + [math]::round(($_| get-view).Hardware.CpuInfo.Hz / 1000000, 0)}},

  @{N=“Memory GB“;E={“” + [math]::round(($_| get-view).Hardware.MemorySize / 1GB, 0) + “ GB“}},

  @{ N="CurrentPolicy"; E={$_.ExtensionData.config.PowerSystemInfo.CurrentPolicy.ShortName}},

  @{N="Power Policy";E={$powSys = Get-View $_.ExtensionData.ConfigManager.PowerSystem

  $powSys.Info.CurrentPolicy.ShortName }},

  @{N = 'OverallStatus'; E = {$_.ExtensionData.OverallStatus}},

@{N="DNS suffixes";E={[string]::Join(",", ($esxcli.network.ip.dns.search.list() | %{$_.DNSSearchDomains}))}},

@{N='Power';E={(Get-AdvancedSetting -Entity $_ -Name 'Power.CpuPolicy').Value}}
