require_relative "boot"

require "rails/all"

ActiveSupport::Deprecation.behavior = :silence

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Portal
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    config.active_record.yaml_column_permitted_classes = [
      ActiveSupport::HashWithIndifferentAccess,
      ActiveSupport::TimeWithZone,
      ActiveSupport::TimeZone,
      Date,
      Symbol,
      Time
    ]
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

    config.mapping_fields = {

      "objmusno_s" => "Museum Number",
      "objname_s"=>"Object Name",
      "objfcp_s"=>"Collection Place",
      "objculturetree_ss"=>"Culture Hierarchy",
      "objfcpgeoloc_p"=>"Lat/Long"
    }
  

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
