require 'json'
require 'net/http'

module Fastlane
  module Helper
    class WaldoHelper
      def self.parse_response(response)
        dump_response(response) if FastlaneCore::Globals.verbose?

        if response.code == '401'
          UI.user_error!("API key is invalid or missing!")

          return false
        else
          return response.code == '200'
        end
      end

      def self.upload_build(params)
        uri = URI('https://api.waldo.io/versions')
        http = Net::HTTP.new(uri.host, uri.port)

        http.use_ssl = true

        request = Net::HTTP::Post.new(uri.request_uri)

        request['Authorization'] = "Upload-Token #{params[:api_key]}"
        request['User-Agent'] = "Waldo FastlaneIOS v#{Fastlane::Waldo::VERSION}"

        request.body = File.read(params[:ipa_path])
        request.content_type = 'application/octet-stream'

        dump_request(request) if FastlaneCore::Globals.verbose?

        http.request(request)
      end

      def self.dump_request(request)
        puts "Request: #{request.method} #{request.path} (#{request.body.length} bytes)"

        request.each_capitalized do |key, value|
          puts "  #{key}: #{value}"
        end

        puts "-------"
      end

      def self.dump_response(response)
        puts "Response: #{response.code} #{response.message} (#{response.body.length} bytes)"

        response.each_capitalized do |key, value|
          puts "  #{key}: #{value}"
        end

        puts "#{response.body}"
      end
    end
  end
end
