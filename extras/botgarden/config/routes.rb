Rails.application.routes.draw do

  get 'errors/not_found'
  get 'errors/internal_server_error'
  match "/404", :to => "errors#not_found", :via => :all
  match "/500", :to => "errors#internal_server_error", :via => :all
  concern :range_searchable, BlacklightRangeLimit::Routes::RangeSearchable.new
  mount Blacklight::Engine => '/'
  mount BlacklightAdvancedSearch::Engine => '/'

  root to: "catalog#index"
  concern :searchable, Blacklight::Routes::Searchable.new

  resource :catalog, only: [:index], as: 'catalog', path: '/catalog', controller: 'catalog' do
    concerns :searchable
    concerns :range_searchable

  end
  devise_for :users
  concern :exportable, Blacklight::Routes::Exportable.new

  resources :solr_documents, only: [:show], path: '/catalog', controller: 'catalog' do
    concerns :exportable
  end

  get '/*ark_tag/:naan/:ark' => 'catalog#decode_ark', constraints: { ark_tag:'ark:' }
  get '/add_gallery_items' => "gallery#add_gallery_items"


  get "/csv_output_fields_form", to: "search_output#csv_output_fields_form", as: "csv_output_fields_form"
  get "/summary_fields_form", to: "search_output#summary_fields_form", as: "summary_fields_form"
  post "/download_csv", to: "search_output#download_csv"
  post "/make_summary", to: "search_output#make_summary"
  get "/download_summary", to: "search_output#download_summary"



  resources :bookmarks do
    concerns :exportable

    collection do
      delete 'clear'
    end
  end
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
