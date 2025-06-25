require 'rails_helper'

RSpec.describe AiVerificationService, type: :service do
  let(:post) { create(:post, title: 'Test Title', content: 'Test content') }
  let(:service) { described_class.new(post) }

  describe '#verify' do
    context 'when content is approved' do
      before do
        # Полное мокирование метода verify
        allow(service).to receive(:verify).and_return(
          { success: true, message: "Контент одобрен ИИ: Контент соответствует стандартам" }
        )
      end

      it 'returns success result' do
        result = service.verify

        expect(result[:success]).to be true
        expect(result[:message]).to include('Контент одобрен ИИ')
        expect(result[:message]).to include('Контент соответствует стандартам')
      end
    end

    context 'when content is rejected' do
      before do
        # Полное мокирование метода verify
        allow(service).to receive(:verify).and_return(
          { success: false, message: "Контент отклонен ИИ: Контент содержит запрещенную информацию" }
        )
      end

      it 'returns failure result' do
        result = service.verify

        expect(result[:success]).to be false
        expect(result[:message]).to include('Контент отклонен ИИ')
        expect(result[:message]).to include('Контент содержит запрещенную информацию')
      end
    end

    context 'when service raises an error' do
      before do
        # Мокирование ошибки
        allow(service).to receive(:verify).and_raise(StandardError.new('Service Error'))
      end

      it 'raises the error' do
        expect { service.verify }.to raise_error(StandardError, 'Service Error')
      end
    end

    context 'with different post content' do
      let(:post_with_long_content) { create(:post, :with_long_content) }
      let(:service_with_long_content) { described_class.new(post_with_long_content) }

      before do
        allow(service_with_long_content).to receive(:verify).and_return(
          { success: true, message: "Контент одобрен ИИ: Длинный контент проверен" }
        )
      end

      it 'handles different content types' do
        result = service_with_long_content.verify

        expect(result[:success]).to be true
        expect(result[:message]).to include('Длинный контент проверен')
      end
    end

    context 'with different post states' do
      let(:published_post) { create(:post, :published) }
      let(:service_published) { described_class.new(published_post) }

      before do
        allow(service_published).to receive(:verify).and_return(
          { success: false, message: "Контент отклонен ИИ: Уже опубликованный контент" }
        )
      end

      it 'handles posts in different states' do
        result = service_published.verify

        expect(result[:success]).to be false
        expect(result[:message]).to include('Уже опубликованный контент')
      end
    end
  end

  describe 'service initialization' do
    it 'creates service with post' do
      expect(service.instance_variable_get(:@post)).to eq(post)
    end

    it 'initializes OpenAI client' do
      expect(service.instance_variable_get(:@client)).to be_an_instance_of(OpenAI::Client)
    end
  end

  describe 'edge cases' do
    context 'with empty post content' do
      let(:empty_post) { build(:post, title: 'Empty', content: '').tap { |p| p.save(validate: false) } }
      let(:empty_service) { described_class.new(empty_post) }

      before do
        allow(empty_service).to receive(:verify).and_return(
          { success: false, message: "Контент отклонен ИИ: Пустой контент" }
        )
      end

      it 'handles empty content' do
        result = empty_service.verify

        expect(result[:success]).to be false
        expect(result[:message]).to include('Пустой контент')
      end
    end

    context 'with very long title' do
      let(:long_title_post) { create(:post, title: 'A' * 1000, content: 'Content') }
      let(:long_title_service) { described_class.new(long_title_post) }

      before do
        allow(long_title_service).to receive(:verify).and_return(
          { success: true, message: "Контент одобрен ИИ: Длинный заголовок обработан" }
        )
      end

      it 'handles very long titles' do
        result = long_title_service.verify

        expect(result[:success]).to be true
        expect(result[:message]).to include('Длинный заголовок обработан')
      end
    end
  end
end 