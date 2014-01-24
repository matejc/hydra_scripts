# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
let
  hydra = pkgs.fetchgit { url = https://github.com/NixOS/hydra; rev = "refs/heads/master"; };
in {
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  require = [ "${hydra}/hydra-module.nix" ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  # Define on which hard drive you want to install Grub.
  boot.loader.grub.device = "/dev/sda";

  networking = {
    hostName = "jaeger.matejc"; # Define your hostname.
    interfaces.enp3s0 = { ipAddress = "192.168.111.8"; prefixLength = 24; };
    defaultGateway = "192.168.111.10";
    nameservers = [ "192.168.111.10" ];
    enableIPv6 = false;
  };
  # networking.wireless.enable = true;  # Enables wireless.

  # Select internationalisation properties.
  i18n = {
    consoleFont = "lat9w-16";
    consoleKeyMap = "us";
    defaultLocale = "en_US.UTF-8";
  };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services = {
    postfix = {
      enable = true;
      setSendmail = true;
    };
    ntp.enable = true;
    openssh = {
      enable = true;
      permitRootLogin = "no";
      passwordAuthentication = false;
    };
    locate.enable = true;
    hydra = {
      enable = true;
      dbi = "dbi:Pg:dbname=hydra;host=localhost;user=hydra;";
      package = (import "${hydra}/release.nix" {}).build.x86_64-linux;
      hydraURL = "http://hydra.scriptores.com/";
      listenHost = "localhost";
      port = 3000;
      minimumDiskFree = 5;
      minimumDiskFreeEvaluator = 2;
      notificationSender = "hydra@jaeger.matejc";
      #tracker = "<div>matejc's Hydra reborn</div>";
      logo = "/var/lib/hydra/logo.png";
      debugServer = false;
    };
    # Hydra requires postgresql to run
    postgresql.enable = true;
    postgresql.package = pkgs.postgresql;

    nginx.enable = true;
    nginx.config = pkgs.lib.readFile /root/nginx.conf;
  };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable the X11 windowing system.
  # services.xserver.enable = true;
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e";

  # Enable the KDE Desktop Environment.
  # services.xserver.displayManager.kdm.enable = true;
  # services.xserver.desktopManager.kde4.enable = true;

  security.sudo.enable = true;

  users.extraUsers = {
    matej = {
      createHome = true;
      extraGroups = [ "wheel" ];
      group = "users";
      home = "/home/matej";
      shell = "/run/current-system/sw/bin/bash";
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDOXEZu/ntHOrciyQMPl6kYUSz4+XUTBsl1mQINMA5mdcosaTOnBurjCh1HG5btGWV9Cjqy7OywC4LkgqEtjromD1YWeNfVTAk2kiG7tcNYYvWsxjJzdzH9t8H7eiLz8XM66Q+Ur7kilepw92wLValfAgr/SvnBzyo3/FfdN8MCuTe358dmKp5zvie3x9pzQ1tOwvVjkmW6tp2h/XKIsbEP4Hv4IbXcwPFAJGSlAr/CXnzNvprNW4tJmf0J9pm7Ovy9EyT/lHPhPZ+Ib91lngDZbjGQIl3Zf4XmkpVtfBjHUXnQlPZCThTMNBNcR97QP9IJFbptu/Bz8hGeFtz0ryxF matej@matej41"
      ];
    };

  };

  time.timeZone = "Europe/Berlin";
  environment = {
    systemPackages = with pkgs; [
      file gnupg nmap p7zip htop tmux telnet zsh bash unzip unrar wget git lsof stdenv vim nano tree
      wgetpaste openssl python27Packages.tarman nix
    ];

    interactiveShellInit = ''
        export PATH=$HOME/bin:$PATH
        export EDITOR="nano"
        export EMAIL=cotman.matej@gmail.com
        export FULLNAME="Matej Cotman"
        source /root/nixmy
    '';

  };

  #export NIX_PATH=nixpkgs=$HOME/.nix-defexpr/channels/nixpkgs/:nixos=$HOME/.nix-defexpr/channels/nixpkgs/nixos/:nixos-config=/etc/nixos/configuration.nix:services=/etc/nixos/services

  system.activationScripts.bin_lib_links = ''
      mkdir -p /usr/lib
      ln -fs ${pkgs.xlibs.libX11}/lib/libX11.so.6 /usr/lib/libX11.so.6
  '';

  system.activationScripts.vncmy = ''
    mkdir -p /usr/bin
    export VNCFONTS="${pkgs.xorg.fontmiscmisc}/lib/X11/fonts/misc,${pkgs.xorg.fontcursormisc}/lib/X11/fonts/misc"
    echo "${pkgs.tightvnc}/bin/Xvnc :99 -localhost -fp $VNCFONTS &" > /usr/bin/vncmy
    echo "echo \$! > \$HOME/.Xvnc.pid" >> /usr/bin/vncmy
    chmod +x /usr/bin/vncmy

    echo "test -f \$HOME/.Xvnc.pid && kill -15 \`cat \$HOME/.Xvnc.pid\` && rm \$HOME/.Xvnc.pid" > /usr/bin/vncmy-kill
    chmod +x /usr/bin/vncmy-kill
  '';
}
