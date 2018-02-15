Minority::Engine.routes.draw do
  get 'legacy_donation_import', to: 'legacy_donation_import#index'
  get 'legacy_donation_import/generate_template', to: 'legacy_donation_import#generate_template'
  post 'legacy_donation_import', to: 'legacy_donation_import#import'

  get 'aorta_manual_proc', to: 'aorta_manual_proc#index'
  post 'aorta_manual_proc', to: 'aorta_manual_proc#queue_tickets'

end
