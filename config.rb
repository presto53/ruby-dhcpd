module DHCPD
  class Config
    # Log level
    # from 0 to 6, where 0 is most verbose
    LOG_LEVEL = 0
    LOG_FILE = 'dhcpd.log'

    # Server ip
    SERVER_BIND_IP = '255.255.255.255'
    SERVER_SUBNET = '192.168.50.0/24'

    # Pool mode
    # :remote, :local
    POOL_MODE = :local

    # Remote pool address
    # when POOL_MODE is set to :remote or :both
    # server will try to get configuration for host
    # from remote server. Server will send HTTP GET
    # request to REMOTE_POOL address with hwaddr
    # parameter.
    REMOTE_POOL = 'http://127.0.0.1:9292/api/host'

    # Local pool configuration
    # Use subnet notation like 192.168.1.0/24
    # or just ip like 172.16.0.4.
    LOCAL_POOL =
      {
      subnet: SERVER_SUBNET,
      exclude: [],
      options: {
	dhcp_server:'192.168.1.1',
	gateway:'192.168.1.1',
	subnet_mask: '255.255.255.0',
	domainname: 'local.domain',
	dns_server: '8.8.8.8',
	lease_time: 28800, # 8 hours
	filename: 'pxeloader.0'
      }
    }
  end
end
