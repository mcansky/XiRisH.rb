#!/usr/bin/env ruby
# the tool to create VMs
require "rubygems" # ruby1.9 doesn't "require" it though
require "thor"
require 'yaml'

class JesterSmith < Thor
  include Thor::Actions

  desc "install_deb", "Install Debian Package"
  def install_deb(name)
    say "Installing Debian package #{name} to #{@build_dir}", :green
    run("DEBIAN_FRONTEND=noninteractive chroot #{@build_dir} /usr/bin/apt-get --yes --force-yes install #{name}", {:verbose => @verbose)
  end

  desc "chroot_run", "Run a command in the chrooted env"
  def chroot_run(cmd)
    say "Running command : #{cmd} in #{@build_dir}", :green
    run("chroot #{@build_dir} #{cmd}")
  end

  def install(name, version, ip, storage)
    # creating dirs
    FileUtils.mkdir_p(@log_dir)
    FileUtils.mkdir_p(@build_dir)

    # creating the fs
    say "Creating filesystem #{name} on #{storage}", :green
    run("lvcreate -L#{@lv_size} -n #{name} #{storage}", {:verbose => @verbose})
    # creating the swap
    say "Creating swap #{for_line}", :green
    run("lvcreate -L#{@lv_swap_size} -n swap_#{name} #{storage}", {:verbose => @verbose})
    # making the fs
    say "Mkfs filesystem #{for_line}", :green
    run("mkfs -t ext4 /dev/#{storage}/#{name}")
    # mkfs swap
    say "Mkfs swap #{for_line}", :green
    run("mkswap /dev/#{storage}/swap_#{name}")
    # mount new fs
    say "Mounting #{name} fs in build dir", :green
    run("mount /dev/#{storage}/#{name} #{@build_dir}", {:verbose => @verbose})

    # debootstrap
    versions = ["lenny", "squeeze32", "squeeze64"]
    raise ArgumentError, "version not known" if !versions.include?(version)
    case
      when version == "lenny"
        @arch = "amd64"
        @kernel = "linux-image-2.6-xen-amd64"
        @base = "lenny"
      when version == "squeeze32"
        @arch = "i386"
        @kernel = "linux-image-2.6-686-bigmem"
        @base = "squeeze"
      when version == "squeeze64"
        @arch = "amd64"
        @kernel = "linux-image-2.6-amd64"
        @base = "squeeze"
    end
    # running the debootstrap
    say "Deboostraping #{name} as #{version}", :green
    run("debootstrap --arch=#{@arch} --components=main,contrib,non-free --include=#{@kernel} #{@base} #{@build_dir} #{@mirror}", {:verbose => @verbose})
  end

  #argument :name, :type => :string, :required => true
  #argument :ip, :type => :string, :required => true
  #argument :storage, :type => :string, :required => true
  #argument :version, :type => :string, :default => "squeeze64"
  desc "create", "Create a new vm"
  method_options :ip => :string, :storage => :string, :version => "squeeze64", :no_install => false
  def create(name)
    #argument :name, :type => :string, :desc => "the name of the vm", :required => true
    #argument :version, :type => :string, :desc => "the version of debian you want to use", :required => true
    #argument :ip, :type => :string, :desc => "the ip address you want the vm to use", :required => true
    #argument :storage, :type => :string, :desc => "the storage vg you want to use", :required => true
    #desc "Create a new Xen VM"

    say "Starting the script with options :\n\tname : #{name}\n\tversion : #{options[:version]}\n\tip : #{options[:ip]}\n\tstorage : #{options[:storage]}\n"

    # loading some vars
    config = YAML::load( File.open( "config.yml" ) )
    tools = ["lvcreate","mkfs","mount","debootstrap","mkdir","cat","dd","mkswap","echo"]
    n_name = name.gsub(/\s/, '_')
    name = name.downcase
    version = options[:version].downcase
    storage = options[:storage]
    ip = options[:ip]
    @build_dir = config["build_dir"]
    @log_dir = config["log_dir"]
    @verbose = true
    @verbose = false if config["verbose"] == 0
    @noinstall = options[:no_install]
    @lv_size = config["lv_size"]
    @lv_swap_size = config["lv_swap_size"]
    # default args aka squeeze 64
    @arch = "amd64"
    @kernel = "linux-image-2.6-amd64"
    @base = "squeeze"
    @mirror = config["mirror"]
    for_line = "for #{name} on #{storage}"
    if config["dummy"] == 1
      say "WARNING : Dummy mode !", :red
      config["build_dir"] = "/tmp/jester"
      config["log_dir"] = "/tmp/jester_log"
    end

    if !@noinstall
      install(n_name, version, ip, storage)
    else
      # mount fs
      say "Mounting #{name} fs in build dir", :green
      run("mount /dev/#{storage}/#{name} #{@build_dir}", {:verbose => @verbose})
    end

    # creating storage for kernels
    say "Creating kernel storage for #{name}", :green
    FileUtils.mkdir_p("/home/xen/domu/#{name}/kernel")
    # copying kernel files
    say "Copying kernel and initrd for #{name}", :green
    vmlinuz_file = Dir.glob("#{config["build_dir"]}/boot/vmlinuz-*").first
    initrd_file = Dir.glob("#{config["build_dir"]}/boot/initrd*").first
    run("cp #{vmlinuz_file} /home/xen/domu/#{name}/kernel/", {:verbose => @verbose})
    run("cp #{initrd_file} /home/xen/domu/#{name}/kernel/", {:verbose => @verbose})
    # storing the names
    vmlinuz_file = Dir.glob("/home/xen/domu/#{name}/kernel/vmlinuz*").first
    initrd_file = Dir.glob("/home/xen/domu/#{name}/kernel/initrd*").first

    # generating xen config["file"]
    xenconf = <<-EOF
      kernel = #{vmlinuz_file}
      ramdisk= #{initrd_file}
      memory = 512
      name = '#{name}'
      vif = [ 'ip=#{ip}' ]
      disk = [
          'phy:/dev/#{storage}/#{name},xvda1,w',
          'phy:/dev/#{storage}/swap_#{name},xvda2,w'
      ]
      root = '/dev/xvda1 ro'
      console = 'hvc0'
    EOF
    # removing white chars at start of lines
    xenconf.gsub!(/^\s*/,'')
    # creating the config file
    say "Creating xenconf file for #{name}", :green
    create_file "/etc/xen/xen.d/#{name}.cfg", xenconf

    # generating network config file
    network_conf = <<-EOF
    interfaces="auto lo
    iface lo inet loopback
  
    auto eth0
    iface eth0 inet static
            address #{ip}
            gateway #{config["gateway"]}
            netmask 255.255.255.0"
    EOF
    network_conf.gsub!(/^\s*/,'')
    # creating the config file
    say "Creating network file for #{name}", :green
    create_file "#{config["build_dir"]}/etc/network/interfaces", network_conf

    # creating the fstab file
    fstab_file = <<-EOF
      /dev/xvda1      /                   ext3        defaults        0       1
      /dev/xvda2      none                swap        defaults        0       0
      proc            /proc               proc        defaults        0       0
    EOF
    fstab_file.gsub!(/^\s*/,'')
    # creating the fstab file
    say "Creating fstab file for #{name}", :green
    create_file "#{config["build_dir"]}/etc/fstab", fstab_file

    # adding line to inittab
    say "Adding hvc0 line to inittab for #{name}", :green
    prepend_to_file "#{config["build_dir"]}/etc/inittab", "hvc0:23:respawn:/sbin/getty 38400 hvc0"

    # hostname
    say "Creating hostname file for #{name}", :green
    create_file "#{config["build_dir"]}/etc/hostname", name

    # sources for apt
    apt_sources = <<-EOF
      deb http://mir1.ovh.net/debian/ #{base} main contrib non-free
      deb-src http://mir1.ovh.net/debian/ #{base} main contrib non-free

      deb http://security.debian.org/ #{base}/updates main
      deb-src http://security.debian.org/ #{base}/updates main
    EOF
    apt_sources.gsub!(/^\s*/,'')
    say "Adding apt-sources for #{name}", :green
    create_file "#{config["build_dir"]}/etc/apt/sources.list", apt_sources
  
    # installing some stuff
    packages = ["vim-common", "screen", "openssh-server", "ntp", "curl", "sudo"]
    packages.each { |deb| install_deb(deb) }

    # umount
    say "Umounting root for #{name}", :green
    run("umount #{config["build_dir"]}", {:verbose => @verbose})
    # DONE
  end
end
JesterSmith.start