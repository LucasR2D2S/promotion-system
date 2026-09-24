require 'rails_helper'

feature 'Admin delete a category' do
  scenario 'successfully, keeping the promotions that used it' do
    user = User.create!(email: 'lucas@gmail.com', password: '123456')
    category = Category.create!(name: 'Natalinas', code: 'NATAL')
    promotion = Promotion.create!(name: 'Natal', description: 'Promoção de Natal',
                                  code: 'NATAL10', discount_rate: 10, coupon_quantity: 100,
                                  expiration_date: '22/12/2033', user: user,
                                  categories: [category])

    login_as user, scope: :user
    visit category_path(category)

    expect { click_button 'Apagar categoria' }.to change(Category, :count).by(-1)
    expect(current_path).to eq categories_path
    expect(page).to have_content 'Categoria apagada com sucesso!'
    expect(promotion.reload.categories).to be_empty
  end
end
