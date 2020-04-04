require "ipaddr"
require "json"

def check_ip client_address
	on_campus = false
	ranges = File.read('../extras/ip_whitelist.json')
	ranges_data = JSON.parse(ranges)
	ranges_data['approved_ranges'].each do |k,v|
		network = IPAddr.new(v['network'])
		if network === IPAddr.new(client_address)
			on_campus = true
			break
		else
			nil
		end
	end
	return on_campus
end
