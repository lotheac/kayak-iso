Using Kayak
===========

Building
--------

 * Set PKGURL to be the source of the OmniOS bits we wish to install with
   kayak, in case it's not the default "omnios" publisher for whatever release
   branch you have checked out.

 * zfs create rpool/kayak_image
 * gmake BUILDSEND=rpool/kayak_image

Operation
---------

DHCP server:
 * your server should be set to PXE boot
 * the DHCP server must return and IP, a nextserver and a bootfile
 * the boot file should be the file {{{/boot/grub/pxegrub}}} or {{{/boot/pxeboot}}} from an existing OmniOS system

TFTP server:
 * menu.lst.01<macaddr_just_hex_caps> based on the template provided in this directory should be placed in /tftpboot/ if using grub, or put loader.conf.local in /tftpboot/boot
 * /boot/grub/pxegrub or /boot/pxeboot should be placed in /tftpboot/
 * /platform/i86pc/kernel/amd64/unix should be placed in /tftpboot/omnios/kayak/
 * the miniroot.gz file should be placed in /tftpboot/omnios/kayak/

HTTP server:
 * The system install images should be placed an accessible URL
 * The target system kayak config should be placed at a URL path with the filename <macaddr_just_hex_caps>

