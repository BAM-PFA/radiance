class SearchOutputController < ApplicationController
	include ActionView::Helpers::TagHelper
	include ActionView::Context
	include ApplicationHelper
	include ActionController::MimeResponds

	# hash of solr_label => display label values for CSV export
	config.csv_output_fields = {
		"objsortnum_s"=>"Sortable Museum Number",
		"objmusno_s"=>"Museum Number",
		"objdept_s"=>"Department",
		"objtype_s"=>"Object Type",
		"objcount_s"=>"Object Count",
		"objcountnote_s"=>"Count Note",
		"objkeelingser_s"=>"Keeling Series Number",
		"objfcpverbatim_s"=>"Collection Place (verbatim)",
		"objname_s"=>"Object Name",
		"objaltnum_ss"=>"Alternate Number",
		"objfilecode_ss"=>"Function",
		"objdescr_s"=>"Description",
		"objcontextuse_s"=>"Context of Use",
		"objdimensions_ss"=>"Dimensions",
		"objmaterials_ss"=>"Materials",
		"objinscrtext_ss"=>"Inscription",
		"objcomment_s"=>"Comment",
		"objtitle_s"=>"Title",
		"objcolldate_s"=>"Collection Date",
		"objproddate_s"=>"Production Date",
		"objcollector_ss"=>"Collector",
		"objaccno_ss"=>"Accession Number",
		"objaccdate_ss"=>"Accession Date",
		"objacqdate_ss"=>"Acquisition Date",
		"anonymousdonor_ss"=>"Donor",
		"objassoccult_ss"=>"Culture or Time period",
		"objfcp_s"=>"Collection Place",
		"objfcpgeoloc_p"=>"Approximate LatLong",
		"objpp_ss"=>"Production Place",
		"csid_s"=>"Object CSID",
		"objmaker_ss"=>"Maker / Artist",
		"objculturedepicted_ss"=>"Culture Depicted",
		"objplacedepicted_ss"=>"Place Depicted",
		"objpersondepicted_ss"=>"Person Depicted",
		"objobjectclass_ss"=>"Object Class",
		"objobjectclasstree_ss"=>"Object Class Hierarchy",
		"objfcptree_ss"=>"Place Hierarchy",
		"objculturetree_ss"=>"Culture Hierarchy",
		"taxon_ss"=>"Taxon",
		"deaccessioned_s"=>"Deaccession Flag"
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
