module Fastlane
  module Helper
    class WaldoHelper
      require 'json'
      require 'net/http'

      def self.determine_asset_name
        platform = RUBY_PLATFORM.downcase

        if platform.include?('linux')
          ext = ''
          os = 'linux'
        elsif platform.include?('darwin')
          ext = ''
          os = 'macos'
        elsif platform.include?('mswin')
          ext = '.exe'
          os = 'windows'
        else
          UI.error("Unsupported platform: #{platform}")
        end

        if platform.include?('arm64')
          arch = 'arm64'
        elsif platform.include?('x86_64')
          arch = 'x86_64'
        else
          UI.error("Unsupported platform: #{platform}")
        end

        "waldo-agent-#{os}-#{arch}#{ext}"
      end

      def self.download(uri, path, retryAllowed)
        begin
          request_uri = uri.request_uri
          response = nil

          loop do
            response = Net::HTTP.get_response(uri)

            break unless response.is_a?(Net::HTTPRedirection)

            uri = URI.parse(response['location'])
          end

          code = response.code.to_i

          if code < 200 || code > 299
            UI.error("Unable to download #{request_uri}, HTTP status: #{response.code}")

            return retryAllowed && shouldRetry?(response)
          end

          fp = File.open(path, 'wb')

          fp.write(response.body)
        rescue => exc
          UI.error("Unable to download #{request_uri}: #{exc.inspect.to_s}")

          return retryAllowed
        ensure
          fp.close if fp
        end

        return false
      end

      def self.download_binary
        asset_name = determine_asset_name

        uri_string = 'https://github.com/waldoapp/waldo-go-agent/releases/latest/download/'

        uri_string += asset_name

        binary_path = File.join(Dir.tmpdir, 'waldo-agent')

		maxDownloadAttempts = 2

		for attempts in 1..maxDownloadAttempts do
          doRetry = download(URI(uri_string), binary_path, attempts < maxDownloadAttempts)

          break unless doRetry

		  UI.message("Failed download attempts: #{attempts} -- retrying…")
        end

        File.chmod(0755, binary_path)

        binary_path
      end

      def self.extract_build_id(output)
        last_line = output.lines(chomp: true).last

		JSON.parse(last_line, {symbolize_names: true})[:appVersionID]
      end

      def self.filter_parameters(in_params)
        out_params = {}

        apk_path = in_params[:apk_path]
        app_path = in_params[:app_path]
        git_branch = in_params[:git_branch]
        git_commit = in_params[:git_commit]
        upload_token = in_params[:upload_token]
        variant_name = in_params[:variant_name] || Actions.lane_context[Actions::SharedValues::GRADLE_BUILD_TYPE]

        apk_path.gsub!('\\ ', ' ') if apk_path
        app_path.gsub!('\\ ', ' ') if app_path

        out_params[:apk_path] = apk_path if apk_path
        out_params[:app_path] = app_path if app_path
        out_params[:git_branch] = git_branch if git_branch
        out_params[:git_commit] = git_commit if git_commit
        out_params[:upload_token] = upload_token if upload_token
        out_params[:variant_name] = variant_name if variant_name

        out_params
      end

      def self.shouldRetry?(response)
        [408, 429, 500, 502, 503, 504].include?(response.code.to_i)
      end

      def self.upload_build(params)
        apk_path = params[:apk_path]
        app_path = params[:app_path]

        if apk_path
          build_path = apk_path
        elsif app_path
          build_path = app_path
        else
          build_path = ''
        end

        command = []

        command << "WALDO_WRAPPER_NAME_OVERRIDE='Waldo Fastlane Plugin'"
        command << "WALDO_WRAPPER_VERSION_OVERRIDE='#{Fastlane::Waldo::VERSION}'"

        command << download_binary.shellescape
        command << 'upload'

        if params[:git_branch]
          command << '--git_branch'
          command << params[:git_branch]
        end

        if params[:git_commit]
          command << '--git_commit'
          command << params[:git_commit]
        end

        if params[:upload_token]
          command << '--upload_token'
          command << params[:upload_token]
        end

        if params[:variant_name]
          command << '--variant_name'
          command << params[:variant_name]
        end

        command << '--verbose' if FastlaneCore::Globals.verbose?

        command << build_path.shellescape

        output = Actions.sh_control_output(command.join(' '),
                                           print_command: FastlaneCore::Globals.verbose?,
                                           print_command_output: true)

        Actions.lane_context[Actions::SharedValues::WALDO_BUILD_ID] = extract_build_id(output)
      end
    end
  end
end
