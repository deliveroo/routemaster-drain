RSpec.shared_examples 'a job backend' do
  class TestJob
    def perform(x, y); end
  end

  let(:job) { TestJob.new }
  let(:x) { 123 }
  let(:y) { 'hello' }

  before do
    allow(TestJob).to receive(:new).and_return(job)
    allow(job).to receive(:perform).and_call_original
    described_class.new.enqueue('test_queue', TestJob, x, y)
  end

  describe '#enqueue' do
    it 'should execute jobs with a #perform method with the passed arguments' do
      expect(job).to have_received(:perform).with(x, y)
    end
  end
end
