class Post < ApplicationRecord
  include AASM

  validates :title, presence: true
  validates :content, presence: true

  aasm column: :state do
    state :created, initial: true
    state :ai_verified
    state :verified
    state :published
    state :deleted

    event :verify_with_ai do
      transitions from: :created, to: :ai_verified
    end

    event :verify do
      transitions from: :ai_verified, to: :verified
    end

    event :publish do
      transitions from: :verified, to: :published
    end

    event :delete do
      transitions from: [ :created, :ai_verified, :verified, :published ], to: :deleted
    end

    event :restore do
      transitions from: :deleted, to: :created
    end

    event :reset_to_created do
      transitions from: [ :ai_verified, :verified, :published ], to: :created
    end
  end

  scope :active, -> { where.not(state: :deleted) }
  scope :published, -> { where(state: :published) }
  scope :pending_review, -> { where(state: [ :created, :ai_verified ]) }

  def reset_state_after_edit!
    if ai_verified? || verified? || published?
      aasm.fire!(:reset_to_created)
    end
  end
end
