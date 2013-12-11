#!/usr/bin/env ruby

require_relative 'lib/helpers'
require_relative 'lib/dhcpd'

module DHCPD
  class DHCPD
    ###
    #
    # Configuration block
    #
    ###
    # Log level from 0 to 6, where 0 is most verbose logging.
    LOG_LEVEL = 0

    # Server ip
    SERVER_BIND_IP = ARGV[0].to_s ||= '0.0.0.0'

    # Pool's configuration
    #
    # You can use subnet notation like 192.168.1.0/24, or just ip like 172.16.0.4
    # If you want to use same options for more than one subnet, you should separate 
    # then with comma's like ['192.168.1.0/24', '192.168.3.0/24']
    SERVER_IP_POOL =
        {
            subnet: '192.168.1.0/24',
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

DHCPD::DHCPD.new(DHCPD::DHCPD::SERVER_IP_POOL).run
