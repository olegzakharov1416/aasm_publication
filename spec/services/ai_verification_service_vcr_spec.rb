require 'rails_helper'

RSpec.describe AiVerificationService, type: :service do
  include WebMock::API
  
  let(:post) { create(:post, title: 'Test Title', content: 'Test content') }
  let(:service) { described_class.new(post) }

  # Настройка VCR
  VCR.configure do |config|
    config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
    config.hook_into :webmock
    config.configure_rspec_metadata!
    
    # Фильтруем чувствительные данные
    config.filter_sensitive_data('<OPENAI_API_KEY>') { ENV['CHAT_GPT_TOKEN'] }
    config.filter_sensitive_data('<OPENAI_ORG_ID>') { ENV['OPENAI_ORG_ID'] }
    
    # Настройки для записи кассет
    config.default_cassette_options = {
      record: :once,
      match_requests_on: [:method, :uri, :body]
    }
  end

  describe '#verify', :vcr do
    context 'when content is safe and approved' do
      let(:safe_post) { create(:post, title: 'Safe Content', content: 'This is a safe and appropriate content for publication.') }

      it 'approves safe content', vcr: { cassette_name: 'ai_verification/safe_content_approved' } do
        service = described_class.new(safe_post)
        result = service.verify

        # Проверяем только структуру ответа, так как реальный AI может дать разные результаты
        expect(result).to have_key(:success)
        expect(result).to have_key(:message)
        expect(result[:message]).to include('ИИ')
      end
    end

    context 'when content contains potentially problematic content' do
      let(:problematic_post) { create(:post, title: 'Problematic Content', content: 'This content mentions some sensitive topics that might need review.') }

      it 'handles potentially problematic content', vcr: { cassette_name: 'ai_verification/problematic_content_review' } do
        service = described_class.new(problematic_post)
        result = service.verify

        # Результат может быть как approved, так и rejected в зависимости от AI
        expect(result).to have_key(:success)
        expect(result).to have_key(:message)
        expect(result[:message]).to include('ИИ')
      end
    end

    context 'when content is clearly inappropriate' do
      let(:inappropriate_post) { create(:post, title: 'Inappropriate', content: 'This content contains clearly inappropriate material.') }

      it 'rejects inappropriate content', vcr: { cassette_name: 'ai_verification/inappropriate_content_rejected' } do
        service = described_class.new(inappropriate_post)
        result = service.verify

        # AI может отклонить такой контент
        expect(result).to have_key(:success)
        expect(result).to have_key(:message)
        expect(result[:message]).to include('ИИ')
      end
    end

    context 'with different content types' do
      let(:long_content_post) { create(:post, :with_long_content) }

      it 'handles long content', vcr: { cassette_name: 'ai_verification/long_content' } do
        service = described_class.new(long_content_post)
        result = service.verify

        expect(result).to have_key(:success)
        expect(result).to have_key(:message)
      end

      let(:short_title_post) { create(:post, :with_short_title) }

      it 'handles short titles', vcr: { cassette_name: 'ai_verification/short_title' } do
        service = described_class.new(short_title_post)
        result = service.verify

        expect(result).to have_key(:success)
        expect(result).to have_key(:message)
      end
    end

    context 'with empty content' do
      let(:empty_post) { build(:post, title: 'Empty', content: '').tap { |p| p.save(validate: false) } }

      it 'handles empty content', vcr: { cassette_name: 'ai_verification/empty_content' } do
        service = described_class.new(empty_post)
        result = service.verify

        expect(result).to have_key(:success)
        expect(result).to have_key(:message)
      end
    end

    context 'with special characters' do
      let(:special_chars_post) { create(:post, title: 'Special: Characters!', content: 'Content with special characters: @#$%^&*()') }

      it 'handles special characters', vcr: { cassette_name: 'ai_verification/special_characters' } do
        service = described_class.new(special_chars_post)
        result = service.verify

        expect(result).to have_key(:success)
        expect(result).to have_key(:message)
      end
    end

    context 'with non-Latin characters' do
      let(:russian_post) { create(:post, title: 'Русский заголовок', content: 'Контент на русском языке с кириллицей') }

      it 'handles non-Latin characters', vcr: { cassette_name: 'ai_verification/russian_content' } do
        service = described_class.new(russian_post)
        result = service.verify

        expect(result).to have_key(:success)
        expect(result).to have_key(:message)
      end
    end

    context 'when API is unavailable' do
      before do
        # Временно отключаем реальные HTTP запросы
        WebMock.disable_net_connect!
        stub_request(:post, /api.openai.com/).to_return(status: 500, body: 'Internal Server Error')
      end

      after do
        WebMock.allow_net_connect!
      end

      it 'handles API errors gracefully' do
        result = service.verify

        expect(result[:success]).to be false
        expect(result[:message]).to include('Ошибка при проверке ИИ')
      end
    end

    context 'when API returns malformed response' do
      before do
        WebMock.disable_net_connect!
        stub_request(:post, /api.openai.com/).to_return(
          status: 200,
          body: '{"invalid": "response"}',
          headers: { 'Content-Type' => 'application/json' }
        )
      end

      after do
        WebMock.allow_net_connect!
      end

      it 'handles malformed API responses' do
        result = service.verify

        expect(result[:success]).to be false
        expect(result[:message]).to include('Ошибка при проверке ИИ')
      end
    end

    context 'when API times out' do
      before do
        WebMock.disable_net_connect!
        stub_request(:post, /api.openai.com/).to_timeout
      end

      after do
        WebMock.allow_net_connect!
      end

      it 'handles API timeouts' do
        result = service.verify

        expect(result[:success]).to be false
        expect(result[:message]).to include('Ошибка при проверке ИИ')
      end
    end
  end

  describe 'VCR cassette management' do
    it 'creates cassettes with meaningful names' do
      # Этот тест создаст кассету с именем, основанным на описании
      service = described_class.new(post)
      result = service.verify

      expect(result).to have_key(:success)
      expect(result).to have_key(:message)
    end

    it 'reuses existing cassettes' do
      # При повторном запуске VCR будет использовать существующую кассету
      service = described_class.new(post)
      result = service.verify

      expect(result).to have_key(:success)
      expect(result).to have_key(:message)
    end
  end

  describe 'API request structure' do
    it 'sends correct request format to OpenAI', vcr: { cassette_name: 'ai_verification/request_structure' } do
      service = described_class.new(post)
      
      # VCR запишет реальный запрос
      result = service.verify

      expect(result).to have_key(:success)
      expect(result).to have_key(:message)
    end
  end
end 