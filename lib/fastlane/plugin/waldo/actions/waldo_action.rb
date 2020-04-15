module Fastlane
  module Actions
    class WaldoAction < Action
      def self.run(params)
        mparams = Helper::WaldoHelper.filter_parameters(params)

        return unless Helper::WaldoHelper.validate_parameters(mparams)

        FastlaneCore::PrintTable.print_values(config: mparams,
                                              title: "Summary for waldo #{Fastlane::Waldo::VERSION.to_s}")

        Helper::WaldoHelper.upload_build
        Helper::WaldoHelper.upload_symbols
      end

      def self.authors
        ['eBardX']
      end

      def self.available_options
        case Helper::WaldoHelper.get_platform
        when :android
          apk_path_default = Dir["*.apk"].last || Dir[File.join('app', 'build', 'outputs', 'apk', 'app-release.apk')].last
        when :ios
          app_path_default = Dir["*.app"].sort_by { |x| File.mtime(x) }.last
          dsym_path_default = Helper::WaldoHelper.get_default_dsym_path
          ipa_path_default = Dir["*.ipa"].sort_by { |x| File.mtime(x) }.last
        end

        [
          # iOS-specific
          FastlaneCore::ConfigItem.new(key: :app_path,
                                       env_name: 'WALDO_APP_PATH',
                                       description: 'Path to your app file',
                                       default_value: app_path_default,
                                       default_value_dynamic: true,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :ipa_path,
                                       env_name: 'WALDO_IPA_PATH',
                                       description: 'Path to your IPA file (optional if you use the _gym_ or _xcodebuild_ action)',
                                       default_value: Actions.lane_context[Actions::SharedValues::IPA_OUTPUT_PATH] || ipa_path_default,
                                       default_value_dynamic: true,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :dsym_path,
                                       env_name: 'WALDO_DSYM_PATH',
                                       description: 'Path to your dSYM file(s) (optional if you use the _gym_ or _xcodebuild_ action)',
                                       default_value: dsym_path_default,
                                       default_value_dynamic: true,
                                       optional: true),
          # Android-specific
          FastlaneCore::ConfigItem.new(key: :apk_path,
                                       env_name: 'WALDO_APK_PATH',
                                       description: 'Path to your APK file (optional if you use the _gradle_ action)',
                                       default_value: Actions.lane_context[Actions::SharedValues::GRADLE_APK_OUTPUT_PATH] || apk_path_default,
                                       default_value_dynamic: true,
                                       optional: true),
          # General
          FastlaneCore::ConfigItem.new(key: :upload_token,
                                       env_name: 'WALDO_UPLOAD_TOKEN',
                                       description: 'Waldo upload token',
                                       optional: true,
                                       sensitive: true),
          FastlaneCore::ConfigItem.new(key: :variant_name,
                                       env_name: 'WALDO_VARIANT_NAME',
                                       description: 'Waldo variant name',
                                       optional: true,
                                       sensitive: true)
        ]
      end

      def self.category
        :testing
      end

      def self.description
        'Upload a new build to [Waldo](https://www.waldo.io)'
      end

      def self.example_code
        [
          'waldo',
          "waldo(
            upload_token: '...'
          )",
          "waldo(
            apk_path: './YourApp.apk',
            upload_token: '...'
          )",
          "waldo(
            ipa_path: './YourApp.ipa',
            upload_token: '...'
          )",
          "waldo(
            app_path: './YourApp.app',
            upload_token: '...'
          )"
        ]
      end

      def self.is_supported?(platform)
        [:android, :ios].include?(platform)
      end
    end
  end
end
