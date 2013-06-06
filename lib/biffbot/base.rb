require 'httparty'
require 'json'
require 'retry'
require 'cgi'

module Biffbot
	class Base
		def initialize(token) 
			@token = token
		end
		def parse(url,options={})
			@url = url
			output = Hash.new
			request = "http://www.diffbot.com/api/article?token=#{@token}&url=#{CGI.escape(@url)}"
			options.each_pair do |key,value|
				if key.match(/html|dontStripAds|tags|comments|summary|stats/) && value == true
					request = request + "&#{key}"
				end
			end
      10.tries do
        response = HTTParty.get(request)
  			response.parsed_response.each_pair do |key,value|
  				output[key] = value
  			end
      end
			return output
		end
		def batch(urls, options={})
			output = []
			request = "http://www.diffbot.com/api/batch"
      batch = urls.map do |url|
        relative_url = "/api/article?token=#{@token}&url=#{CGI.escape(url)}"
  			options.each_pair do |key,value|
  				if key.match(/html|dontStripAds|tags|comments|summary|stats/) && value == true
  					relative_url = relative_url + "&#{key}"
  				end
  			end
        { :method => "GET", :relative_url => relative_url }
      end
      options = { :body => {:token => @token, :batch => batch.to_json }, :basic_auth => @auth }
      10.tries do
  			response = HTTParty.post(request, options)
      
  			JSON.parse(response.parsed_response).each do |response_dict|
  				output << JSON.parse(response_dict["body"])
  			end
      end
			return output
    end
	end
end
