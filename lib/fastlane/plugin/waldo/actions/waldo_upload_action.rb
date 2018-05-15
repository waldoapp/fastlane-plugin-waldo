module Fastlane
  module Actions
    class WaldoUploadAction < Action
      def self.run(params)
        params.values   # validate all inputs before looking for IPA

        command = Helper::WaldoHelper.generate_command(params)

        UI.success('Uploading app binary to Waldo backend—this could take a while…')

        sh command

        UI.success('App binary successfully uploaded to Waldo backend!')
      end

      #########################################################################

      def self.description
        "Upload app binary to Waldo backend"
      end

      def self.details
        [
          "This action wil upload an app binary to the Waldo backend for processing."
        ]/join(' ')
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :api_key,
                                       env_name: "WALDO_API_KEY",
                                       description: "The API key",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :app_path,
                                       env_name: "WALDO_APP_PATH",
                                       description: "The path to the app binary",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :application_id,
                                       env_name: "WALDO_APPLICATION_ID",
                                       description: "The application ID",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :package_name,
                                       env_name: "WALDO_PACKAGE_NAME",
                                       description: "The package name of the app",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :trace,
                                       env_name: "WALDO_TRACE",
                                       description: "Trace HTTP requests/responses",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :variant_name,
                                       env_name: "WALDO_VARIANT_NAME",
                                       description: "The variant name of the app",
                                       optional: false,
                                       type: String)
        ]
      end

      def self.authors
        ["eBardX"]
      end

      def self.is_supported?(platform)
        platform == :ios
      end

      def self.example_code
        [
          "waldo_upload(
            app_path: '/Users/jgp/Desktop/XestiMonitorsDemo.ipa',
            application_id: 'app-b6ef42d5f619357b',
            api_key: '9191623f3d80780c391be39085ed2652',
            package_name: 'com.xesticode.XestiMonitorsDemo-iOS',
            variant_name: 'ad-hoc'
          )"
        ]
      end

      def self.category
        :testing
      end
    end
  end
end
