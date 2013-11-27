require 'httparty'
require 'json'
require 'retries'
require 'cgi'

module Biffbot
  class ParserError < Exception; end
  
	class Base
    

    include HTTParty
    default_timeout 120
    
		def initialize(token) 
			@token = token
		end

		def parse(url,options={})
			@url = url
			output = Hash.new
			request = "http://www.diffbot.com/api/article?token=#{@token}&url=#{CGI.escape(@url)}"
			options.each_pair do |key,value|
				if key.match(/html|dontStripAds|tags|comments|summary|stats|outback/) && value == true
					request = request + "&#{key}=true"
				end
			end
      with_retries(:max_tries => 5, :max_sleep_seconds => 10.0, :rescue => ResponseError) do
        response = self.class.get(request)
        if response.parsed_response.respond_to?(:each_pair)
    			response.parsed_response.each_pair do |key,value|
    				output[key] = value
    			end
        else
          raise ParserError, "Response: #{response.parsed_response.inspect}"
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
      
      with_retries(:max_tries => 5, :max_sleep_seconds => 10.0, :rescue => ResponseError) do
  			response = self.class.post(request, options)
        if response.parsed_response.respond_to?(:each)
    			response.parsed_response.each do |response_dict|
    				relative_urls[response_dict['relative_url']][:body] = JSON.parse(response_dict["body"])
    			end
        else
          raise ParserError, "Response: #{response.parsed_response.inspect}"
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
        if key.match(/html|dontStripAds|tags|comments|summary|stats|outback/) && value == true
          relative = relative + "&#{key}"
        end
      end
      relative
    end
	end
end
