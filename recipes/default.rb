#
# Cookbook Name:: ohai-plugins
# Recipe:: default
#
# Copyright 2012, dn365
#
# All rights reserved - Do Not Redistribute
#

directory "/etc/chef/plugins" do
  action :create
end

node["ohai"]["plugins"].each do |file|
  template "/etc/chef/plugins/#{file}" do
    source "plugins/#{file}.erb"
  end
end




