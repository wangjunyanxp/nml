class Nml < Sinatra::Base
  @@master = "10.132.17.108"
  @@base = "nml"
  @@dns = "222.73.13.68 58.215.44.20 218.30.78.103"

  def request_headers
    env.inject({}){|acc, (k,v)| acc[$1.downcase] = v if k =~ /^http_(.*)/i; acc}
  end  

  def get_real_ipaddr()
    ips = request_headers["x_forwarded_for"].to_s.scan /^(?:\d+\.){3}\d+/
    ips[0]
  end

  def to_path(release)
      # centos-6.0-x86_64 -> /centos/6.0/os/x86_64
      '/' + release.split("-").insert(-2, 'os').join('/')
  end

  def install(uuid, ipaddr, gateway, hostname, iface, baudrate, release)
    if /^ubuntu/i =~ release
      indent = ' ' * 4
      head = "serial 0 #{baudrate}\ntimeout 50\nlabel pxeboot"
      tail = "default #{release}/vesamenu.c32"

      kernel = indent + "kernel %s/linux" % [release] 

      configs = [
        "autostep",
        "console-tools/archs=skip-config",
        "console-keymaps-at/keymap=us",
        "vga=normal",
        "netcfg/confirm_static=true",
        "netcfg/disable_dhcp=true",
        "netcfg/get_hostname=#{hostname}",
        "netcfg/get_domain=.nml",
        "netcfg/get_nameservers=%s" % [@@dns],
        "netcfg/get_ipaddress=#{ipaddr}",
        "netcfg/get_netmask=255.255.255.0",
        "netcfg/get_gateway=#{gateway}",
        "console-setup/ask_detect=false",
        "console-setup/layoutcode=us",
        "locale=en_US.UTF-8",
        "interface=#{iface}",
        "console=ttyS0,#{baudrate}n8",
        "initrd=#{release}/initrd.gz",
        "auto url=http://%s/%s/preseed/#{uuid}" % [@@master, @@base]
      ]

      append = indent + 'append ' + configs.join(' ') + ' -- quiet'
      [head, kernel, append, tail].join("\n") + "\n"
    elsif /^centos/ =~ release
      indent = ' ' * 4
      head = "serial 0 #{baudrate}\ntimeout 50\nlabel pxeboot"
      tail = "default #{release}/vesamenu.c32"

      kernel = indent + "kernel %s/vmlinuz" % [release] 
      configs = [
        "ks=http://%s/%s/preseed/#{uuid}" % [@@master, @@base],
        "vga=normal",
        "hostname=#{hostname}",
        "ip=#{ipaddr}",
        "dns=%s" % [@@dns],
        "gateway=#{gateway}",
        "netmask=255.255.255.0",
        "ksdevice=#{iface}",
        "console=ttyS0,#{baudrate}n8",
        "method=http://%s%s" % [@@master, to_path(release)],
        "lang=en_US",
        "keymap=us",
        "initrd=#{release}/initrd.img",
      ]
      append = indent + 'append ' + configs.join(' ') + ' quiet'
      [head, kernel, append, tail].join("\n") + "\n"
    else
    end
  end

  def get_release(uuid)
    if uuid == '40f9d7c1-446c-b601-2911-001a6499e750'
      # 'centos-6.0-x86_64'
      # 'centos-6.0-i386'
      #'centos-5.6-x86_64'
        'centos-5.6-i386'
    else
      'ubuntu-lucid-amd64'
    end
  end

  def get_iface(uuid)
    'eth0'
  end

  def get_hostname(uuid)
    'aoti'
  end

  def get_baudrate(uuid)
    115200
  end

  def get_gateway(uuid)
    ip =  get_real_ipaddr
    ip.to_s.sub(/\.\d+$/, '.1')
  end

  def get_ipaddr(uuid)
    get_real_ipaddr
  end

  get '/nml/chain/:manufacturer/:product/:uuid' do
    result = "#!ipxe\nkernel http://%s/%s/pxelinux.0\nboot" % [@@master, @@base]
  end

  get '/nml/pxelinux.cfg/:uuid' do
    uuid = params[:uuid]
    install(uuid, get_ipaddr(uuid), get_gateway(uuid), get_hostname(uuid),
      get_iface(uuid), get_baudrate(uuid), get_release(uuid))
  end

  # get '/try' do
  #   get_centos_path('centos-6.0-x86_64')
  # end
end
