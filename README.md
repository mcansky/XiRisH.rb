# Thor script to create xen VMs

## Install

1. Get the config and rb file.
2. Install thor : gem install thor. I suggest you to use rvm (see dependencies).
3. Edit the config.yml to your needs
4. Chmod : chmod +x genvm.rb

## Run

    ./genvm.rb create <vm_name> --version="squeeze64" --ip="10.0.0.2" --storage="<vg_name>"

The version you can use are : lenny, squeeze32 and squeeze64, default is squeeze64. The script is using debootstrap to create the vm. The storage is expected to be a LVM logical volume. Pass the name of the desired volume group.

About the network you probably need to check the config.yml file to set the gateway, for the ip well change it accordingly to your needs.

## Dependencies

1. Thor : https://github.com/wycats/thor
2. Rvm (optionnal) : http://rvm.beginrescueend.com

You might want to read : https://github.com/wycats/thor to debug or do stuff around with it.

## Fork it

If you have any suggestions or ideas, or just need to adapt the script to your needs make a fork on github : https://github.com/mcansky/XiRisH.rb . You can report issues and make pull request through this mean too.