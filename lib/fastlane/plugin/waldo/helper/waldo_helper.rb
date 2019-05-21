require 'net/http'

module Fastlane
  module Helper
    class WaldoHelper
      def self.dump_request(request)
        len = request.body ? request.body.length : 0

        puts "Request: #{request.method} #{request.path} (#{len} bytes)"

        request.each_capitalized do |key, value|
          puts "  #{key}: #{value}"
        end

        puts '-------'
      end

      def self.dump_response(response)
        puts "Response: #{response.code} #{response.message} (#{response.body.length} bytes)"

        response.each_capitalized do |key, value|
          puts "  #{key}: #{value}"
        end

        puts "#{response.body}"
      end

      def self.get_authorization
        "Upload-Token #{@upload_token}"
      end

      def self.get_flavor
        case get_platform
        when :android
          "Android"
        when :ios
          "iOS"
        else
          "unknown"
        end
      end

      def self.get_platform
        Actions.lane_context[Actions::SharedValues::PLATFORM_NAME] || :ios
      end

      def self.get_user_agent
        "Waldo fastlane/#{get_flavor} v#{Fastlane::Waldo::VERSION}"
      end

      def self.handle_error(message)
        UI.error(message)

        upload_error(message) if @upload_token
      end

      def self.make_build_request(uri)
        if @apk_path
          body_path = @apk_path
        elsif @ipa_path
          body_path = @ipa_path
        else
          app_basename = File.basename(@app_path)
          app_dirname = File.dirname(@app_path)

          body_path = File.join(Dir.tmpdir, "#{app_basename}.zip")

          unless zip(src_path: app_basename,
                     zip_path: body_path,
                     cd_path: app_dirname)
            return nil
          end
        end

        request = Net::HTTP::Post.new(uri.request_uri)

        request['Authorization'] = get_authorization
        request['Transfer-Encoding'] = 'chunked'
        request['User-Agent'] = get_user_agent

        request.body_stream = WaldoReadIO.new(body_path)

        if @app_path
          request.content_type = 'application/zip'
        else
          request.content_type = 'application/octet-stream'
        end

        request
      end

      def self.make_build_uri
        uri_string = 'https://api.waldo.io/versions'

        uri_string += "?variantName=#{@variant_name}" if @variant_name

        URI(uri_string)
      end

      def self.make_error_request(uri, message)
        request = Net::HTTP::Post.new(uri.request_uri)

        request['Authorization'] = get_authorization
        request['User-Agent'] = get_user_agent

        request.body = { "message": message }.to_json
        request.content_type = 'application/json'

        request
      end

      def self.make_error_uri
          uri_string = 'https://api.waldo.io/uploadError'

          URI(uri_string)
      end

      def self.parse_response(response)
        dump_response(response) if FastlaneCore::Globals.verbose?

        case response.code.to_i
        when 200..299
          UI.success('Build successfully uploaded to Waldo!')
        when 401
          handle_error('Upload token is invalid or missing!')
        else
          handle_error("Build failed to upload to Waldo: #{response.code} #{response.message}")
        end
      end

      def self.upload_build
        begin
          @variant_name ||= Actions.lane_context[Actions::SharedValues::GRADLE_BUILD_TYPE]

          uri = make_build_uri

          request = make_build_request(uri)

          return unless request

          UI.success('Uploading the build to Waldo. This could take a while…')

          dump_request(request) if FastlaneCore::Globals.verbose?

          Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
            http.read_timeout = 120   # 2 minutes

            parse_response(http.request(request))
          end
        rescue Net::ReadTimeout => exc
          handle_error('Upload to Waldo timed out!')
        rescue => exc
          handle_error("Something went wrong uploading to Waldo: #{exc.inspect.to_s}")
        ensure
          request.body_stream.close if request && request.body_stream
        end
      end

      def self.upload_error(message)
        begin
          uri = make_error_uri

          request = make_error_request(uri, message)

          Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
            http.read_timeout = 30  # seconds

            http.request(request)
          end
        rescue => exc
          UI.error("Something went wrong uploading error report to Waldo: #{exc.inspect.to_s}")
        end
      end

      def self.validate_parameters(params)
        @apk_path = params[:apk_path]
        @app_path = params[:app_path]
        @ipa_path = params[:ipa_path]
        @upload_token = params[:upload_token]
        @variant_name = params[:variant_name]

        unless @upload_token
          handle_error('You must pass a nonempty upload token to the Waldo action')

           return false
        end

        case get_platform
        when :android
          unless @apk_path
            handle_error('You must pass an APK path to the Waldo action')

            return false
          end

          @apk_path.gsub!("\\ ", ' ')

          unless File.exist?(@apk_path)
            handle_error("Unable to find APK at path '#{@apk_path.to_s}'")

            return false
          end

          unless File.file?(@apk_path) && File.readable?(@apk_path)
            handle_error("Unable to read APK at path '#{@apk_path.to_s}'")

            return false
          end
        when :ios
          unless @app_path || @ipa_path
            handle_error('You must pass an IPA or app path to the Waldo action')

            return false
          end

          if @app_path
            @app_path.gsub!("\\ ", ' ')


            unless File.exist?(@app_path)
              handle_error("Unable to find app at path '#{@app_path.to_s}'")

              return false
            end

            unless File.directory?(@app_path) && File.readable?(@app_path)
              handle_error("Unable to read app at path '#{@app_path.to_s}'")

              return false
            end
          elsif @ipa_path
            @ipa_path.gsub!("\\ ", ' ')

            unless File.exist?(@ipa_path)
              handle_error("Unable to find IPA at path '#{@ipa_path.to_s}'")

              return false
            end

            unless File.file?(@ipa_path) && File.readable?(@ipa_path)
              handle_error("Unable to read IPA at path '#{@ipa_path.to_s}'")

              return false
            end
          end
        else
            handle_error("Unsupported platform: '#{get_platform.to_s}'")

            return false
        end

        if @variant_name && @variant_name.empty?
          handle_error('Empty variant name for Waldo given')

          return false
        end

        return true
      end

      def self.zip(src_path:, zip_path:, cd_path:)
        unless FastlaneCore::CommandExecutor.which('zip')
            handle_error("Command not found: 'zip'")

            return false
        end

        FileUtils.cd(cd_path) do
          unless Actions.sh(%(zip -qry "#{zip_path}" "#{src_path}")).empty?
            handle_error("Unable to zip app at path '#{src_path.to_s}' into '#{zip_path.to_s}'")

            return false
          end
        end

        return true
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
