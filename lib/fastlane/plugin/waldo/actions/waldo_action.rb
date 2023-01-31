module Fastlane
  module Actions
    class WaldoAction < Action
      def self.run(params)
        mparams = Helper::WaldoHelper.filter_parameters(params)

        FastlaneCore::PrintTable.print_values(config: mparams,
                                              title: "Summary for waldo #{Fastlane::Waldo::VERSION.to_s}")

        Helper::WaldoHelper.upload_build(mparams)
      end

      def self.authors
        ['eBardX']
      end

      def self.available_options
        [
          # iOS-specific
          FastlaneCore::ConfigItem.new(key: :app_path,
                                       env_name: 'WALDO_APP_PATH',
                                       description: 'Path to your app file',
                                       optional: true),
          # Android-specific
          FastlaneCore::ConfigItem.new(key: :apk_path,
                                       env_name: 'WALDO_APK_PATH',
                                       description: 'Path to your APK file (optional if you use the _gradle_ action)',
                                       default_value: Actions.lane_context[Actions::SharedValues::GRADLE_APK_OUTPUT_PATH],
                                       default_value_dynamic: true,
                                       optional: true),
          # General
          FastlaneCore::ConfigItem.new(key: :upload_token,
                                       env_name: 'WALDO_UPLOAD_TOKEN',
                                       description: 'Upload token',
                                       optional: true,
                                       sensitive: true),
          FastlaneCore::ConfigItem.new(key: :variant_name,
                                       env_name: 'WALDO_VARIANT_NAME',
                                       description: 'Variant name',
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :git_branch,
                                       env_name: 'WALDO_GIT_BRANCH',
                                       description: 'Branch name for originating git commit',
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :git_commit,
                                       env_name: 'WALDO_GIT_COMMIT',
                                       description: 'Hash of originating git commit',
                                       optional: true)
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
