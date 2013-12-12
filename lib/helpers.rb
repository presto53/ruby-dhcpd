require 'ipaddr'

module DHCPD
  class DHCPD
    ###
    #
    # Constants
    #
    ###
    SERVER_DHCP_PORT = 67
    CLIENT_DHCP_PORT = 68

    private

    def to_hwaddr(chaddr,hlen)
      chaddr.take(hlen).map {|x| x.to_s(16).size<2 ? '0'+x.to_s(16) : x.to_s(16)}.join(':')
    end

    def pool_from(config)
      config[:subnet] = IPAddr.new(config[:subnet]).to_range
      config[:options][:dhcp_server] = config[:options][:dhcp_server].split('.').map! {|octet| octet.to_i}
      config[:options][:domainname] = config[:options][:domainname].unpack('C*')
      config[:options][:dns_server] = config[:options][:dns_server].split('.').map! {|octet| octet.to_i}
      config[:options][:lease_time] = [config[:options][:lease_time]].pack('N').unpack('C*')
      config[:options][:subnet_mask] = config[:options][:subnet_mask].split('.').map! {|octet| octet.to_i}
      config[:options][:gateway] = config[:options][:gateway].split('.').map! {|octet| octet.to_i}
      config
    end

    def ip_from_default_pool(hwaddr,type)
      IPAddr.new('192.168.1.200')
      #someday it will get random ip from pool and check it is free then return it
    end

    def remote_get_payload(hwaddr,type)
      # will be implemented soon
      @log.error 'Remote pool is unavailable.'
      raise
    end

    def local_get_payload(hwaddr,type)
      pl = Hash.new
      @ip_pool[:options].each {|op, data| pl[op] = data} 
      pl[:ipaddr] = ip_from_default_pool(hwaddr,type).to_i
      pl
    end
  end
end
