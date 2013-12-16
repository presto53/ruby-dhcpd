require 'ipaddr'
require 'net/http'
require 'json'

module DHCPD
  class Pool

    SUPPORTED_MODES = [:remote, :local]

    def initialize(pool_mode)
      raise "Unknown pool mode #{pool_mode.to_s}." unless SUPPORTED_MODES.include?(pool_mode)
      @mode = pool_mode
      @leases = Hash.new
      @pool = pool_from_config
    end

    def get_payload(hwaddr,lock)
      self.send("from_#{@mode.to_s}".to_sym, hwaddr,lock)
    end

    private

    def from_local(hwaddr, lock)
      resp = Hash.new
      begin
	ipaddr = @pool[:addreses].sample
      end while @leases.values.include(ipaddr)
      resp[:ipaddr] = ipaddr.to_i
      @pool[:options].each {|option, data| resp[option] = data}
      lock(hwaddr,ipaddr) if lock
      resp
    end

    def from_remote(hwaddr, lock)
      uri = URI(REMOTE_POOL)
      begin
	res = Net::HTTP.post_form(uri, 'hwaddr' => hwaddr, 'check_in' => Time.now, 'lock' => lock)
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

    def pool_from_config
      pool = Hash.new
      pool[:addreses] = IPAddr.new(LOCAL_POOL[:subnet]).to_range.to_a
      pool[:addreses].shift
      pool[:addreses].pop
      pool[:addreses] = pool[:addreses] - LOCAL_POOL[:exclude].map {|s| IPAddr.new(s).to_range.to_a}.inject {|sum, a| sum+=a}
      pool[:options] = LOCAL_POOL[:options]
      pool[:options][:dhcp_server] = pool[:options][:dhcp_server].split('.').map! {|octet| octet.to_i}
      pool[:options][:domainname] = pool[:options][:domainname].unpack('C*')
      pool[:options][:dns_server] = pool[:options][:dns_server].split('.').map! {|octet| octet.to_i}
      pool[:options][:lease_time] = [pool[:options][:lease_time]].pack('N').unpack('C*')
      pool[:options][:subnet_mask] = pool[:options][:subnet_mask].split('.').map! {|octet| octet.to_i}
      pool[:options][:gateway] = pool[:options][:gateway].split('.').map! {|octet| octet.to_i}
      pool
    end

    def lock(hwaddr, ip)
      @leases['hwaddr'] = ip
    end
  end
end