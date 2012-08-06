maintainer       "dn365"
maintainer_email "dn@365"
license          "All rights reserved"
description      "Installs/Configures ohai-plugins"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.0.3"

%w{ aix ubuntu debian redhat centos fedora freebsd  windows hpux }.each do |os|
  supports os
end