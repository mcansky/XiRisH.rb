#!/usr/bin/env ruby
# the tool to create VMs
require "rubygems" # ruby1.9 doesn't "require" it though
require "thor"
require 'yaml'

class JesterSmith < Thor
  include Thor::Actions

  # install a debian package
  def install_deb(name)
    fake = <<-EOF
    #!/bin/sh'
    echo \"Warning: Fake start-stop-daemon called, doing nothing\"
    EOF
    fake.gsub!(/^\s*/,'')
    say "Deactivating auto start for deamon", :yellow
    run("mv #{@build_dir}/sbin/start-stop-daemon #{@build_dir}/sbin/start-stop-daemon.REAL")
    create_file "#{@build_dir}/sbin/start-stop-daemon", fake
    run("chmod 766 #{@build_dir}/sbin/start-stop-daemon")
    say "Installing Debian package #{name} to #{@build_dir}", :green
    run("chroot #{@build_dir} /usr/bin/apt-get --yes --force-yes install #{name}")
    say "Activating auto start for deamon", :yellow
    run("mv #{@build_dir}/sbin/start-stop-daemon.REAL #{@build_dir}/sbin/start-stop-daemon")
  end

  def install_deb_daemon(name)
    fake = <<-EOF
    #!/bin/sh'
    echo \"Warning: Fake start-stop-daemon called, doing nothing\"
    EOF
    fake.gsub!(/^\s*/,'')
    say "Deactivating auto start for deamon", :yellow
    run("mv #{@build_dir}/sbin/start-stop-daemon #{@build_dir}/sbin/start-stop-daemon.REAL")
    create_file "#{@build_dir}/sbin/start-stop-daemon", fake
    run("chmod 766 #{@build_dir}/sbin/start-stop-daemon")
    say "Installing Debian package #{name} to #{@build_dir}", :green
    run("chroot #{@build_dir} /usr/bin/apt-get --yes --force-yes install #{name}")
    say "Activating auto start for deamon", :yellow
    run("mv #{@build_dir}/sbin/start-stop-daemon.REAL #{@build_dir}/sbin/start-stop-daemon")
    say "Stopping the #{name} deamon", :yellow
    run("chroot #{@build_dir} /etc/init.d/#{name} stop")
  end

  # Run a command in the chrooted env
  def chroot_run(cmd)
    say "Running command : #{cmd} in #{@build_dir}", :green
    run("chroot #{@build_dir} #{cmd}", {:verbose => @verbose})
  end

  # install part (deboot strap and all)
  def install(name, version, ip, storage)
    for_line = "for #{name} on #{storage}"
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
  method_options :ip => :string, :storage => :string, :version => "squeeze64", :no_install => false, :silent => false, :packages => false, :bare => false
  def create(name)
    #argument :name, :type => :string, :desc => "the name of the vm", :required => true
    #argument :version, :type => :string, :desc => "the version of debian you want to use", :required => true
    #argument :ip, :type => :string, :desc => "the ip address you want the vm to use", :required => true
    #argument :storage, :type => :string, :desc => "the storage vg you want to use", :required => true
    #desc "Create a new Xen VM"

    say "Starting the script with options :\n\tname : #{name}\n\tversion : #{options[:version]}\n\tip : #{options[:ip]}\n\tstorage : #{options[:storage]}\n", :green

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
    @verbose = false if ((config["verbose"] == 0) || (options[:silent] == true))
    @noinstall = options[:no_install]
    @lv_size = config["lv_size"]
    @lv_swap_size = config["lv_swap_size"]
    # default args aka squeeze 64
    @arch = "amd64"
    @kernel = "linux-image-2.6-amd64"
    @base = "squeeze"
    @mirror = config["mirror"]
    @locale = config["locale"] || 'en_US.ISO-8859-15'
    @packages = false
    @packages = true if (options[:packages] == true)
    @bare = true if (options[:bare] == true)
    @pub_key = config["pub_key"]
    for_line = "for #{name} on #{storage}"
    if config["dummy"] == 1
      say "WARNING : Dummy mode !", :red
      config["build_dir"] = "/tmp/jester"
      config["log_dir"] = "/tmp/jester_log"
    end

    if !@noinstall
      install(n_name, version, ip, storage)
    else
      say "No install requested, directly configuring", :yellow
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
      kernel = '#{vmlinuz_file}'
      ramdisk= '#{initrd_file}'
      vcpus = '1'
      memory = '512'
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
    File.delete("/etc/xen/xen.d/#{name}.cfg") if File.exist?("/etc/xen/xen.d/#{name}.cfg")
    create_file "/etc/xen/xen.d/#{name}.cfg", xenconf

    # generating network config file
    network_conf = <<-EOF
    auto lo
    iface lo inet loopback
  
    auto eth0
    iface eth0 inet static
            address #{ip}
            gateway #{config["gateway"]}
            netmask #{config["netmask"]}
    EOF
    network_conf.gsub!(/^\s*/,'')
    # creating the config file
    say "Creating network file for #{name}", :green
    File.delete("#{@build_dir}/etc/network/interfaces") if File.exist?("#{@build_dir}/etc/network/interfaces")
    create_file "#{@build_dir}/etc/network/interfaces", network_conf

    # creating the fstab file
    fstab_file = <<-EOF
      /dev/xvda1      /                   ext3        defaults        0       1
      /dev/xvda2      none                swap        defaults        0       0
      proc            /proc               proc        defaults        0       0
    EOF
    fstab_file.gsub!(/^\s*/,'')
    # creating the fstab file
    say "Creating fstab file for #{name}", :green
    File.delete("#{@build_dir}/etc/fstab") if File.exist?("#{@build_dir}/etc/fstab")
    create_file "#{@build_dir}/etc/fstab", fstab_file

    # adding line to inittab
    say "Adding hvc0 line to inittab for #{name}", :green
    append_to_file "#{@build_dir}/etc/inittab", "hvc0:23:respawn:/sbin/getty 38400 hvc0"

    # hostname
    say "Creating hostname file for #{name}", :green
    File.delete("#{@build_dir}/etc/hostname") if File.exist?("#{@build_dir}/etc/hostname")
    create_file "#{@build_dir}/etc/hostname", name.gsub("_",'-')

    # sources for apt
    apt_sources = <<-EOF
      deb http://mir1.ovh.net/debian/ #{@base} main contrib non-free
      deb-src http://mir1.ovh.net/debian/ #{@base} main contrib non-free

      deb http://security.debian.org/ #{@base}/updates main
      deb-src http://security.debian.org/ #{@base}/updates main
    EOF
    apt_sources.gsub!(/^\s*/,'')
    say "Adding apt-sources for #{name}", :green
    File.delete("#{@build_dir}/etc/apt/sources.list") if File.exist?("#{@build_dir}/etc/apt/sources.list")
    create_file "#{@build_dir}/etc/apt/sources.list", apt_sources

    # updating apt
    chroot_run("apt-get update")
    chroot_run("apt-get upgrade -y")
    chroot_run("apt-get clean")

    # creating a user
    say "Creating master user", :green
    chroot_run "useradd -u 111 -s /bin/bash -m master"
    # install sudo
    install_deb("sudo")
    # add sudo line
    append_to_file "#{@build_dir}/etc/sudoers", "master ALL=(ALL) ALL"
    # add pub key
    pub_key = IO.read(@pub_key)
    run("mkdir -m 700 #{@build_dir}/home/master/.ssh")
    append_to_file("#{@build_dir}/home/master/.ssh/authorized_keys2", pub_key)
    chroot_run("chown -R root:root /home/master/.ssh")

    unless @bare
      install_deb("locales")
      # setting the locale
      say "Setting the locale to #{@locale}", :green
      File.delete("#{@build_dir}/etc/locale.gen") if File.exist?("#{@build_dir}/etc/locale.gen")
      File.delete("#{@build_dir}/etc/default/locale") if File.exist?("#{@build_dir}/etc/default/locale")
      # creating locale.gen
      locale_gen = <<-EOF
        #{@locale} #{@locale.split(".").last}
      EOF
      locale_gen.gsub!(/^\s*/,'')
      create_file "#{@build_dir}/etc/locale.gen", locale_gen
      # creating locale
      locale_f = <<-EOF
        LANG="#{@locale}"
      EOF
      locale_f.gsub!(/^\s*/,'')
      create_file "#{@build_dir}/etc/default/locale", locale_f
      # running the gen script
      chroot_run("/usr/sbin/locale-gen")

      if @packages
        # installing some stuff
        packages = ["vim-common", "screen", "openssh-server", "curl"]
        packages.each { |deb| install_deb(deb) }
        daemons = ["ntp"]
        daemons.each { |deb| install_deb_daemon(deb) }
      end
    end

    # umount
    say "Umounting root for #{name}", :green
    run("umount #{config["build_dir"]}", {:verbose => @verbose})
    # DONE
  end
end
JesterSmith.start