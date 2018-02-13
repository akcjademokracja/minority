Minority::Engine.routes.draw do
  get 'bank_account_import', to: 'bank_account_controller#index'
  post 'bank_account_import', to: 'bank_account_controller#process'

  get 'aorta_manual_proc', to: 'aorta_manual_proc#index'
  post 'aorta_manual_proc', to: 'aorta_manual_proc#process'

end
