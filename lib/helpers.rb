require 'ipaddr'
require 'net/http'
require 'json'

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
      uri = URI(REMOTE_POOL)
      begin
	res = Net::HTTP.post_form(uri, 'hwaddr' => hwaddr, 'check_in' => Time.now)
      rescue
        @log.error 'Remote pool is completely unavailable.'
	raise
      end
      if res.is_a?(Net::HTTPSuccess)
	begin
	  JSON.parse(res.body)
	rescue
	  @log.error "Received invalid data from remote pool server."
	end
      else
	@log.error "Remote pool return code: #{res.code}"
	raise
      end
    end

    def local_get_payload(hwaddr,type)
      pl = Hash.new
      @ip_pool[:options].each {|op, data| pl[op] = data} 
      pl[:ipaddr] = ip_from_default_pool(hwaddr,type).to_i
      pl
    end
  end
end
