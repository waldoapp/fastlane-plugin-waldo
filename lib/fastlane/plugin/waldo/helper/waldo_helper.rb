module Fastlane
  module Helper
    class WaldoHelper
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

      def self.download(uri, path)
        begin
          request_uri = uri.request_uri
          response = nil

          loop do
            response = Net::HTTP.get_response(uri)

            break unless response.is_a?(Net::HTTPRedirection)

            uri = URI.parse(response['location'])
          end

          fp = File.open(path, 'wb')

          fp.write(response.body)
        rescue => exc
          UI.error("Unable to download #{request_uri}: #{exc.inspect.to_s}")
        ensure
          fp.close if fp
        end
      end

      def self.download_binary
        asset_name = determine_asset_name

        uri_string = 'https://github.com/waldoapp/waldo-go-agent/releases/latest/download/'

        uri_string += asset_name

        binary_path = File.join(Dir.tmpdir, 'waldo-agent')

        download(URI(uri_string), binary_path)

        File.chmod(0755, binary_path)

        binary_path
      end

      def self.filter_parameters(in_params)
        out_params = {}

        apk_path = in_params[:apk_path]
        app_path = in_params[:app_path]
        git_branch = in_params[:git_branch]
        git_commit = in_params[:git_commit]
        ipa_path = in_params[:ipa_path]
        upload_token = in_params[:upload_token]
        variant_name = in_params[:variant_name] || Actions.lane_context[Actions::SharedValues::GRADLE_BUILD_TYPE]

        apk_path.gsub!('\\ ', ' ') if apk_path
        app_path.gsub!('\\ ', ' ') if app_path
        ipa_path.gsub!('\\ ', ' ') if ipa_path

        out_params[:apk_path] = apk_path if apk_path

        if app_path && ipa_path
          if !File.exist?(app_path)
            out_params[:ipa_path] = ipa_path

            app_path = nil
          elsif !File.exist?(ipa_path)
            out_params[:app_path] = app_path

            ipa_path = nil
          elsif File.mtime(app_path) < File.mtime(ipa_path)
            out_params[:ipa_path] = ipa_path

            app_path = nil
          else
            out_params[:app_path] = app_path

            ipa_path = nil
          end
        else
          out_params[:app_path] = app_path if app_path
          out_params[:ipa_path] = ipa_path if ipa_path
        end

        out_params[:git_branch] = git_branch if git_branch
        out_params[:git_commit] = git_commit if git_commit
        out_params[:upload_token] = upload_token if upload_token
        out_params[:variant_name] = variant_name if variant_name

        out_params
      end

      def self.upload_build(params)
        apk_path = params[:apk_path]
        app_path = params[:app_path]
        ipa_path = params[:ipa_path]

        if apk_path
          build_path = apk_path
        elsif app_path
          build_path = app_path
        elsif ipa_path
          build_path = ipa_path
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

        Actions.sh_control_output(command.join(' '),
                                  print_command: FastlaneCore::Globals.verbose?,
                                  print_command_output: true) do |error|
          # do nothing special, for now
        end
      end
    end
  end
end
