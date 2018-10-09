require 'fastlane_core/command_executor'

module Fastlane
  module Helper
    class WaldoHelper
      def self.find_waldo_command()
        path = FastlaneCore::CommandExecutor.which('waldo')

        unless path
          UI.user_error!("Waldo not installed, download from https://github.com/waldoapp/waldo-cli/releases")
        end

        return path
      end

      def self.generate_waldo_command(cmd, params)
        command = []
        command << find_waldo_command()
        command << "#{cmd} '#{params[:ipa_path]}'"
        command << "--application '#{params[:application_id]}'" if params[:application_id]
        command << "--configuration '#{params[:configuration_path]}'" if params[:configuration_path]
        command << "--key '#{params[:api_key]}'" if params[:api_key]

        return command.join(' ')
      end
    end
  end
end
