describe Fastlane::Actions::WaldoUploadAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The waldo plugin is working!")

      Fastlane::Actions::WaldoUploadAction.run(nil)
    end
  end
end
