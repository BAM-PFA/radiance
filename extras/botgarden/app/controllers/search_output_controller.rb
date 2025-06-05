class SearchOutputController < ApplicationController
	include ActionView::Helpers::TagHelper
	include ActionView::Context
	include ApplicationHelper
	include ActionController::MimeResponds

	# hash of solr_label => display label values for CSV export
	config.csv_output_fields = {
	  "objcsid_s" => "Object CSID",
	  "canonicalNameComplete_s" => "Canonical Name",
	  "gardenlocation_s" => "Garden Location",
	  "accessionnumber_s" => "Accession Number",
	  "deaddate_s" => "Dead Date",
	  "family_s" => "Taxonomic Family",
	  "genusOrAbove_s" => "Genus Or Above",
	  "locality_s" => "Collecting Locality",
	  "provenancetype_s" => "Provenance Type",
	  "accessrestrictions_s" => "Access Restrictions",
	  "accessionnotes_s" => "Accession Notes",
	  "source_s" => "Source",
	  "hybridflag_s" => "Hybrid?",
	  "rare_s" => "Rare?",
	  "vouchers_s" => "Has Vouchers?",
	  "blob_ss" => "Has Images?"
	  }

	def csv_output_fields_form
		respond_to do |format|
		    format.html
			# format.json
		    # format.js
		end
	end

	def summary_fields_form
		respond_to do |format|
		    format.html
			# format.json
		    # format.js
		end
	end

	def download_csv
		fields_to_query = []
		params.except(:authenticity_token,:commit,:controller,:solr_params,:action,:summary_field).each do |field,value|
			if value.to_s == "1"
				fields_to_query << field
			end
		end
		puts params

		send_file(view_context.requery_solr(
			JSON.parse(params[:solr_params]),
			"#{fields_to_query}")
		)
		
	end

	def make_summary
		fields_to_query = []
		params.except(:authenticity_token,:commit,:controller,:solr_params,:action,:summary_field).each do |field,value|
			if value.to_s == "1"
				fields_to_query << field
			end
		end
		summary_field, fields_to_export, summary_database_path = view_context.requery_solr_summarize(
			JSON.parse(params[:solr_params]),
			"#{fields_to_query}",
			summary_field=params["summary_field"]
			)
		# params[:results] = results
		params[:summary_field] = summary_field
		params[:fields_to_export] = fields_to_export
		params[:summary_database_path] = summary_database_path
		# puts params
		respond_to do |format|
		    format.html
			# format.json
		    # format.js
		end
		
	end

	def download_summary
		send_file(
			make_stats(
				params[:summary_field],
				params[:fields_to_export],
				params[:summary_database_path],
				download=true
				)
		)
	end

end
