require 'net/http'
require 'json'


task :post do 
  env   = ENV['env'] || 'development'
  data  = File.open('test/github-post-receive.json') { |f| f.read }
  uri   = (env == 'development') ? URI.parse("http://localhost:3000") : URI.parse("http://post.ruhoh.com")

  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Post.new(uri.request_uri)
  request.set_form_data('payload' => data)
  response = http.request(request)

  puts response
  response
end  

