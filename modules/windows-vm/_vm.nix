# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# Builds the libvirt domain definition and the unattended installation media.
{
  pkgs,
  lib,
  accountName,
  memoryMiB,
  cores,
  threads,
  timeZone,
  inputLocale,
  productKey,
}: let
  esc = lib.escapeXML;
  name = "windows";
  imagesDir = "/var/lib/libvirt/images";
  diskPath = "${imagesDir}/windows.qcow2";
  installIsoPath = "${imagesDir}/windows-11.iso";
  nvramPath = "/var/lib/libvirt/qemu/nvram/windows_VARS.fd";
  ovmf = pkgs.OVMFFull.fd;

  # Setup assigns D: to the Windows ISO on the first SATA port and E: to this media.
  driverDirs = [
    "viostor"
    "vioscsi"
    "NetKVM"
    "Balloon"
    "vioserial"
    "viorng"
    "vioinput"
    "viogpudo"
    "qemufwcfg"
    "pvpanic"
  ];
  driverPaths =
    lib.concatImapStrings (i: dir: ''
      <PathAndCredentials wcm:action="add" wcm:keyValue="${toString i}">
        <Path>E:\${dir}\w11\amd64</Path>
      </PathAndCredentials>
    '')
    driverDirs;

  international = component: ''
    <component name="${component}" processorArchitecture="amd64"
      publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      ${lib.optionalString (component == "Microsoft-Windows-International-Core-WinPE") ''
      <SetupUILanguage>
        <UILanguage>en-US</UILanguage>
      </SetupUILanguage>
    ''}
      <InputLocale>${esc inputLocale}</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>
  '';

  firstLogonCommands =
    lib.concatImapStrings (i: command: ''
      <SynchronousCommand wcm:action="add">
        <Order>${toString i}</Order>
        <CommandLine>${esc command}</CommandLine>
      </SynchronousCommand>
    '') [
      # Drivers, QEMU guest agent and SPICE agent from the virtio-win bundle.
      ''cmd /c for %d in (D E F G H) do @if exist %d:\virtio-win-guest-tools.exe start "" /wait %d:\virtio-win-guest-tools.exe /install /quiet /norestart''
      "powercfg /hibernate off"
      "net accounts /maxpwage:unlimited"
    ];

  autounattend = pkgs.writeText "autounattend.xml" ''
    <?xml version="1.0" encoding="utf-8"?>
    <unattend xmlns="urn:schemas-microsoft-com:unattend"
      xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
      <settings pass="windowsPE">
        ${international "Microsoft-Windows-International-Core-WinPE"}
        <component name="Microsoft-Windows-PnpCustomizationsWinPE" processorArchitecture="amd64"
          publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
          <DriverPaths>
            ${driverPaths}
          </DriverPaths>
        </component>
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64"
          publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
          <Diagnostics>
            <OptIn>false</OptIn>
          </Diagnostics>
          <DynamicUpdate>
            <Enable>false</Enable>
            <WillShowUI>Never</WillShowUI>
          </DynamicUpdate>
          <DiskConfiguration>
            <WillShowUI>OnError</WillShowUI>
            <Disk wcm:action="add">
              <DiskID>0</DiskID>
              <WillWipeDisk>true</WillWipeDisk>
              <CreatePartitions>
                <CreatePartition wcm:action="add">
                  <Order>1</Order>
                  <Type>EFI</Type>
                  <Size>300</Size>
                </CreatePartition>
                <CreatePartition wcm:action="add">
                  <Order>2</Order>
                  <Type>MSR</Type>
                  <Size>16</Size>
                </CreatePartition>
                <CreatePartition wcm:action="add">
                  <Order>3</Order>
                  <Type>Primary</Type>
                  <Extend>true</Extend>
                </CreatePartition>
              </CreatePartitions>
              <ModifyPartitions>
                <ModifyPartition wcm:action="add">
                  <Order>1</Order>
                  <PartitionID>1</PartitionID>
                  <Label>System</Label>
                  <Format>FAT32</Format>
                </ModifyPartition>
                <ModifyPartition wcm:action="add">
                  <Order>2</Order>
                  <PartitionID>2</PartitionID>
                </ModifyPartition>
                <ModifyPartition wcm:action="add">
                  <Order>3</Order>
                  <PartitionID>3</PartitionID>
                  <Label>Windows</Label>
                  <Letter>C</Letter>
                  <Format>NTFS</Format>
                </ModifyPartition>
              </ModifyPartitions>
            </Disk>
          </DiskConfiguration>
          <ImageInstall>
            <OSImage>
              <InstallTo>
                <DiskID>0</DiskID>
                <PartitionID>3</PartitionID>
              </InstallTo>
              <InstallToAvailablePartition>false</InstallToAvailablePartition>
              <WillShowUI>OnError</WillShowUI>
            </OSImage>
          </ImageInstall>
          <UpgradeData>
            <Upgrade>false</Upgrade>
            <WillShowUI>Never</WillShowUI>
          </UpgradeData>
          <UserData>
            <AcceptEula>true</AcceptEula>
            <FullName>${esc accountName}</FullName>
            <ProductKey>
              <Key>${esc productKey}</Key>
              <WillShowUI>OnError</WillShowUI>
            </ProductKey>
          </UserData>
        </component>
      </settings>
      <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64"
          publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
          <ComputerName>windows-vm</ComputerName>
          <TimeZone>${esc timeZone}</TimeZone>
        </component>
      </settings>
      <settings pass="oobeSystem">
        ${international "Microsoft-Windows-International-Core"}
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64"
          publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
          <OOBE>
            <HideEULAPage>true</HideEULAPage>
            <HideLocalAccountScreen>true</HideLocalAccountScreen>
            <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
            <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
            <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
            <NetworkLocation>Home</NetworkLocation>
            <ProtectYourPC>3</ProtectYourPC>
            <SkipMachineOOBE>true</SkipMachineOOBE>
            <SkipUserOOBE>true</SkipUserOOBE>
          </OOBE>
          <UserAccounts>
            <LocalAccounts>
              <LocalAccount wcm:action="add">
                <Name>${esc accountName}</Name>
                <DisplayName>${esc accountName}</DisplayName>
                <Group>Administrators</Group>
                <Password>
                  <Value></Value>
                  <PlainText>true</PlainText>
                </Password>
              </LocalAccount>
            </LocalAccounts>
          </UserAccounts>
          <AutoLogon>
            <Enabled>true</Enabled>
            <LogonCount>1</LogonCount>
            <Username>${esc accountName}</Username>
            <Password>
              <Value></Value>
              <PlainText>true</PlainText>
            </Password>
          </AutoLogon>
          <FirstLogonCommands>
            ${firstLogonCommands}
          </FirstLogonCommands>
        </component>
      </settings>
    </unattend>
  '';

  # Windows Setup reads autounattend.xml from the root of any attached removable media.
  unattendIso =
    pkgs.runCommand "windows-vm-unattend.iso" {
      nativeBuildInputs = [pkgs.xorriso];
    } ''
      mkdir root
      # Only the Windows 11 x64 drivers and the standalone guest tools installer.
      for dir in ${lib.escapeShellArgs driverDirs}; do
        mkdir -p "root/$dir/w11"
        cp -r ${pkgs.virtio-win}/"$dir"/w11/amd64 "root/$dir/w11/"
      done
      cp ${pkgs.virtio-win}/virtio-win-guest-tools.exe root/
      chmod -R u+w root
      cp ${autounattend} root/autounattend.xml
      xorriso -as mkisofs -iso-level 3 -J -joliet-long -r -V WINVM_SETUP -o "$out" root
    '';

  domain = pkgs.writeText "windows-vm.xml" ''
    <domain type="kvm">
      <name>${name}</name>
      <uuid>1807f15e-aa5d-47d1-a3a8-781001e493c7</uuid>
      <title>Windows 11</title>
      <metadata>
        <libosinfo:libosinfo xmlns:libosinfo="http://libosinfo.org/xmlns/libvirt/domain/1.0">
          <libosinfo:os id="http://microsoft.com/win/11"/>
        </libosinfo:libosinfo>
      </metadata>
      <memory unit="MiB">${toString memoryMiB}</memory>
      <currentMemory unit="MiB">${toString memoryMiB}</currentMemory>
      <vcpu placement="static">${toString (cores * threads)}</vcpu>
      <os>
        <type arch="x86_64" machine="q35">hvm</type>
        <loader readonly="yes" secure="yes" type="pflash">${ovmf}/FV/OVMF_CODE.ms.fd</loader>
        <nvram template="${ovmf}/FV/OVMF_VARS.ms.fd">${nvramPath}</nvram>
      </os>
      <features>
        <acpi/>
        <apic/>
        <hyperv mode="custom">
          <relaxed state="on"/>
          <vapic state="on"/>
          <spinlocks state="on" retries="8191"/>
          <vpindex state="on"/>
          <runtime state="on"/>
          <synic state="on"/>
          <stimer state="on">
            <direct state="on"/>
          </stimer>
          <reset state="on"/>
          <frequencies state="on"/>
          <reenlightenment state="on"/>
          <tlbflush state="on"/>
          <ipi state="on"/>
        </hyperv>
        <vmport state="off"/>
        <smm state="on"/>
      </features>
      <cpu mode="host-passthrough" check="none" migratable="on">
        <topology sockets="1" dies="1" cores="${toString cores}" threads="${toString threads}"/>
      </cpu>
      <clock offset="localtime">
        <timer name="rtc" tickpolicy="catchup"/>
        <timer name="pit" tickpolicy="delay"/>
        <timer name="hpet" present="no"/>
        <timer name="hypervclock" present="yes"/>
      </clock>
      <on_poweroff>destroy</on_poweroff>
      <on_reboot>restart</on_reboot>
      <on_crash>destroy</on_crash>
      <pm>
        <suspend-to-mem enabled="no"/>
        <suspend-to-disk enabled="no"/>
      </pm>
      <devices>
        <emulator>/run/libvirt/nix-emulators/qemu-system-x86_64</emulator>
        <disk type="file" device="disk">
          <driver name="qemu" type="qcow2" cache="none" io="native" discard="unmap"/>
          <source file="${diskPath}"/>
          <target dev="vda" bus="virtio"/>
          <boot order="1"/>
        </disk>
        <disk type="file" device="cdrom">
          <driver name="qemu" type="raw"/>
          <source file="${installIsoPath}" startupPolicy="optional"/>
          <target dev="sda" bus="sata"/>
          <readonly/>
          <boot order="2"/>
        </disk>
        <disk type="file" device="cdrom">
          <driver name="qemu" type="raw"/>
          <source file="${unattendIso}"/>
          <target dev="sdb" bus="sata"/>
          <readonly/>
        </disk>
        <controller type="usb" model="qemu-xhci" ports="15"/>
        <interface type="network">
          <source network="default"/>
          <model type="virtio"/>
        </interface>
        <input type="tablet" bus="usb"/>
        <graphics type="spice" autoport="yes">
          <listen type="address" address="127.0.0.1"/>
          <image compression="off"/>
        </graphics>
        <audio id="1" type="spice"/>
        <sound model="ich9">
          <audio id="1"/>
        </sound>
        <video>
          <model type="virtio" heads="1" primary="yes"/>
        </video>
        <channel type="spicevmc">
          <target type="virtio" name="com.redhat.spice.0"/>
        </channel>
        <channel type="unix">
          <target type="virtio" name="org.qemu.guest_agent.0"/>
        </channel>
        <redirdev bus="usb" type="spicevmc"/>
        <redirdev bus="usb" type="spicevmc"/>
        <tpm model="tpm-crb">
          <backend type="emulator" version="2.0"/>
        </tpm>
        <memballoon model="virtio"/>
        <rng model="virtio">
          <backend model="random">/dev/urandom</backend>
        </rng>
      </devices>
    </domain>
  '';
in {
  inherit name imagesDir diskPath installIsoPath autounattend unattendIso domain;
}
