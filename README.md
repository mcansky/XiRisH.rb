# Thor script to create xen VMs

## About

The main point is to have a one line command to create a full featured domU system on a Debian dom0 system. At the moment no "classes" of systems are used, you need to tweak the config file for that, but it's definitely in the todo list.

This script is based on a based script a friend of mine was using (https://github.com/ziirish). Since I want to use it with some other Ruby code I've migrated the idea from bash to Ruby/Thor. As you can guess, it adds dependencies but for my needs it's ok (since I'll have Ruby and Thor installed anyway) and it also adds nice bonus points because of Thor and Ruby.

As this work is heavily based on ziirish's : thanks mate for doing such a brilliant job !

## Install

1. Get the config and rb file.
2. Install thor : gem install thor. I suggest you to use rvm (see dependencies).
3. Edit the config.yml to your needs
4. Chmod : chmod +x genvm.rb

## Quick Run

    ./genvm.rb create <vm_name> --version="squeeze64" --ip="10.0.0.2" --storage="<vg_name>"

The version you can use are : lenny, squeeze32 and squeeze64, default is squeeze64. The script is using debootstrap to create the vm. The storage is expected to be a LVM logical volume. Pass the name of the desired volume group.

About the network you probably need to check the config.yml file to set the gateway, for the ip well change it accordingly to your needs.

## More about options

There are 7 options available. Some are needed, some are not. Some are silly, some are a bit less silly.

  * ip : *needed*, ip address. __The gateway is specified in the config.yml file__.
  * storage : *needed*, the lvm volume where you want to create the swap and root fs. __The sizes of those spaces are defined in the config.yml file.__
  * version : *optionnal*, the version of debian you want to use. You can pass either : lenny, squeeze32 or squeeze64. __squeeze64 is default and set if that option is not passed.__
  * no_install : *optionnal*, silly. Default : false.
  * silent : *optionnal*, silence Thor system calls. If passed then you will only see the green, yellow and red lines of the Thor script and no lines from the os command that are being runned. Default : false.
  * packages : *optionnal*, at the moment the only way to pass packages to be installed is through script editing, soon to be changed with classes, but until then you can pass this option to tell the script to install thoses packages you've added. Default : false.
  * bare : *optionnal*, handy if you just want a bare system to be installed. Default : false.

## Dependencies

1. Thor : https://github.com/wycats/thor
2. Rvm (optionnal) : http://rvm.beginrescueend.com

You might want to read : https://github.com/wycats/thor to debug or do stuff around with it.

## Fork it

If you have any suggestions or ideas, or just need to adapt the script to your needs make a fork on github : https://github.com/mcansky/XiRisH.rb . You can report issues and make pull request through this mean too.