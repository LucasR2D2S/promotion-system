require 'rails_helper'

RSpec.describe Category, type: :model do
  describe 'associations' do
    it { should have_and_belong_to_many(:promotions).class_name('Promotion') }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:code) }
    it { should validate_uniqueness_of(:code) }
  end
end
