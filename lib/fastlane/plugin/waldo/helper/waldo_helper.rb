require 'net/http'

module Fastlane
  module Helper
    class WaldoHelper
      def self.upload_build(params)
        UI.success('Uploading the build to Waldo. This could take a while…')

        begin
          uri = URI('https://api.waldo.io/versions')

          request = build_request(uri, params)

          dump_request(request) if FastlaneCore::Globals.verbose?

          Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
            http.read_timeout = 120   # 2 minutes

            parse_response(http.request(request))
          end
        rescue Net::ReadTimeout
          UI.user_error!("Upload to Waldo timed out!")
        rescue => exc
          UI.user_error!("Something went wrong uploading to Waldo: #{exc.inspect}")
        ensure
          request.body_stream.close if request && request.body_stream
        end
      end

      def self.build_request(uri, params)
          request = Net::HTTP::Post.new(uri.request_uri)

          request['Authorization'] = "Upload-Token #{params[:api_key]}"
          request['Transfer-Encoding'] = 'chunked'
          request['User-Agent'] = "Waldo FastlaneIOS v#{Fastlane::Waldo::VERSION}"

          request.body_stream = WaldoReadIO.new(params[:ipa_path])
          request.content_type = 'application/octet-stream'

          request
      end

      def self.dump_request(request)
        len = request.body ? request.body.length : 0

        puts "Request: #{request.method} #{request.path} (#{len} bytes)"

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

      def self.parse_response(response)
        dump_response(response) if FastlaneCore::Globals.verbose?

        case response.code.to_i
        when 200..299
          UI.success('Build successfully uploaded to Waldo!')
        when 401
          UI.user_error!("API key is invalid or missing!")
        else
          UI.user_error!("Build failed to upload to Waldo: #{response.code} #{response.message}")
        end
      end
    end

    class WaldoReadIO
      def initialize(path)
        @fp = File.open(path)
      end

      def close
        @fp.close
      end

      def read(length = nil, outbuf = nil)
        if result = @fp.read(length, outbuf)
          result.force_encoding('BINARY') if result.respond_to?(:force_encoding)
        end

        result
      end
    end
  end
end
