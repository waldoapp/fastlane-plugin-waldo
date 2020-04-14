require 'base64'
require 'json'
require 'net/http'

module Fastlane
  module Helper
    class WaldoHelper
      def self.convert_commit(sha)
        puts "Entering convert_commit(#{sha})"

        prefix = 'remotes/origin/'
        pfxlen = prefix.length

        full_name = get_git_commit_name(sha)

        if full_name.start_with?(prefix)
          abbr_name = full_name[pfxlen..-1]
        else
          abbr_name = "local:#{full_name}"
        end

        %("#{sha[0..7]}-#{abbr_name}")
      end

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

      def self.filter_parameters(in_params)
        out_params = {}

        apk_path = in_params[:apk_path]
        app_path = in_params[:app_path]
        dsym_path = in_params[:dsym_path]
        ipa_path = in_params[:ipa_path]
        upload_token = in_params[:upload_token]
        variant_name = in_params[:variant_name]

        apk_path.gsub!("\\ ", ' ') if apk_path
        app_path.gsub!("\\ ", ' ') if app_path
        dsym_path.gsub!("\\ ", ' ') if dsym_path
        ipa_path.gsub!("\\ ", ' ') if ipa_path

        out_params[:apk_path] = apk_path if apk_path

        if app_path && ipa_path
          if !File.exist?(app_path)
            out_params[:ipa_path] = ipa_path
          elsif !File.exist?(ipa_path)
            out_params[:app_path] = app_path
          elsif File.mtime(app_path) < File.mtime(ipa_path)
            out_params[:ipa_path] = ipa_path
          else
            out_params[:app_path] = app_path
          end
        else
          out_params[:app_path] = app_path if app_path
          out_params[:ipa_path] = ipa_path if ipa_path
        end

        out_params[:dsym_path] = dsym_path if dsym_path && (app_path || ipa_path)
        out_params[:upload_token] = upload_token if upload_token && !upload_token.empty?
        out_params[:variant_name] = variant_name if variant_name

        out_params
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

      def self.get_git_commit_name(sha)
        cmd = %(git name-rev --exclude='tags/*' --name-only "#{sha}")

        puts "Calling: #{cmd}" if FastlaneCore::Globals.verbose?

        result = Actions.sh(cmd, log: false).chomp

        puts "#{cmd} => #{result}" if FastlaneCore::Globals.verbose?

        result
      end

      def self.get_git_commits
        cmd = %(git log --format=%H -50)

        result = Actions.sh(cmd, log: false).chomp

        puts "#{cmd} => #{result}" if FastlaneCore::Globals.verbose?

        result.split(' ')
      end

      def self.get_history
        history = get_git_commits

        return '' unless !history.empty?

        history = history.map { |sha| convert_commit(sha) }

        Base64.strict_encode64("[#{history.join(',')}]")
      end

      def self.get_platform
        Actions.lane_context[Actions::SharedValues::PLATFORM_NAME] || :ios
      end

      def self.get_user_agent
        "Waldo fastlane/#{get_flavor} v#{Fastlane::Waldo::VERSION}"
      end

      def self.handle_error(message)
        UI.error(message)

        UI.error('No token for error report upload to Waldo!') unless @upload_token

        upload_error(message) if @upload_token
      end

      def self.has_git_command?
        cmd = %(which git)

        result = Actions.sh(cmd, log: false).chomp

        puts "#{cmd} => #{result}" if FastlaneCore::Globals.verbose?

        !result.empty?
      end

      def self.is_git_repository?
        cmd = %(git rev-parse)

        result = true

        Actions.sh(cmd,
                   log: false,
                   error_callback: ->(ignore) { result = false }
                  ).chomp

        puts "#{cmd} => #{result}" if FastlaneCore::Globals.verbose?

        result
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
        if !has_git_command?
          history_error = "noGitCommandFound"
        elsif !is_git_repository?
          history_error = "notGitRepository"
        else
          history = get_history
        end

        query = ''

        if history
          query += "&history=#{history}"
        elsif history_error
          query += "&historyError=#{history_error}"
        end

        query += "&variantName=#{@variant_name}" if @variant_name

        uri_string = 'https://api.waldo.io/versions'

        uri_string += "?#{query[1..-1]}" if !query.empty?

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

      def self.make_symbols_request(uri)
        if File.file?(@dsym_path)
          body_path = @dsym_path
        else
          dsym_basename = File.basename(@dsym_path)
          dsym_dirname = File.dirname(@dsym_path)

          body_path = File.join(Dir.tmpdir, "#{dsym_basename}.zip")

          unless zip(src_path: dsym_basename,
                     zip_path: body_path,
                     cd_path: dsym_dirname)
            return nil
          end
        end

        request = Net::HTTP::Post.new(uri.request_uri)

        request['Authorization'] = get_authorization
        request['Transfer-Encoding'] = 'chunked'
        request['User-Agent'] = get_user_agent

        request.body_stream = WaldoReadIO.new(body_path)
        request.content_type = 'application/zip'

        request
      end

      def self.make_symbols_uri
          uri_string = 'https://api.waldo.io/versions/'

          uri_string += @build_upload_id
          uri_string += '/symbols'

          URI(uri_string)
      end

      def self.parse_build_response(response)
        dump_response(response) if FastlaneCore::Globals.verbose?

        case response.code.to_i
        when 200..299
          UI.success('Build successfully uploaded to Waldo!')
        when 401
          handle_error('Token is invalid or missing for build upload to Waldo!')
        else
          handle_error("Build failed to upload to Waldo: #{response.code} #{response.message}")
        end

        result = JSON.parse(response.body)

        @build_upload_id = result["id"]
      end

      def self.parse_error_response(response)
        dump_response(response) if FastlaneCore::Globals.verbose?

        case response.code.to_i
        when 200..299
          UI.success('Error report successfully uploaded to Waldo!')
        when 401
          UI.error('Token is invalid or missing for error report upload to Waldo!')
        else
          UI.error("Error report failed to upload to Waldo: #{response.code} #{response.message}")
        end
      end

      def self.parse_symbols_response(response)
        dump_response(response) if FastlaneCore::Globals.verbose?

        case response.code.to_i
        when 200..299
          UI.success('Symbols successfully uploaded to Waldo!')
        when 401
          UI.error('Token is invalid or missing for symbols upload to Waldo!')
        else
          UI.error("Symbols failed to upload to Waldo: #{response.code} #{response.message}")
        end
      end

      def self.upload_build
        begin
          @variant_name ||= Actions.lane_context[Actions::SharedValues::GRADLE_BUILD_TYPE]

          uri = make_build_uri

          request = make_build_request(uri)

          return unless request

          UI.success('Uploading build to Waldo')

          dump_request(request) if FastlaneCore::Globals.verbose?

          Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
            http.read_timeout = 120 # 2 minutes

            parse_build_response(http.request(request))
          end
        rescue Net::ReadTimeout => exc
          handle_error('Build upload to Waldo timed out!')
        rescue => exc
          handle_error("Something went wrong uploading build to Waldo: #{exc.inspect.to_s}")
        ensure
          request.body_stream.close if request && request.body_stream
        end
      end

      def self.upload_error(message)
        begin
          uri = make_error_uri

          request = make_error_request(uri, message)

          UI.error('Uploading error report to Waldo')

          dump_request(request) if FastlaneCore::Globals.verbose?

          Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
            http.read_timeout = 30  # seconds

            parse_error_response(http.request(request))
          end
        rescue Net::ReadTimeout => exc
          UI.error('Error report upload to Waldo timed out!')
        rescue => exc
          UI.error("Something went wrong uploading error report to Waldo: #{exc.inspect.to_s}")
        end
      end

      def self.upload_symbols
        begin
          return unless @dsym_path

          uri = make_symbols_uri

          request = make_symbols_request(uri)

          return unless request

          UI.success('Uploading symbols to Waldo')

          dump_request(request) if FastlaneCore::Globals.verbose?

          Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
            http.read_timeout = 120 # 2 minutes

            parse_symbols_response(http.request(request))
          end
        rescue Net::ReadTimeout => exc
          handle_error('Symbols upload to Waldo timed out!')
        rescue => exc
          handle_error("Something went wrong uploading symbols to Waldo: #{exc.inspect.to_s}")
        ensure
          request.body_stream.close if request && request.body_stream
        end
      end

      def self.validate_parameters(params)
        @apk_path = params[:apk_path]
        @app_path = params[:app_path]
        @dsym_path = params[:dsym_path]
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
            unless File.exist?(@app_path)
              handle_error("Unable to find app at path '#{@app_path.to_s}'")

              return false
            end

            unless File.directory?(@app_path) && File.readable?(@app_path)
              handle_error("Unable to read app at path '#{@app_path.to_s}'")

              return false
            end
          elsif @ipa_path
            unless File.exist?(@ipa_path)
              handle_error("Unable to find IPA at path '#{@ipa_path.to_s}'")

              return false
            end

            unless File.file?(@ipa_path) && File.readable?(@ipa_path)
              handle_error("Unable to read IPA at path '#{@ipa_path.to_s}'")

              return false
            end
          end

          if @dsym_path
            unless File.exist?(@dsym_path)
              handle_error("Unable to find symbols at path '#{@dsym_path.to_s}'")

              return false
            end

            unless (File.directory?(@dsym_path) || File.file?(@dsym_path)) && File.readable?(@dsym_path)
              handle_error("Unable to read symbols at path '#{@dsym_path.to_s}'")

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
          cmd = %(zip -qry "#{zip_path}" "#{src_path}")

          result = Actions.sh(cmd, log: false)

          puts "#{cmd} => #{result}" if FastlaneCore::Globals.verbose?

          unless result.empty?
            handle_error("Unable to zip folder at path '#{src_path.to_s}' into '#{zip_path.to_s}'")

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
