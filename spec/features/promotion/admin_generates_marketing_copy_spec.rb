require 'rails_helper'

feature 'Admin generates a marketing e-mail with AI' do
  let(:user) { create(:user) }
  let(:endpoint) { "#{Rails.configuration.x.ai.base_url.chomp('/')}/chat/completions" }

  def stub_llm(**response)
    stub_request(:post, endpoint).to_return(**response)
  end

  def completion(copy)
    { status: 200, body: { choices: [{ message: { content: copy.to_json } }] }.to_json }
  end

  scenario 'and sees the copy with the merge tags highlighted' do
    promotion = create(:promotion, name: 'Natal', discount_rate: 15)
    stub_llm(**completion(subject: 'Natal: 15% OFF', preheader: 'Presentes com desconto',
                          body: "Olá, {{NOME}}!\n\nUse o cupom {{CUPOM}} e ganhe 15%.\n\nEquipe Promotion Store",
                          call_to_action: 'Ver ofertas'))

    login_as user, scope: :user
    visit promotion_path(promotion)
    click_on 'Gerar e-mail marketing com IA'

    expect(page).to have_content 'E-mail marketing: Natal'
    expect(page).to have_content 'Natal: 15% OFF'
    expect(page).to have_css('#marketing-copy-body mark', text: '{{CUPOM}}')
    expect(page).to have_css('#marketing-copy-body mark', text: '{{NOME}}')
  end

  scenario 'and the model text is escaped, never rendered as HTML' do
    promotion = create(:promotion, discount_rate: 15)
    stub_llm(**completion(subject: '15% OFF', preheader: 'Ofertas', call_to_action: 'Ver',
                          body: "15% OFF <script>alert(1)</script> {{CUPOM}}"))

    login_as user, scope: :user
    visit promotion_path(promotion)
    click_on 'Gerar e-mail marketing com IA'

    # Rejected by the validation (HTML), so nothing from the model reaches the page.
    expect(page).to have_content 'A IA não gerou um texto que atenda às regras da campanha'
    expect(page).not_to have_css('script', visible: :all, text: 'alert(1)')
  end

  scenario 'and sees a friendly message when the AI service is down' do
    promotion = create(:promotion)
    stub_request(:post, endpoint).to_raise(Errno::ECONNREFUSED)

    login_as user, scope: :user
    visit promotion_path(promotion)
    click_on 'Gerar e-mail marketing com IA'

    expect(current_path).to eq promotion_path(promotion)
    expect(page).to have_content 'Não foi possível conectar ao serviço de IA'
  end

  scenario 'but not for an expired promotion' do
    promotion = create(:promotion, :expired)

    login_as user, scope: :user
    visit promotion_path(promotion)

    expect(page).not_to have_button 'Gerar e-mail marketing com IA'
  end
end
