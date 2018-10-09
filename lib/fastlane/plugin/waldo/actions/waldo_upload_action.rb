require_relative '../helper/waldo_helper'

module Fastlane
  module Actions
    class WaldoUploadAction < Action
      def self.run(params)
        params.values   # validate all inputs before looking for the IPA

        FastlaneCore::PrintTable.print_values(config: params,
                                              title: "Summary for waldo_upload #{Fastlane::Waldo::VERSION}")

        if params[:ipa_path]
          command = Helper::WaldoHelper.generate_waldo_command('upload', params)
        else
          UI.user_error!("You must pass an IPA file to the Waldo upload action")
        end

        UI.success('Uploading the build to Waldo. This could take a while…')

        UI.verbose(command)

        result = Actions.sh_control_output(command,
                                           print_command: false,
                                           print_command_output: false,
                                           error_callback: proc do |error|
                                             UI.user_error!(error)
                                           end)

        UI.verbose(result)

        UI.success('Build successfully uploaded to Waldo!')
      end

      def self.authors
        ["eBardX"]
      end

      def self.available_options
        platform = Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]

        if platform == :ios || platform.nil?
          ipa_path_default = Dir["*.ipa"].sort_by { |x| File.mtime(x) }.last
        end

        [
          # iOS-specific
          FastlaneCore::ConfigItem.new(key: :ipa_path,
                                       env_name: "WALDO_IPA_PATH",
                                       description: "Path to your IPA file. Optional if you use the _gym_ or _xcodebuild_ action",
                                       default_value: Actions.lane_context[SharedValues::IPA_OUTPUT_PATH] || ipa_path_default,
                                       default_value_dynamic: true,
                                       optional: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("Unable to find IPA file at path '#{value}'") unless File.exist?(value)
                                       end),
          # General
          FastlaneCore::ConfigItem.new(key: :api_key,
                                       env_name: "WALDO_API_KEY",
                                       description: "Waldo API key. Overrides value in Waldo configuration file",
                                       optional: true,
                                       sensitive: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("No API key for Waldo given, pass using `api_key: 'key'`") unless value && !value.empty?
                                       end),
          FastlaneCore::ConfigItem.new(key: :application_id,
                                       env_name: "WALDO_APPLICATION_ID",
                                       description: "Waldo application ID. Overrides value in Waldo configuration file",
                                       optional: true,
                                       sensitive: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("No application ID for Waldo given, pass using `application_id: 'id'`") unless value && !value.empty?
                                       end),
          FastlaneCore::ConfigItem.new(key: :configuration_path,
                                       env_name: "WALDO_CONFIGURATION_PATH",
                                       description: "Path to your Waldo configuration file. Defaults to `./.waldo.yml`",
                                       optional: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("Path '#{value}' not found") unless File.exist?(value)
                                       end)
        ]
      end

      def self.category
        :testing
      end

      def self.description
        "Upload a new build to [Waldo](https://www.waldo.io)"
      end

      def self.example_code
        [
          'waldo_upload',
          'waldo_upload(
            ipa_path: "./MyApp.ipa",
            configuration_path: "./Waldo.yml"
          )',
          'waldo_upload(
            ipa_path: "./MyApp.ipa",
            api_key: "...",
            application_id: "..."
          )'
        ]
      end

      def self.is_supported?(platform)
        [:ios].include?(platform)
      end
    end
  end
end
