require 'rails_helper'

RSpec.describe Post, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:content) }
  end

  describe 'scopes' do
    let!(:created_post) { create(:post, state: 'created') }
    let!(:ai_verified_post) { create(:post, state: 'ai_verified') }
    let!(:verified_post) { create(:post, state: 'verified') }
    let!(:published_post) { create(:post, state: 'published') }
    let!(:deleted_post) { create(:post, state: 'deleted') }

    describe '.active' do
      it 'returns posts that are not deleted' do
        expect(Post.active).to include(created_post, ai_verified_post, verified_post, published_post)
        expect(Post.active).not_to include(deleted_post)
      end
    end

    describe '.published' do
      it 'returns only published posts' do
        expect(Post.published).to include(published_post)
        expect(Post.published).not_to include(created_post, ai_verified_post, verified_post, deleted_post)
      end
    end

    describe '.pending_review' do
      it 'returns posts that need review' do
        expect(Post.pending_review).to include(created_post, ai_verified_post)
        expect(Post.pending_review).not_to include(verified_post, published_post, deleted_post)
      end
    end
  end

  describe 'AASM states and transitions' do
    let(:post) { create(:post) }

    describe 'initial state' do
      it 'starts in created state' do
        expect(post).to be_created
      end
    end

    describe 'verify_with_ai' do
      it 'transitions from created to ai_verified' do
        expect(post).to be_created
        post.verify_with_ai!
        expect(post).to be_ai_verified
      end
    end

    describe 'verify' do
      it 'transitions from ai_verified to verified' do
        post.verify_with_ai!
        expect(post).to be_ai_verified
        post.verify!
        expect(post).to be_verified
      end
    end

    describe 'publish' do
      it 'transitions from verified to published' do
        post.verify_with_ai!
        post.verify!
        expect(post).to be_verified
        post.publish!
        expect(post).to be_published
      end
    end

    describe 'delete' do
      it 'transitions from any state to deleted' do
        states = [ :created, :ai_verified, :verified, :published ]

        states.each do |state|
          post = create(:post, state: state)
          post.delete!
          expect(post).to be_deleted
        end
      end
    end

    describe 'restore' do
      it 'transitions from deleted to created' do
        post.delete!
        expect(post).to be_deleted
        post.restore!
        expect(post).to be_created
      end
    end

    describe 'reset_to_created' do
      it 'transitions from verified states to created' do
        states = [ :ai_verified, :verified, :published ]

        states.each do |state|
          post = create(:post, state: state)
          post.reset_to_created!
          expect(post).to be_created
        end
      end
    end
  end

  describe '#reset_state_after_edit!' do
    context 'when post is ai_verified' do
      let(:post) { create(:post, :ai_verified) }

      it 'resets to created state' do
        post.reset_state_after_edit!
        expect(post).to be_created
      end
    end

    context 'when post is verified' do
      let(:post) { create(:post, :verified) }

      it 'resets to created state' do
        post.reset_state_after_edit!
        expect(post).to be_created
      end
    end

    context 'when post is published' do
      let(:post) { create(:post, :published) }

      it 'resets to created state' do
        post.reset_state_after_edit!
        expect(post).to be_created
      end
    end

    context 'when post is created' do
      let(:post) { create(:post) }

      it 'stays in created state' do
        post.reset_state_after_edit!
        expect(post).to be_created
      end
    end

    context 'when post is deleted' do
      let(:post) { create(:post, :deleted) }

      it 'stays in deleted state' do
        post.reset_state_after_edit!
        expect(post).to be_deleted
      end
    end
  end
end
