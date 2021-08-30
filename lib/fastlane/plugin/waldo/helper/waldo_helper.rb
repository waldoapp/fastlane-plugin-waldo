module Fastlane
  module Helper
    class WaldoHelper
      def self.filter_parameters(in_params)
        out_params = {}

        apk_path = in_params[:apk_path]
        app_path = in_params[:app_path]
        dsym_path = in_params[:dsym_path]
        include_symbols = in_params[:include_symbols]
        ipa_path = in_params[:ipa_path]
        upload_token = in_params[:upload_token]
        variant_name = in_params[:variant_name] || Actions.lane_context[Actions::SharedValues::GRADLE_BUILD_TYPE]

        apk_path.gsub!("\\ ", ' ') if apk_path
        app_path.gsub!("\\ ", ' ') if app_path
        dsym_path.gsub!("\\ ", ' ') if dsym_path
        ipa_path.gsub!("\\ ", ' ') if ipa_path

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

        if app_path
            out_params[:dsym_path] = dsym_path if dsym_path
            out_params[:include_symbols] = include_symbols if include_symbols
        else
            out_params[:dsym_path] = dsym_path if dsym_path && ipa_path
        end

        out_params[:upload_token] = upload_token if upload_token
        out_params[:variant_name] = variant_name if variant_name

        out_params
      end

      def self.get_flavor
        case get_platform
        when :android
          'Android'
        when :ios
          'iOS'
        else
          'unknown'
        end
      end

      def self.get_platform
        Actions.lane_context[Actions::SharedValues::PLATFORM_NAME] || :ios
      end

      def self.get_script_path
        root = Pathname.new(File.expand_path('../../..', __FILE__))

        File.join(root, 'waldo', 'assets', 'WaldoCLI.sh')
      end

      def self.get_user_agent
        "Waldo fastlane/#{get_flavor} v#{Fastlane::Waldo::VERSION}"
      end

      def self.upload_build_with_symbols(params)
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
            build_path = ""
        end

        command = []

        command << "WALDO_UPLOAD_TOKEN='#{params[:upload_token]}'"
        command << "WALDO_USER_AGENT_OVERRIDE='#{get_user_agent}'"
        command << "WALDO_VARIANT_NAME='#{params[:variant_name]}'" if params[:variant_name]

        command << get_script_path.shellescape

        command << '--include_symbols' if params[:include_symbols]
        command << '--verbose' if FastlaneCore::Globals.verbose?

        command << build_path.shellescape
        command << params[:dsym_path].shellescape if params[:dsym_path]

        Actions.sh_control_output(command.join(' '),
                                  print_command: FastlaneCore::Globals.verbose?,
                                  print_command_output: true) do |error|
          # do nothing special, for now
        end
      end
    end
  end
end
