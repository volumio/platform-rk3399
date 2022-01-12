
## Prerequisites for building with Armbian

- x64 machine with at least 2GB of memory and ~35GB of disk space for a VM, container or native OS,
- Ubuntu Hirsute 21.04 x64 for native building or any [Docker](https://docs.armbian.com/Developer-Guide_Building-with-Docker/) capable x64 Linux for containerised,
  - Hirsute is required for newer non-LTS releases.. ex: Bullseye, Sid, Groovy, Hirsute
  - If building for LTS releases.. ex: Focal, Bionic, Buster, it is possible to use Ubuntu 20.04 Focal, but it is not supported
- superuser rights (configured sudo or root access).

## How to build the Armbian kernel and u-boot for Volumio?

Download the armbian build system
```
sudo apt-get install git
git clone https://github.com/armbian/build armbian-volumio
```
Prepare the customized build script
```
cd armbian-volumio
cat <<-EOF > compile-custom-nanopim4.sh
sudo ./compile.sh  BOARD=nanopim4 BRANCH=current KERNEL_ONLY=yes KERNEL_CONFIGURE=yes KERNEL_KEEP_CONFIG=yes CREATE_PATCHES=yes
EOF
sudo chmod +x compile-custom-nanopim4.sh
cd ..
git clone https://github.com/gkkpch/platform-rk3399
cd platform-rk3399
tar xfJ nanopim4.tar.xz
cd ..
```

## Start u-boot and kernel configurations
```
cd armbian-volumio
./compile-custom-nanopim4.sh
```
This will download all further prerequisites.  
Once finished downloading and all patches have been applied, you get the opportunity to add your own patches (valid both for u-boot and kernel).  

The first patch break is before compiling u-boot, now modify the sources in *armbian-volumio/output/cache/sources/u-boot/*.  
After you have done the modifications (or don't have any) press \<Enter>.  

The next patch break will be before compiling the kernel.  
**Important:**  
With the very first compile, you need to 
- copy ```linux-rockchip64-current.config``` from *platform-rk3399/nanopim4/armbian* to *armbian-volumio/output/config*.
- copy ```rk3399-nanopi-m4b.dts``` from *platform-rk3399/nanopim4/armbian* to *armbian-volumio/output/cache/linux-mainline/linux-5.x.y/arch/arm64/boot/dts/rockchip*
- modify ```Makefile``` in *armbian/output/cache/sources/linux-mainline/linux-5.x.y/arch/arm64/boot/dts/rockchip* to compile the new dts.  

After you have done any other modifications in *output/cache/sources/linux-mainline/linux-5.x.y* (or don't have any) press \<Enter>.  
==> You will find your patches here: *armbian-volumio/output/patch/kernel-rockchip64-current.patch*, it is incremental.

Next step is Kernel Configuration, just <exit> when you do not want to modify anything.  
**Note 1:** Modified kernel settings will be saved for the next build.  
**Note 2:** When you want to keep a backup of kernel configurations and patches, copy them from *armbian/output/patch/* and *armbian/output/config*  

## Recompiling

Restart the u-boot and kernel compilation.  
```
./compile-custom-nanopim4.sh
```
This time you only pay attention to the 2 patch breaks and the kernel config.
Ignore them when there are no changes.



## When finished

Move the following .deb packages from *armbian/output/debs* to *platform-rk3399/nanopim4/*
```
armbian-firmware_x.y.z-trunk_all.deb
linux-headers-current-rockchip64_x.y.z-trunk_arm64.deb
linux-image-current-rockchip64_x.y.z-trunk_arm64.deb
linux-u-boot-current-nanopim4_x.y.z-trunk_arm64.deb
```
Where x.y.z is the used armbian version.  
(At the time of writing 21.11.0)  
Refer to ```armbian-firmware-full_x.y.z-trunk_all.deb``` for a full copy of all current firmware for 5.x.y  

## Generating platform files

This will be part of the nanopim4 build recipe.  
It will unpack firmware, image and u-boot debs and put the information straight into the right place.


