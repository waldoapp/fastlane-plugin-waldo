module Fastlane
  module Actions
    class WaldoAction < Action
      def self.run(params)
        params.values   # validate all inputs

        platform = Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]

        if platform == :android
          UI.user_error!("You must pass an APK path to the Waldo action") unless params[:apk_path]
        elsif platform == :ios || platform.nil?
          UI.user_error!("You must pass an IPA path to the Waldo action") unless params[:ipa_path]
        end

        UI.user_error!("You must pass an API key to the Waldo action") unless params[:api_key]
        UI.user_error!("You must pass an application ID to the Waldo action") unless params[:application_id]

        FastlaneCore::PrintTable.print_values(config: params,
                                              title: "Summary for waldo #{Fastlane::Waldo::VERSION.to_s}")

        Helper::WaldoHelper.upload_build(params)
      end

      def self.authors
        ["eBardX"]
      end

      def self.available_options
        platform = Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]

        if platform == :android
          apk_path_default = Dir["*.apk"].last || Dir[File.join("app", "build", "outputs", "apk", "app-release.apk")].last
        elsif platform == :ios || platform.nil?
          ipa_path_default = Dir["*.ipa"].sort_by { |x| File.mtime(x) }.last
        end

        [
          # iOS-specific
          FastlaneCore::ConfigItem.new(key: :ipa_path,
                                       env_name: "WALDO_IPA_PATH",
                                       description: "Path to your IPA file. Optional if you use the _gym_ or _xcodebuild_ action",
                                       default_value: Actions.lane_context[Actions::SharedValues::IPA_OUTPUT_PATH] || ipa_path_default,
                                       default_value_dynamic: true,
                                       optional: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("Unable to find IPA file at path '#{value.to_s}'") unless File.exist?(value)
                                       end),
          # Android-specific
          FastlaneCore::ConfigItem.new(key: :apk_path,
                                       env_name: "WALDO_APK_PATH",
                                       description: "Path to your APK file. Optional if you use the _gradle_ action",
                                       default_value: Actions.lane_context[Actions::SharedValues::GRADLE_APK_OUTPUT_PATH] || apk_path_default,
                                       default_value_dynamic: true,
                                       optional: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("Unable to find APK file at path '#{value.to_s}'") unless File.exist?(value)
                                       end),
          # General
          FastlaneCore::ConfigItem.new(key: :api_key,
                                       env_name: "WALDO_API_KEY",
                                       description: "Waldo API key",
                                       optional: true,
                                       sensitive: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("No API key for Waldo given, pass using `api_key: 'key'`") unless value && !value.empty?
                                       end),
          FastlaneCore::ConfigItem.new(key: :application_id,
                                       env_name: "WALDO_APPLICATION_ID",
                                       description: "Waldo application ID",
                                       optional: true,
                                       sensitive: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("No application ID for Waldo given, pass using `application_id: 'id'`") unless value && !value.empty?
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
          'waldo',
          'waldo(
            api_key: "...",
            application_id: "..."
          )',
          'waldo(
            apk_path: "./MyApp.apk",
            api_key: "...",
            application_id: "..."
          )',
          'waldo(
            ipa_path: "./MyApp.ipa",
            api_key: "...",
            application_id: "..."
          )'
        ]
      end

      def self.is_supported?(platform)
        [:android, :ios].include?(platform)
      end
    end
  end
end
