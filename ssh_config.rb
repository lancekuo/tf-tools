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

system("aws --region us-east-2 s3 cp s3://tf.ci.internal/env:/continuous-integration/terraform.tfstate "+ File.dirname(__FILE__))

file = File.read(File.dirname(__FILE__)+'/terraform.tfstate')
data_hash = JSON.parse(file)

hosts = {}
bastion = {}
bastion_name = ""
eip = ""
resources = {}

pathname = File.expand_path(File.dirname(__FILE__))+'/../..'

data_hash['modules'].each do |i|
    if i['resources'].empty? == false
        resources = resources.merge(i['resources'])
    end
end

resources.each do |key, resource|
  if ['aws_instance'].include?(resource['type'])
    attributes = resource['primary']['attributes']
    name = attributes['tags.Name'].downcase
    if name.index('bastion')
      bastion_name = name
    end
  end
  if ['aws_eip'].include?(resource['type']) && key.index('bastion')
    attributes = resource['primary']['attributes']
    eip = attributes['public_ip']
  end
end
bastion_path = pathname+'/keys/bastion'
bastion[bastion_name] = {
    :hostname => eip,
    :user     => 'ubuntu',
    :path     => bastion_path,
}
renderer = ERB.new(get_template)
puts renderer.result(SshConfig.new(bastion).get_binding)

resources.each do |key, resource|
  if ['aws_instance'].include?(resource['type'])
    attributes = resource['primary']['attributes']
    name = attributes['tags.Name'].downcase
    hostname = attributes['private_ip']
    if !name.index('bastion')

      user = 'ubuntu'
      node_path = pathname+'/keys/node'
      if name.index('manager')
        node_path = pathname+'/keys/manager'
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
