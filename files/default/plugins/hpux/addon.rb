provides "addon"
require_plugin "network"
require_plugin "dmi"
storage Mash.new
storage[:interfaces] = Mash.new
virtualization Mash.new
dmi[:system]  = Mash.new unless dmi[:system]
dmi[:system][:product_name] = from("model")
dmi[:system][:manufacturer] = "HP"
if File.executable?( "/usr/contrib/bin/machinfo" ) then
  popen4("/usr/contrib/bin/machinfo") do |pid, stdin, stdout, stderr|
    stdin.close
    stdout.each do |line|
      if line.match(/achine\s+serial\s+number\s*[:=]\s+(\S+)/) then
        dmi[:system][:serial_number] = $1
      end
      if line.match(/Virtual Machine/) then
        virtualization[:system] = "HPVM"
      end
    end
  end
else
  popen4("echo 'sc product system;il' | /usr/sbin/cstm | grep 'System Serial Number'") do |pid, stdin, stdout, stderr|
    stdin.close
    stdout.each do |line|
      if line.match(/:\s+(\w+)/) then
        dmi[:system][:serial_number] = $1
      end
    end
  end
end

network['interfaces'].keys.each do |ifName|
  next if ifName.match(/lo/) or ifName.match(/:/)
  ppa=ifName[/\d+/]
  popen4("lanadmin -g #{ppa}") do |pid, stdin, stdout, stderr|
    stdin.close
    stdout.each do |line|
      case line
      when /Description\s+=\s(lan\d+)\s(\S+\s\S+\s\S+)\s/
        network['interfaces'][ifName]['name'] = $2
      when /Operation Status.+=\s(\w+)\W/i
        network['interfaces'][ifName]['status'] = $1
      end
      if network['interfaces'][ifName]['name'] =~ /LinkAggregate/ then
        popen4("lanadmin -x -i #{ppa}") do |pid, stdin, stdout, stderr|
          stdin.close
          stdout.each do |line|
            case line 
            when /Aggregation\sMode\s+:\s(.+)/
              network['interfaces'][ifName]['aggregation'] = $1
            when /Balance\sMode\s+:\s(.+)/
              network['interfaces'][ifName]['balance'] = $1
            end
          end
        end
      end
    end
  end
end

popen4("lanscan -q") do |pid, stdin, stdout, stderr|
  stdin.close
  stdout.each do |line|
    member = line.rstrip!.split(" ")
    if member.size > 1 then
      ifName = "lan" + member[0]
      member.map! { |x| "lan"+x }
      member.shift
      network['interfaces'][ifName]['member'] = member.join(",")
    elsif member.size == 1 then
      ifName = "lan" + member[0]
      next if !network['interfaces'][ifName].nil?
      network['interfaces'][ifName] = Mash.new
      popen4("lanadmin -g #{member[0]}") do |pid, stdin, stdout, stderr|
        stdin.close
        stdout.each do |line1|
          case line1
          when /Description\s+=\s(lan\d+)\s(\S+\s\S+\s\S+)\s/
            des = $2
            break if $2 =~ /LinkAggregate/
            network['interfaces'][ifName]['name'] = des
          when /Station\sAddress\s+=\s0x(\w{2})(\w{2})(\w{2})(\w{2})(\w{2})/
            macaddr = "00:" + $1 + ":" + $2 + ":" + $3 + ":" + $4 + ":" + $5 
            network['interfaces'][ifName]['addresses'] = Mash.new
            network['interfaces'][ifName]['addresses'][macaddr] = { "family" => "lladdr" }
          when /Station\sAddress\s+=\s0x(\w{2})(\w{2})(\w{2})(\w{2})(\w{2})(\w{2})/
            macaddr = $1 + ":" + $2 + ":" + $3 + ":" + $4 + ":" + $5 + ":" + $6
            network['interfaces'][ifName]['addresses'] = Mash.new
            network['interfaces'][ifName]['addresses'][macaddr] = { "family" => "lladdr" }
          when /Operation Status.+=\s(\w+)\W/i
            network['interfaces'][ifName]['status'] = $1
          end
        end
      end
    end
 end
end


if File.executable?("/opt/fcms/bin/fcmsutil") then
  popen4("ioscan -funC fc") do |pid, stdin, stdout, stderr|
    stdin.close
    stdout.each do |line|
      case line
      when /.*INTERFACE\s+(.*)/
				$tmp = $1
			when /\/dev\/(\w+)/
				fcid = $1
				storage[:interfaces][fcid] = Mash.new unless storage[:interfaces][fcid]
				storage[:interfaces][fcid][:name] = $tmp
			end
		end
	end
	storage['interfaces'].keys.each do |fcName|
		devName = "/dev/" + fcName
		popen4("/opt/fcms/bin/fcmsutil #{devName}") do |pid, stdin, stdout, stderr|
        stdin.close
        stdout.each do |line|
          case line
          when /Link.+=\s(.+)/
					storage['interfaces'][fcName]['speed'] = $1
				when /Driver\sstate\s+=\s(.+)/
					storage['interfaces'][fcName]['status'] = $1
				when /N_Port\sPort.+=\s0x(..)(..)(..)(..)(..)(..)(..)(..)$/
					storage['interfaces'][fcName]['wwn'] = $1+":"+$2+":"+$3+":"+$4+":"+$5+":"+$6+":"+$7+":"+$8
				end
			end
		end
	end
end

result= `ps -ef | grep vpard | grep -v grep`
if result.match(/vpard/) then
  virtualization[:system] = "VPAR"
else
  virtualization[:system] = "NPAR"
end
