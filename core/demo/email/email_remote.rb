#--
# Copyright (C) Swiby Committers. All rights reserved.
# 
# The software in this package is published under the terms of the BSD
# style license a copy of which has been included with this distribution in
# the LICENSE.txt file.
#
#++

#
# Run this script with '-json' switch to use JSON exhcange format,
# otherwise it uses Ruby format
#

# To use JSON format, need to install some gem:
#         gem install json-jruby
#         or jruby -S gem install json-jruby

#either use
#     require 'rubygems'
# either set env variable
#     set JRUBY_OPTS=-rubygems
require 'rubygems'
require 'erb'
require 'net/http'

class JSONParser
  
  attr_accessor :last_error
  
  def parse data
    symbolize!(JSON.parse(data))
  end
  
  def parse? data
    
    @last_error = nil
    
    @last_error = symbolize!(JSON.parse(data)) unless data.chomp == "\"OK\""
    
    @last_error.nil?
    
  end
  
  def last_error
    @last_error
  end
  
  private
  
  # change keys names in hash maps (JSON objects) from String type to Ruby symbols (more rubish)
  def symbolize! data
    
    data.each {|el| symbolize!(el)} if data.is_a?(Array)
    
    if data.is_a?(Hash)
      
      h = data.to_a
      data.clear
      
      h.each do |pair|
        data[pair[0].to_sym] = symbolize!(pair[1])
      end
    
    end
  
    data
    
  end
  
end

class RubyParser
  
  attr_accessor :last_error
  
  def parse data
    eval(data)
  end
  
  def parse? data
    
    @last_error = nil
    
    data = eval(data)
    
    @last_error = data unless data == "OK"
    
    @last_error.nil?
    
  end
  
  def last_error
    @last_error
  end
  
end

class Connection
  
  def initialize parser = RubyParser.new, service_path = '/remoting/ruby', server = 'localhost', port = 8080
    @http = Net::HTTP.new(server, port)
    @service_path = service_path
    @headers = nil
    @parser = parser
  end

  def submit remote_class, method, args = {}
    @parser.parse(post(remote_class, method, args))
  end
  
  def submit? remote_class, method, args = {}
    @parser.parse?(post(remote_class, method, args))
  end
  
  def last_error
    @parser.last_error
  end
  
  def last_error= last_error
    @parser.last_error = last_error
  end
  
  private
  
  def post remote_class, method, args
    
    path = "#{@service_path}/#{remote_class}/#{method}"
    
    body = args.map {|k,v| "#{k}=#{ERB::Util.url_encode(v)}"}.join("&")
    
    resp, data = @http.post(path, body, @headers)
    
    @headers = { 'Cookie' => resp.response['set-cookie']} if resp.response['set-cookie']
    
    data
    
  end
  
end

class Auth
  
  def initialize connection
    @connection = connection
  end
  
  def login user, password
    @connection.submit?(self.class, 'logIn', :userName => user, :password => password)
  end
  
  def logout
    @connection.submit?(self.class, 'logOut')    
  end
  
  def inbox
    @inbox = Inbox.new(@connection) unless @inbox
    @inbox
  end
  
  def sentbox
    @sentbox = Sent.new(@connection) unless @sentbox
    @sentbox
  end
  
  def last_error
    @connection.last_error
  end
  
end

class Mailbox
  
  def initialize connection
    @connection = connection
  end
  
  def messages
    @connection.submit(self.class, 'messages')
  end
  
  def delete id
    @connection.submit?(self.class, 'delete', :msgId => id)
  end
  
  def read id
    
    message = @connection.submit(self.class, 'read', :msgId => id)
    
    @connection.last_error = message if message[:ERROR]
    
    message = nil if @connection.last_error
    
    message
    
  end
  
  def last_error
    @connection.last_error
  end
  
end

class Inbox < Mailbox
end

class Sent < Mailbox
  
  def send subject, message, to
    @connection.submit?(self.class, 'send', :subject => subject, :message => message, :to => to)
  end
  
end

if $0 == __FILE__

  if ARGV[0] == '-json'
    puts 'Using JSON format'
    require 'json'
    auth = Auth.new(Connection.new(JSONParser.new, '/remoting/pwr'))
  else
    puts 'Using Ruby format'
    auth = Auth.new(Connection.new)
  end

  unless auth.login('Gil Bates', '1234')
  #unless auth.login('Beeve Salmer', '1234')
    puts auth.last_error[:message]
    exit
  end

  puts '::inbox'
  p auth.inbox.messages
  puts '::sent'
  p auth.sentbox.messages

  puts '::read message 1'
  p auth.inbox.read 1

  puts '::read message 1999'
  unless auth.inbox.read 1999
    puts auth.inbox.last_error[:message]
  end

=begin
  puts '::delete 1'
  unless auth.inbox.delete 1
    puts auth.inbox.last_error[:message]
  end

  puts '::inbox'
  p auth.inbox.messages
=end

  puts '::delete 7777'
  unless auth.inbox.delete 7777
    puts auth.inbox.last_error[:message]
  end

  puts '::send mail + show sent box'
  auth.sentbox.send 'news', 'Misual Vasic .ORG', 'James Bond'
  p auth.sentbox.messages

  auth.logout

end