require 'fastlane_core/command_executor'
require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class WaldoHelper
      def find_waldo_command()
        path = FastlaneCore::CommandExecutor.which('waldo')

        unless path
          UI.user_error!("Waldo not installed, download from https://github.com/waldoapp/Waldo")
        end

        return path
      end

      def generate_command(params)
        command = []
        command << find_waldo_command()
        command << "upload '#{params[:app_path]}'"
        command << "--application '#{params[:application_id]}'"
        command << "--key '#{params[:api_key]}'"
        command << "--package '#{params[:package_name]}'"
        command << "--trace '#{params[:trace]}'" if params[:trace]
        command << "--variant '#{params[:variant_name]}'"

        return command
      end
    end
  end
end
