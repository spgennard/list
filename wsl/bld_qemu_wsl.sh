sudo apt install aria2 bc dwarves aptitude libssl-dev
mkdir kernel
cd kernel/
curl -s https://api.github.com/repos/microsoft/WSL2-Linux-Kernel/releases/latest | jq -r '.name' | sed 's/$/.tar.gz/' | sed 's#^#https://github.com/microsoft/WSL2-Linux-Kernel/archive/refs/tags/#' | aria2c -i -
cd "$(find -type d -name "WSL2-Linux-Kernel-linux-msft-wsl-*")"
tar -xf *.tar.gz
cd "$(find -type d -name "WSL2-Linux-Kernel-linux-msft-wsl-*")"
cp Microsoft/config-wsl .config
sed -i 's/# CONFIG_KVM_GUEST is not set/CONFIG_KVM_GUEST=y/g' .config
sed -i 's/# CONFIG_ARCH_CPUIDLE_HALTPOLL is not set/CONFIG_ARCH_CPUIDLE_HALTPOLL=y/g' .config
sed -i 's/# CONFIG_HYPERV_IOMMU is not set/CONFIG_HYPERV_IOMMU=y/g' .config
sed -i '/^# CONFIG_PARAVIRT_TIME_ACCOUNTING is not set/a CONFIG_PARAVIRT_CLOCK=y' .config
sed -i '/^# CONFIG_CPU_IDLE_GOV_TEO is not set/a CONFIG_CPU_IDLE_GOV_HALTPOLL=y' .config
sed -i '/^CONFIG_CPU_IDLE_GOV_HALTPOLL=y/a CONFIG_HALTPOLL_CPUIDLE=y' .config
sed -i 's/CONFIG_HAVE_ARCH_KCSAN=y/CONFIG_HAVE_ARCH_KCSAN=n/g' .config
sed -i '/^CONFIG_HAVE_ARCH_KCSAN=n/a CONFIG_KCSAN=n' .config
diff Microsoft/config-wsl .config
make clean
make -j 8
find . -name bzImage -print
# powershell.exe /C 'Write-Output [wsl2]`nkernel=$env:USERPROFILE\bzImage | % {$_.replace("\","\\")} | Out-File $env:USERPROFILE\.wslconfig -encoding ASCII'
 #powershell.exe /C 'Copy-Item .\arch\x86\boot\bzImage $env:USERPROFILE'
  
