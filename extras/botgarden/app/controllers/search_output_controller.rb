class SearchOutputController < ApplicationController
	include ActionView::Helpers::TagHelper
	include ActionView::Context
	include ApplicationHelper
	include ActionController::MimeResponds

	def csv_output_fields_form
		# puts params[:solr_params]
		# search_data = generate_search_results_data(solr_query)
		respond_to do |format|
		    format.html
			format.json
		    format.js
		end
	end

	# def has_values fields_to_query
	# 	has_values = fields_to_query.select(&:presence)
	# 	if has_values.blank?
	# 		return false    
	# 	end
	# end


	def download_csv
		fields_to_query = []
		params.except(:authenticity_token,:commit,:controller,:solr_params,:action,:authenticity_token).each do |field,value|
			# puts field, value
			if value.to_s == "1"
				fields_to_query << field
			end
		end
		puts "hello "*100
		# puts JSON.parse(params[:solr_params])

		send_file(view_context.requery_solr(
			JSON.parse(params[:solr_params]),
			"#{fields_to_query}")
		)
		
	end

end
