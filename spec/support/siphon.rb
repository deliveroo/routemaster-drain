RSpec.shared_examples 'supports siphon' do
  context "if a siphon is defined" do
    let(:siphon_double) { double(new: siphon_instance) }
    let(:siphon_instance) { double(call: nil) }
    let(:options){ { siphon_events: { payload[0]['topic'] => siphon_double } } }

    it "calls the siphon with the event" do
      perform
      expect(siphon_double).to have_received(:new).with(payload[0]).at_least(:once)
      expect(siphon_instance).to have_received(:call).at_least(:once)
    end
  end
end
