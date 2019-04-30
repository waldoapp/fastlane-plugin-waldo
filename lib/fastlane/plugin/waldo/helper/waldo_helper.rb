require 'net/http'

module Fastlane
  module Helper
    class WaldoHelper
      def self.upload_build(params)
        UI.success('Uploading the build to Waldo. This could take a while…')

        begin
          variant_name = params[:variant_name] || Actions.lane_context[Actions::SharedValues::GRADLE_BUILD_TYPE]
          uri_string = 'https://api.waldo.io/versions'

          uri_string += "?variantName=#{variant_name}" if variant_name

          uri = URI(uri_string)

          request = build_request(uri, params)

          dump_request(request) if FastlaneCore::Globals.verbose?

          Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
            http.read_timeout = 120   # 2 minutes

            parse_response(http.request(request))
          end
        rescue Net::ReadTimeout
          UI.error("Upload to Waldo timed out!")
        rescue => exc
          UI.error("Something went wrong uploading to Waldo: #{exc.inspect.to_s}")
        ensure
          request.body_stream.close if request && request.body_stream
        end
      end

      def self.build_request(uri, params)
        platform = Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]

        if platform == :android
          body_path = params[:apk_path]
          flavor = "Android"
        elsif platform == :ios || platform.nil?
          if params[:app_path]
            app_dir_path = File.dirname(params[:app_path])
            app_name = File.basename(params[:app_path])
            body_path = File.join(Dir.tmpdir, "#{app_name}.zip")

            Actions.sh(%(cd "#{app_dir_path}" && zip -qry "#{body_path}" "#{app_name}"))
          else
            body_path = params[:ipa_path]
          end
          flavor = "iOS"
        end

        request = Net::HTTP::Post.new(uri.request_uri)

        request['Authorization'] = "Upload-Token #{params[:upload_token]}"
        request['Transfer-Encoding'] = 'chunked'
        request['User-Agent'] = "Waldo fastlane/#{flavor} v#{Fastlane::Waldo::VERSION}"

        request.body_stream = WaldoReadIO.new(body_path)

        if params[:app_path]
          request.content_type = 'application/zip'
        else
          request.content_type = 'application/octet-stream'
        end

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
          UI.error("Upload token is invalid or missing!")
        else
          UI.error("Build failed to upload to Waldo: #{response.code} #{response.message}")
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
