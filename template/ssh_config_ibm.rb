#!/usr/bin/env ruby
# NOTICE: AWS providers only.
# Inspired from https://gist.github.com/gionn/fabbd0f6d6ad897d0338

require 'json'
require 'erb'

def get_template()
%{
<% hosts.each do |key, entry| %>
Host <%= key %>
    User <%= entry[:user] %>
    Hostname <%= entry[:hostname] %>
    IdentityFile <%= entry[:path] %>
<% end %>
}
end

def get_template_bastion()
%{
<% hosts.each do |key, entry| %>
Host <%= key %>
    User <%= entry[:user] %>
    Hostname <%= entry[:hostname] %>
    ProxyCommand ssh -A <%= entry[:bastion_name]%> nc %h %p
    IdentityFile <%= entry[:path] %>
    ForwardAgent yes
<% end %>
}
end

class SshConfig
  attr_accessor :hosts

  def initialize(hosts)
    @hosts = hosts
  end

  def get_binding
    binding()
  end
end

if false == ${s3_enabled}
    system("cp ../terraform.tfstate.d/${env_name}/${filename} "+ File.dirname(__FILE__))
else
    system("aws --region ${region} s3 cp s3://${bucket_name}/env:/${env_name}/${filename} "+ File.dirname(__FILE__))
end

file = File.read(File.dirname(__FILE__) + "/${filename}")
data_hash = JSON.parse(file)

hosts = {}
bastion = {}
bastion_name = ""
eip = ""
resources = {}

pathname = File.expand_path(File.dirname(__FILE__))

data_hash['modules'].each do |i|
    if i['resources'].empty? == false
        resources = resources.merge(i['resources'])
    end
end

resources.each do |key, resource|
  if ['ibm_compute_vm_instance'].include?(resource['type'])
    attributes = resource['primary']['attributes']
    name = attributes['hostname'].downcase
    if name.index('bastion')
      bastion_name = name
      eip = attributes['ipv4_address']
    end
  end
end
bastion_path = pathname+'/bastion'
bastion[bastion_name] = {
    :hostname => eip,
    :user     => 'root',
    :path     => bastion_path,
}
renderer = ERB.new(get_template)
puts renderer.result(SshConfig.new(bastion).get_binding)

resources.each do |key, resource|
  if ['ibm_compute_vm_instance'].include?(resource['type'])
    attributes = resource['primary']['attributes']
    name = attributes['hostname'].downcase
    hostname = attributes['ipv4_address_private']
    if !name.index('bastion')

      user = 'root'
      node_path = pathname+'/node'
      if name.index('manager')
        node_path = pathname+'/manager'
      end
      hosts[name] = {
        :hostname => hostname,
        :user => user,
        :bastion_name => bastion_name,
        :path => node_path,
      }
    end
  end
end
renderer2 = ERB.new(get_template_bastion)
puts renderer2.result(SshConfig.new(hosts).get_binding)
File.write(File.expand_path('~')+'/.ssh/config.d/'+bastion_name[0..bastion_name.index('bastion')-2], renderer.result(SshConfig.new(bastion).get_binding)+renderer2.result(SshConfig.new(hosts).get_binding))
system('cat '+File.expand_path('~')+'/.ssh/config.d/* > '+File.expand_path('~')+'/.ssh/config')
