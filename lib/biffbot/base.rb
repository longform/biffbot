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
			
      relative_urls = {} # hash of transformed relative_url => response returned from diffbot
      batch_items = [] # array of requests to post to diffbot in batch
      output = {} # hash of url => decoded hash of JSON body for the URL
			
      request = "http://www.diffbot.com/api/batch"
      
      urls.each do |url|
        relative = relative_url(url, options)
        relative_urls[relative] = { :url => url, :body => nil }
        batch_items << { :method => "GET", :relative_url => relative }
      end
      
      options = { :body => {:token => @token, :batch => batch_items.to_json }, :basic_auth => @auth }
      
      10.tries do
  			response = HTTParty.post(request, options)
  			response.parsed_response.each do |response_dict|
  				relative_urls[response_dict['relative_url']][:body] = JSON.parse(response_dict["body"])
  			end
      end

      # map hash of relative_urls back to the original url
      relative_urls.each do |relative, data|
        output[data[:url]] = data[:body]
      end

			return output
    end

    def relative_url(url, options)
      relative = "/api/article?token=#{@token}&url=#{CGI.escape(url)}"
      options.each_pair do |key,value|
        if key.match(/html|dontStripAds|tags|comments|summary|stats/) && value == true
          relative = relative + "&#{key}"
        end
      end
      relative
    end
	end
end
