provides "addon"
require_plugin "network"
require_plugin "dmi"
storage Mash.new
storage[:interfaces] = Mash.new
virtualization Mash.new
dmi[:system]  = Mash.new unless dmi[:system]
dmi[:system][:product_name] = from("uname -M").split(",")[1]
dmi[:system][:manufacturer] = "IBM"
dmi[:system][:serial_number] = from("uname -u")[6..12]

popen4("lscfg -v -l ent*") do |pid, stdin, stdout, stderr|
  stdin.close
  stdout.each do |line|
    case line
    when /^\s+ent(\d+)\s+\S+\s+(.+)\s+\(.+\)/
      $ifName = "en" + $1
      network['interfaces'][$ifName] = Mash.new unless network['interfaces'][$ifName]
      network['interfaces'][$ifName]['name'] = $2
      popen4("entstat -d #{$ifName}") do |pid, stdin, stdout, stderr|
        stdin.close
        stdout.each do |line|
          case line
          when /Link\sStatus\s*:\s*(.+)/
            network['interfaces'][$ifName]['status'] = $1
          end
        end
      end
    when /Network\sAddress\.+(\w{2})(\w{2})(\w{2})(\w{2})(\w{2})(\w{2})/
      macaddr = $1 + ":" + $2 + ":" + $3 + ":" + $4 + ":" + $5 + ":" + $6
      network['interfaces'][$ifName]['addresses'] = Mash.new unless network['interfaces'][$ifName]['addresses']
      network['interfaces'][$ifName]['addresses'][macaddr] = { "family" => "lladdr" }
    end
  end
end

network['interfaces'].keys.each do |ifName|
  next if ifName.match(/lo/) or ifName.match(/:/) or ifName.match(/^et\d+/)
  ppa=ifName[/\d+/]
  popen4("lscfg -vpl ent#{ppa}") do |pid, stdin, stdout, stderr|
    stdin.close
    if stdout.string.empty? then
      popen4("entstat -d #{ifName}") do |pid, stdin, stdout, stderr|
        member = Array.new
        stdin.close
        stdout.each do |line|
          case line
          when /Operating\smode:\s(.+)/
            network['interfaces'][ifName]['balance'] = $1
          when /ETHERNET\sSTATISTICS\s\(ent(\d+)\)/
            member << "en" + $1
            $netname = "en" + $1
            network['interfaces'][ifName]['member'] = member.join (",")
          when /Device\sType:\s+(.+Link.*)/
            network['interfaces'][ifName]['name'] = $1
          when /Link\sStatus\s*:\s*(.+)/
            network['interfaces'][$netname]['status'] = $1
          end
        end
      end
    else
      stdout.each do |line|
        case line
        when /^\s+ent(\d+)\s+\S+\s+(.+)\s+\(.+\)/
        network['interfaces'][ifName]['name'] = $2
        end
      end
    end
  end
end

popen4("lscfg -v -l fcs*") do  |pid, stdin, stdout, stderr|
  stdin.close
  stdout.each do |line|
    case line
    when /fcs(\d+)/
      $fcid = "fcs" + $1
      scsiid = "fscsi" + $1
      storage[:interfaces][$fcid] = Mash.new unless storage[:interfaces][$fcid]
      storage[:interfaces][$fcid][:name] = "FC Adapter"
      popen4("lsattr -El #{scsiid}") do |pid, stdin, stdout, stderr|
        stdin.close
        stdout.each do |line|
          if line.match(/attach\s+none/) then
            storage[:interfaces][$fcid][:status] = "DOWN"
            break
          else
            storage[:interfaces][$fcid][:status] = "UP"
            if File.executable?("/usr/sbin/fcstat") then
              popen4("fcstat #{$fcid} | grep running") do |pid, stdin, stdout, stderr|
                stdin.close
                stdout.each do |line|
                  if line.match(/^Port\s+Speed\s+\(running\):\s+(\d)/i) then
                    storage[:interfaces][$fcid][:speed] = $1 + "Gb"
                  else
                    storage[:interfaces][$fcid][:speed] = "UNKNOWN"
                  end
                end
              end
            else
              storage[:interfaces][$fcid][:speed] = "UNKNOWN"
            end
          end
        end
      end
    when /Network\s+Address\.+(..)(..)(..)(..)(..)(..)(..)(..)/
      storage[:interfaces][$fcid][:wwn] = $1+":"+$2+":"+$3+":"+$4+":"+$5+":"+$6+":"+$7+":"+$8
    end
  end
end
