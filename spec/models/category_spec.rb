require 'rails_helper'

RSpec.describe Category, type: :model do
  describe 'associations' do
    it { should have_many(:promotions).through(:product_category_promotions) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:code) }
    it { should validate_uniqueness_of(:code).case_insensitive.with_message('já está em uso') }
  end
end
