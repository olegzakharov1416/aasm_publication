require 'rails_helper'

RSpec.describe 'Basic Functionality', type: :feature do
  describe 'Post creation and state management' do
    it 'allows creating a post and managing its states' do
      post = create(:post, title: 'Test Post', content: 'Test content')
      expect(post).to be_created
      post.verify_with_ai!
      expect(post).to be_ai_verified
      post.verify!
      expect(post).to be_verified
      post.publish!
      expect(post).to be_published
      post.delete!
      expect(post).to be_deleted
      post.restore!
      expect(post).to be_created
    end
  end

  describe 'Post scopes' do
    let!(:created_post) { create(:post, state: 'created') }
    let!(:published_post) { create(:post, state: 'published') }
    let!(:deleted_post) { create(:post, state: 'deleted') }

    it 'filters posts correctly' do
      expect(Post.active.count).to eq(2)
      expect(Post.published.count).to eq(1)
      expect(Post.pending_review.count).to eq(1)
    end
  end

  describe 'AiVerificationService integration' do
    let(:post) { create(:post, title: 'Safe Content', content: 'This is safe content') }
    let(:service) { AiVerificationService.new(post) }

    it 'can verify content through AI service' do
      allow_any_instance_of(OpenAI::Client).to receive(:chat).and_return(
        {
          'choices' => [
            {
              'message' => {
                'content' => '{"approved": true, "reason": "Контент безопасен"}'
              }
            }
          ]
        }
      )
      result = service.verify
      expect(result[:success]).to be true
    end
  end
end
