require 'rails_helper'

RSpec.describe AiVerificationService, type: :service do
  let(:post) { create(:post, title: 'Test Title', content: 'Test content') }
  let(:service) { described_class.new(post) }
  let(:mock_client) { instance_double(OpenAI::Client) }

  before do
    allow(OpenAI::Client).to receive(:new).and_return(mock_client)
  end

  describe '#verify' do
    context 'when AI approves the content' do
      before do
        allow(mock_client).to receive(:chat).and_return(
          {
            'choices' => [
              {
                'message' => {
                  'content' => '{"approved": true, "reason": "Контент соответствует стандартам"}'
                }
              }
            ]
          }
        )
      end

      it 'returns success result' do
        result = service.verify

        expect(result[:success]).to be true
        expect(result[:message]).to include('Контент одобрен ИИ')
        expect(result[:message]).to include('Контент соответствует стандартам')
      end

      it 'calls OpenAI API with correct parameters' do
        expect(mock_client).to receive(:chat).with(
          parameters: {
            model: "gpt-4o-mini",
            messages: [
              {
                role: "system",
                content: include("Ты модератор контента")
              },
              {
                role: "user",
                content: "Заголовок: #{post.title}\n\nСодержание: #{post.content}"
              }
            ],
            temperature: 0.3
          }
        ).and_return(
          {
            'choices' => [
              {
                'message' => {
                  'content' => '{"approved": true, "reason": "OK"}'
                }
              }
            ]
          }
        )

        service.verify
      end
    end

    context 'when AI rejects the content' do
      before do
        allow(mock_client).to receive(:chat).and_return(
          {
            'choices' => [
              {
                'message' => {
                  'content' => '{"approved": false, "reason": "Контент содержит запрещенную информацию"}'
                }
              }
            ]
          }
        )
      end

      it 'returns failure result' do
        result = service.verify

        expect(result[:success]).to be false
        expect(result[:message]).to include('Контент отклонен ИИ')
        expect(result[:message]).to include('Контент содержит запрещенную информацию')
      end
    end

    context 'when AI response is not in JSON format but contains approval keywords' do
      before do
        allow(mock_client).to receive(:chat).and_return(
          {
            'choices' => [
              {
                'message' => {
                  'content' => 'Контент одобрен. Нарушений не выявлено.'
                }
              }
            ]
          }
        )
      end

      it 'returns success result' do
        result = service.verify

        expect(result[:success]).to be true
        expect(result[:message]).to include('Контент одобрен ИИ')
      end
    end

    context 'when AI response is not in JSON format and contains rejection keywords' do
      before do
        allow(mock_client).to receive(:chat).and_return(
          {
            'choices' => [
              {
                'message' => {
                  'content' => 'Контент отклонен. Обнаружены нарушения.'
                }
              }
            ]
          }
        )
      end

      it 'returns failure result' do
        result = service.verify

        expect(result[:success]).to be false
        expect(result[:message]).to include('Контент отклонен ИИ')
      end
    end

    context 'when OpenAI API raises an error' do
      before do
        allow(mock_client).to receive(:chat).and_raise(StandardError.new('API Error'))
      end

      it 'returns error result' do
        result = service.verify

        expect(result[:success]).to be false
        expect(result[:message]).to include('Ошибка при проверке ИИ')
        expect(result[:message]).to include('API Error')
      end
    end

    context 'when JSON parsing fails' do
      before do
        allow(mock_client).to receive(:chat).and_return(
          {
            'choices' => [
              {
                'message' => {
                  'content' => 'Invalid JSON response'
                }
              }
            ]
          }
        )
      end

      it 'falls back to keyword matching' do
        result = service.verify

        expect(result[:success]).to be false
        expect(result[:message]).to include('Контент не соответствует стандартам')
      end
    end

    context 'with different post content' do
      let(:post_with_long_content) { create(:post, :with_long_content) }
      let(:service_with_long_content) { described_class.new(post_with_long_content) }

      before do
        allow(mock_client).to receive(:chat).and_return(
          {
            'choices' => [
              {
                'message' => {
                  'content' => '{"approved": true, "reason": "Длинный контент проверен"}'
                }
              }
            ]
          }
        )
      end

      it 'handles different content types' do
        result = service_with_long_content.verify

        expect(result[:success]).to be true
        expect(result[:message]).to include('Длинный контент проверен')
      end
    end

    context 'with malformed API response' do
      before do
        allow(mock_client).to receive(:chat).and_return(
          {
            'choices' => [
              {
                'message' => {
                  'content' => '{"approved": true}'  # Missing reason field
                }
              }
            ]
          }
        )
      end

      it 'handles missing reason field' do
        result = service.verify

        expect(result[:success]).to be true
        expect(result[:message]).to include('Не указана причина')
      end
    end

    context 'with empty API response' do
      before do
        allow(mock_client).to receive(:chat).and_return(
          {
            'choices' => [
              {
                'message' => {
                  'content' => ''
                }
              }
            ]
          }
        )
      end

      it 'handles empty response' do
        result = service.verify

        expect(result[:success]).to be false
        expect(result[:message]).to include('Контент не соответствует стандартам')
      end
    end
  end

  describe 'service initialization' do
    it 'creates OpenAI client with correct token' do
      expect(OpenAI::Client).to receive(:new).with(access_token: ENV["CHAT_GPT_TOKEN"])
      described_class.new(post)
    end

    it 'stores post reference' do
      expect(service.instance_variable_get(:@post)).to eq(post)
    end
  end
end 