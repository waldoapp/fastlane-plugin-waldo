module Fastlane
  module Actions
    class WaldoAction < Action
      def self.run(params)
        params.values   # validate all inputs

        platform = Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]

        if platform == :android
          UI.error("You must pass an APK path to the Waldo action") and return unless params[:apk_path]
        elsif platform == :ios || platform.nil?
          UI.error("You must pass an IPA path to the Waldo action") and return unless params[:ipa_path]
        end

        UI.error("You must pass an upload token to the Waldo action") and return unless params[:upload_token]

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
                                         UI.error("Unable to find IPA file at path '#{value.to_s}'") unless File.exist?(value)
                                       end),
          # Android-specific
          FastlaneCore::ConfigItem.new(key: :apk_path,
                                       env_name: "WALDO_APK_PATH",
                                       description: "Path to your APK file. Optional if you use the _gradle_ action",
                                       default_value: Actions.lane_context[Actions::SharedValues::GRADLE_APK_OUTPUT_PATH] || apk_path_default,
                                       default_value_dynamic: true,
                                       optional: true,
                                       verify_block: proc do |value|
                                         UI.error("Unable to find APK file at path '#{value.to_s}'") unless File.exist?(value)
                                       end),
          # General
          FastlaneCore::ConfigItem.new(key: :upload_token,
                                       env_name: "WALDO_UPLOAD_TOKEN",
                                       description: "Waldo upload token",
                                       optional: true,
                                       sensitive: true,
                                       verify_block: proc do |value|
                                         UI.error("No upload token for Waldo given, pass using `upload_token: 'value'`") unless value && !value.empty?
                                       end),
          FastlaneCore::ConfigItem.new(key: :variant_name,
                                       env_name: "WALDO_VARIANT_NAME",
                                       description: "Waldo variant name",
                                       optional: true,
                                       sensitive: true,
                                       verify_block: proc do |value|
                                         UI.error("No variant name for Waldo given, pass using `variant_name: 'value'`") unless value && !value.empty?
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
            upload_token: "..."
          )',
          'waldo(
            apk_path: "./YourApp.apk",
            upload_token: "..."
          )',
          'waldo(
            ipa_path: "./YourApp.ipa",
            upload_token: "..."
          )'
        ]
      end

      def self.is_supported?(platform)
        [:android, :ios].include?(platform)
      end
    end
  end
end
