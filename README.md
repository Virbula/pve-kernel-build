# Virbula pve-kernel-build
Automated PVE Kernel Build With Docker Containers, used by the Virbula team for building and customizing the PVE Kernel for experimentation.

Important Note: You need to make sure you docker instance provides enough disk space for the container.  On Docker Desktop, this is a resource limit setting you can set in the Settings configuration section. 

# License

AGPL v3.0 license, open source as Proxmox PVE license. 


# Steps

## 1. Build the docker container image used to compile the PVE Kernel source

* make build

or 

* make container

## 2. Prepare the build directory and install build-dependencies in the build directory 

* make prep

It essentially does the following things:
* clones the git repos into a docker volume
* make build-dir-refresh
* mk-build-deps -ir BUILD-DIR/debian/control

which creates the build directory,  and install build-dependencies in the actual build directory 
created in the first step.  You have to replace the BUILD-DIR with the actual build directory name.
The make file automates that to use the first directory found, which is correct most of the time. 



## 3. Build the actual .deb kernel packages, including the kernel and the header packages.

* make kernel 

It runs make deb in the pve-kernel directory after the preps are done. 


## 4. Make clean all and rebuild

You can clean up the tree, and rebuild the kernel as needed.  


