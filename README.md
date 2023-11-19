# PLATFORM-RK3399
## Prerequisites for building with Armbian for Volumio platform files

- x86_64 or aarch64 machine with at least 2GB of memory and >= 35GB of disk space for a virtual machine, WSL2, container or bare metal installation.  
- Ubuntu Jammy 22.04.x amd64 for native building.  
- Superuser rights (configured sudo or root access).  
- Make sure all your system components are up-to-date.  

## How to build the Armbian kernel and u-boot for Volumio?

Download the armbian build system (example rockchip64, but any local name is valid)
```
sudo apt-get install git
git clone https://github.com/armbian/build armbian-rockchip64
```

Download the platform-folder, when existing.
Otherwise create a new platform-folder, using an existing one as a template.
Then adapt script <platform-folder>mkplatform.sh to your needs.
```
git clone http://github.com/volumio/platform-rk3399
```

### (Re-)Generating the platform files

Start the build script
```
cd platform-rk3399
cd /mkplatform.sh
```

This will download all further prerequisites.  
Once finished downloading and all patches have been applied, you get the opportunity to add your own local patches.  
(mkplatform.sh prerequisite: KERNELPATH="yes").

Once finmished local patching the kernel configuration can be modified.
(mkplatform.sh prerequisite: KERNELCONFIGURE="yes").


## Changelog


  
|Date|Author|Change
|---|---|---|
|20211216|gkkpch|Initial
|20220112|gkkpch|Finished kernel buildscript
|20220121|gkkpch|Switched to ```rk3399-nanopi-m4b.dtb```
|||Kernel 5.10.93, switched kernel configuration
|||Added kernel bluetooth support
|||Added ```bcrm_patchram_plus``` and ```rk3399-bluetooth.service``` 
|||Abandoned
|20230229|gkkpch|Revived with kernel 5.15,y, fixed alsa & bluetooth issues
|20231110|gkkpch|Refactored with Armbian integration and script ```mkplatform.sh```. 
|||Kernel version 6.1
|20231111|gkkpch|Fix "./compile.sh kernel-patch" processing
