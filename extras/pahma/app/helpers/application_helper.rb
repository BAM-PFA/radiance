module ApplicationHelper

  def bookmark_control_label document, counter, total
    label = "#{document['objname_s']}, museum number #{document['objmusno_s']}"
    if counter && counter.to_i > 0
      label += ". Search result #{counter}"
      if total && total.to_i > 0
        label += " of #{total}"
      end
    end
    label.html_safe
  end

  def requery_solr(params,fields_to_export)
    requery_url, solr_params = format_requery_params(params)
    filepath = get_paginated_solr_results(requery_url,solr_params,fields_to_export)
  end

  def requery_solr_summarize(params,fields_to_export,summary_field)
    requery_url, solr_params = format_requery_params(params)
    summary_field, fields_to_export, summary_database_path = get_paginated_solr_results(requery_url,solr_params,fields_to_export,summary_field=summary_field)
    return summary_field, fields_to_export, summary_database_path
  end

  def format_requery_params(blacklight_q_params)
    # puts "hello "*100
    # puts blacklight_q_params
    solr_params = {}
    if blacklight_q_params.key?("search_field")
      if blacklight_q_params["search_field"] == "advanced"
        blacklight_q_params.except("f","search_field").each do |k,v|
          solr_params.merge!({k => "'#{v}'"})
          solr_params&.delete("advanced")
        end
      end
      # puts blacklight_q_params["search_field"], blacklight_q_params["q"] 
      # if blacklight_q_params["search_field"].kind_of? Hash || blacklight_q_params["search_field"] == "text"
      solr_params[blacklight_q_params["search_field"]] = blacklight_q_params["q"]
      solr_params.delete("search_field")
      solr_params.delete("q")
      # end
    end

    if blacklight_q_params.key?("range")
      blacklight_q_params['range'].each do |k,v|
        value="[#{v['begin']} TO #{v['end']}]"
        solr_params.merge!({k => value})
      end
    end

    if blacklight_q_params.key?("f")
      puts blacklight_q_params['f']
      if blacklight_q_params['f'].key?("Has image")
        
        if blacklight_q_params['f']["Has image"][0] == "has_image"
          solr_params.merge!({"blob_ss" => "[* TO *]"})
        elsif blacklight_q_params['f']["Has image"][0] == "no_image"
          solr_params.merge!({"-(blob_ss" => "[* TO *])"})
        end
        blacklight_q_params['f'] = blacklight_q_params['f'].delete("Has Image")

      end
      puts solr_params
      blacklight_q_params['f']&.each do |k,v|
        if v.kind_of?(Array)
          v = v.join(separator = " ")
        end
        solr_params.merge!({k => "'#{v}'"})
      end
      solr_params.delete('f')
    end
    solr_params&.delete("advanced")
    puts solr_params


    endpoint_params = ""
    solr_params.each do |k,v|
      endpoint_params+="#{k} : #{v} "
    end
    url_string = "https://webapps.cspace.berkeley.edu/solr/pahma-public/select?defType=edismax&df=text&q.op=AND&q=#{endpoint_params}"
    url_string = url_string.gsub("'","%22").gsub(" ","%20")
    puts url_string
    
    return url_string, solr_params
  end

  def get_paginated_solr_results requery_url, solr_params, fields_to_export, summary_field=nil
    # TODO this method is crazy sprawling, refactor & DRY
    require 'uri'
    require 'net/http'
    require 'json'
    require 'thread'
    require 'securerandom'
    require 'csv'


    fields_to_export = JSON.parse(fields_to_export)
    first_row = fields_to_export.map { |value| "" }
    first_row = first_row.unshift(solr_params)
    headers = []

    # headers = fields_to_export
    headers = headers.unshift("Query parameters")
    fields_to_export.each do |f|
      headers << config.csv_output_fields[f]
    end

    # define the number of results per page returned by solr
    # this is a guess at a reasonable number without overloading the server? 
    # it could be too low though, esp for large result sets
    results_per_page = 10000
    requery_url_string = "#{requery_url}&rows=#{results_per_page}"
    puts requery_url_string
    response = get_single_solr_page(requery_url_string,0)
    
    total_items = response['response']['numFound'].to_i
    number_of_full_pages, last_page_num_items = total_items.divmod(results_per_page)
    starting_row = 0
    last_page = number_of_full_pages + 1
    last_page_start_row = (number_of_full_pages*results_per_page)
    last_row = total_items - 1

    uuid = SecureRandom.uuid[0..7]

    page_queue = Queue.new
    (0..last_page_start_row).step(results_per_page) do |start_row|
      page_queue << start_row
    end

    if summary_field != nil
      summary_database, summary_database_path = create_summary_db(fields_to_export,summary_field,uuid)
      # puts fields_to_export.insert(0,"count")
      columns = "#{summary_field}_summary, #{fields_to_export.insert(0,"count").join(", ")}"
      # puts columns
      # number of columns doesn't include the "count" column
      number_of_columns = fields_to_export.length()
      parameterized_values = "?"
      number_of_columns.times { parameterized_values += ", ?" }
      
      workers = last_page.times.map do
        Thread.new do
          until page_queue.empty?
            start_row = page_queue.pop(true) rescue nil
            if start_row
              response = get_single_solr_page(requery_url_string,start_row)
              response['response']['docs']&.each do |row|
                if row[summary_field].nil?
                    row[summary_field] = ""
                  end
                if row[summary_field].is_a?(Array)
                  values = [row[summary_field].join(separator = " > ")]
                else
                  values = [row[summary_field]]
                end
                # puts values.to_s
                fields_to_export.each do |column|
                  # puts column
                  # puts row[column].class
                  # puts row[column].to_s


                  if row[column].is_a?(Array)
                    # puts row[column].join(separator = " > ")
                    values << row[column].join(separator = " | ")
                  else
                    values << row[column]
                  end
                end
                puts values.to_s

                insert_string = "INSERT INTO summary (#{columns}) VALUES (#{parameterized_values});"
                puts insert_string
                summary_database.execute insert_string, values

              end
            end
          end
        end
      end
      workers.each(&:join)

      return summary_field, fields_to_export, summary_database_path

    end

   
    uuid = SecureRandom.uuid[0..7]
    results_filepath = "public/query_results_#{uuid}.csv"

    CSV.open(results_filepath, "a") do |csv|
      csv << headers
      csv << first_row

      workers = last_page.times.map do
        Thread.new do
          until page_queue.empty?
            start_row = page_queue.pop(true) rescue nil
            if start_row
              response = get_single_solr_page(requery_url_string,start_row)
              response['response']['docs'].each do |row|
                # account for the column for search params
                row_to_enter = [""]
                fields_to_export.each do |field|
                  row_to_enter << row[field]
                end
                csv << row_to_enter
              end
            end
          end
        end
      end
      workers.each(&:join)
    end

    return results_filepath
  end

  def make_stats summary_field,fields_to_export,summary_database_path, download=false
    require 'securerandom'
    require 'time'

    summary_database = SQLite3::Database.open(summary_database_path)
    uuid = SecureRandom.uuid[0..7]
    stats_csv_filepath = "public/stats_#{Time.current.localtime.strftime("%Y-%m-%d_%H-%M-%S")}.csv"
    if download == false
      limit = "LIMIT 500"
    elsif download == true
      limit = ""
    end
    
    count_string = "SELECT #{summary_field}_summary AS 'Summarizing on #{config.csv_output_fields[summary_field]}', COUNT(#{summary_field}_summary) AS 'Count'"
    fields_to_export.delete('count')
    # puts fields_to_export
    fields_to_export.each {|column| count_string += ", GROUP_CONCAT(DISTINCT #{column}) AS '#{config.csv_output_fields[column]}'" }
    count_string += " FROM summary GROUP BY #{summary_field}_summary ORDER BY Count DESC #{limit};"
    # puts count_string
    results = summary_database.query(count_string)
    # puts results[-1].to_s
    # puts results.columns
    # results.unshift(summary_database)

    if download == false


      thead = content_tag :thead do
        content_tag :tr do
          results.columns.collect {|column| 
            concat content_tag(:th,column)
          }.join().html_safe
        end
      end

      tbody = content_tag :tbody do
        results.collect { |row|

          content_tag :tr do
            row.collect { |value|
                concat content_tag(:td, value.to_s.gsub(/([a-zA-Z0-9\.\']+?)(,)([a-zA-Z0-9]+?)/, '\1<br/>\3').html_safe, html: {class: "m-2"})
            }.to_s.html_safe
          end

        }.join().html_safe
      end

      table = content_tag(:table, class:"table table-responsive table-bordered") do 
        thead.concat(tbody)
      end

    elsif download == true
      headers = []
      fields_to_export.each do |column|
        headers << config.csv_output_fields[column]
      end

      headers[0] = "Summarizing on #{config.csv_output_fields[summary_field]}"

      CSV.open(stats_csv_filepath, "a") do |csv|
        csv << headers
        # csv << first_row
        results.each do |row|
          csv << row
        end
      end
      return stats_csv_filepath
    end

  end

  def total_stats_item_count summary_database_path
    summary_database = SQLite3::Database.open(summary_database_path)
    total_count = summary_database.query("SELECT COUNT(*) from summary").next()[0]

  end

  def create_summary_db fields_to_export,summary_field,uuid
    require 'sqlite3'
    require 'fileutils'
    db_path = "public/summary_#{uuid}.db"
    FileUtils.touch(db_path)
    db = SQLite3::Database.open(db_path)
    fields_columns = ""
    fields_to_export&.each do |field|
      fields_columns += ", #{field} TEXT"
    end

    sql_create_statement = "CREATE TABLE summary(#{summary_field}_summary TEXT DEFAULT '', count INTEGER DEFAULT 0#{fields_columns})"
    puts sql_create_statement
    db.execute sql_create_statement

    return db,db_path

  end

  def get_single_solr_page requery_url_string,start_row
    requery_url_string = "#{requery_url_string}&start=#{start_row}"
    requery_url = URI(requery_url_string)
    res = Net::HTTP.get_response(requery_url)
    if res.is_a?(Net::HTTPSuccess) 
      response = JSON.parse(res.body)
      return response
    else
      return ""
    end
  end

  def render_csid csid, derivative
    "https://webapps.cspace.berkeley.edu/pahma/imageserver/blobs/#{csid}/derivatives/#{derivative}/content"
  end

  def render_status options = {}
    options[:value].collect do |status|
      content_tag(:span, status, class: 'text-danger')
    end.join(', ').html_safe
  end

  def render_multiline options = {}
    # render an array of values as a list
    content_tag(:div) do
      content_tag(:ul) do
        options[:value].collect do |array_element|
          content_tag(:li, array_element)
        end.join.html_safe
      end
    end
  end

  def render_film_links options = {}
    # return a <ul> of films with links to the films themselves
    content_tag(:div) do
      content_tag(:ul) do
        options[:value].collect do |array_element|
          parts = array_element.split(/^(.*?)\+\+(.*?)\+\+(.*)/)
          content_tag(:li, (link_to parts[2], '/catalog/' + parts[1]) + parts[3])
        end.join.html_safe
      end
    end
  end

  def render_doc_link options = {}
    # return a link to a search for documents for a film
    content_tag(:div) do
      options[:value].collect do |film_id|
        content_tag(:a, 'Click for documents related to this film',
          href: "/?q=#{film_id}&search_field=film_id_ss",
          style: 'padding: 3px;',
          class: 'hrefclass')
      end.join.html_safe
    end
  end

  def render_warc options = {}
    doc_type = options[:document][:doctype_s]
    warc_url = options[:document][:docurl_s]
    canonical_url = options[:document][:canonical_url_s]
    unless warc_url.nil?
      if doc_type == 'web archive'
        render partial: '/shared/warcs', locals: { warc_url: warc_url, canonical_url: canonical_url }
      end
    end
  end

  def check_and_render_pdf options = {}
    # access_code is set by by complicated SQL expression and results in an integer code_s in solr
    access_code = options[:document][:code_s]
    # access_code==4 => "World", everything else is restricted
    if access_code == '4'
      restricted = false
    else
      restricted = true
    end
    render_pdf options[:value].first, restricted
  end

  def render_pdf pdf_csid, restricted
    # render a pdf using html5 pdf viewer
    render partial: '/shared/pdfs', locals: { csid: pdf_csid, restricted: restricted }
  end

  def render_alt_text(blob_csid, options)
    document = options[:document]
    unless options[:field] == 'card_ss'
      prefix = 'Hearst Museum object'
      total_pages = document[:blob_ss] ? document[:blob_ss].length : 1
      if total_pages > 1
        page_number = document[:blob_ss].find_index(blob_csid)
        if page_number.is_a? Integer
          prefix += " #{page_number + 1} of #{total_pages}"
        end
      end
    else
      prefix = 'Documentation associated with Hearst Museum object'
    end
    brief_description = unless document[:objdescr_txt].nil? then "described as #{document[:objdescr_txt][0]}" else 'no description available.' end
    if document[:restrictions_ss] && document[:restrictions_ss].include?('notpublic') && !document[:restrictions_ss].include?('public')
      brief_description += ' Notice: Image restricted due to its potentially sensitive nature. Contact Museum to request access.'
    end
    object_name = unless document[:objname_txt].nil? then "titled #{document[:objname_txt][0]}" else 'no title available' end
    object_number = unless document[:objmusno_txt].nil? then "accession number #{document[:objmusno_txt][0]}" else 'no object accession number available' end
    "#{prefix} #{object_name}, #{object_number}, #{brief_description}".html_safe
  end

  def render_media(options)
    # return a list of cards or images
    content_tag(:div) do
      options[:value].collect do |blob_csid|
        content_tag(:a,
          content_tag(:img, '',
            src: render_csid(blob_csid, 'Medium'),
            alt: render_alt_text(blob_csid, options),
            class: 'thumbclass'
          ),
          href: "https://webapps.cspace.berkeley.edu/pahma/imageserver/blobs/#{blob_csid}/derivatives/OriginalJpeg/content",
          # href: "https://webapps.cspace.berkeley.edu/pahma/imageserver/blobs/#{blob_csid}/content",
          target: 'original',
          style: 'padding: 3px;',
          class: 'hrefclass d-inline-block')
      end.join.html_safe
    end
  end

  def render_linkless_media options = {}
    # return a list of cards or images
    content_tag(:div) do
      options[:value].collect do |blob_csid|
        content_tag(:div,
          content_tag(:img, '',
            src: render_csid(blob_csid, 'Medium'),
            alt: render_alt_text(blob_csid, options),
            class: 'thumbclass'
          ),
          class: 'd-inline-block',
          style: 'padding: 3px;')
      end.join.html_safe
    end
  end

  def render_restricted_media options = {}
    # return a list of cards or images
    content_tag(:div) do
        if current_user
          options[:value].collect do |blob_csid|
            content_tag(:img, '',
                src: render_csid(blob_csid, 'Medium'),
                alt: render_alt_text(blob_csid, options),
                class: 'thumbclass')
          end.join.html_safe
        else content_tag(:img, '',
                src: '../kuchar.jpg',
                class: 'thumbclass',
                alt: 'log in to view images')
        end
    end
  end

  # use authenticating proxy and blob csid to serve audio
  # TODO: hostname will need to change if a museum besides pahma wants to use this feature
  def render_audio_csid options = {}
    # render audio player
    content_tag(:div) do
      options[:value].collect do |audio_csid|
        content_tag(:audio,
          content_tag(:source, "I'm sorry; your browser doesn't support HTML5 audio in MPEG format.",
            src: "https://portal.hearstmuseum.berkeley.edu/cspace-services/blobs/#{audio_csid}/content",
            id: 'audio_csid',
            type: 'audio/mpeg'),
          controls: 'controls',
          style: 'height: 60px; width: 640px;')
      end.join.html_safe
    end
  end

  # use authenticating proxy and blob csid to serve video
  # TODO: hostname will need to change if a museum besides pahma wants to use this feature
  def render_video_csid options = {}
    # render video player
    content_tag(:div) do
      options[:value].collect do |video_csid|
        content_tag(:video,
          content_tag(:source, "I'm sorry; your browser doesn't support HTML5 video in MP4 with H.264.",
            src: "https://portal.hearstmuseum.berkeley.edu/cspace-services/blobs/#{video_csid}/content",
            id: 'video_csid',
            type: 'video/mp4'),
          controls: 'controls',
          style: 'width: 640px;')
      end.join.html_safe
    end
  end

  # serve audio directy via apache (apache needs to be configured to serve nuxeo repo)
  def render_audio_directly options = {}
    # render audio player
    content_tag(:div) do
      options[:value].collect do |audio_md5|
        l1 = audio_md5[0..1]
        l2 = audio_md5[2..3]
        content_tag(:audio,
          content_tag(:source, "I'm sorry; your browser doesn't support HTML5 audio in MPEG format.",
            src: "https://cspace-prod-02.ist.berkeley.edu/pahma_nuxeo/data/#{l1}/#{l2}/#{audio_md5}",
            id: 'audio_md5',
            type: 'audio/mpeg'),
          controls: 'controls',
          style: 'height: 60px; width: 640px;')
      end.join.html_safe
    end
  end

  # serve audio directy via apache (apache needs to be configured to serve nuxeo repo)
  def render_video_directly options = {}
    # render video player
    content_tag(:div) do
      options[:value].collect do |video_md5|
        l1 = video_md5[0..1]
        l2 = video_md5[2..3]
        content_tag(:video,
          content_tag(:source, "I'm sorry; your browser doesn't support HTML5 video in MP4 with H.264.",
            src: "https://cspace-prod-02.ist.berkeley.edu/pahma_nuxeo/data/#{l1}/#{l2}/#{video_md5}",
            id: 'video_md5',
            type: 'video/mp4'),
          controls: 'controls',
          style: 'width: 640px;')
      end.join.html_safe
    end
  end

  def render_x3d_csid options = {}
    # render x3d object
    content_tag(:div) do
      options[:value].collect do |x3d_csid|
        content_tag(:x3d,
          content_tag(:scene,
            content_tag(:inline, '',
            url: "https://webapps.cspace.berkeley.edu/pahma/imageserver/blobs/#{x3d_csid}/content",
            id: 'x3d',
            type: 'model/x3d+xml')),
          aria: {label: render_alt_text(x3d_csid, options)},
          role: 'img',
          class: 'x3d-object')
      end.join.html_safe
    end
  end

  # serve X3D directy via apache (apache needs to be configured to serve nuxeo repo)
  def render_x3d_directly options = {}
    # render x3d player
    content_tag(:div) do
      options[:value].collect do |x3d_md5|
        l1 = x3d_md5[0..1]
        l2 = x3d_md5[2..3]
        content_tag(:x3d,
          content_tag(:scene,
            content_tag(:inline, '',
            url: "https://cspace-prod-02.ist.berkeley.edu/pahma_nuxeo/data/#{l1}/#{l2}/#{x3d_md5}",
            class: 'x3d',
            type: 'model/x3d+xml')),
          aria: {label: render_alt_text(x3d_md5, options)},
          role: 'img',
          class: 'x3d-object')
      end.join.html_safe
    end
  end

  # compute ark from museum number and render as a link
  def render_ark options = {}
    # encode museum number as ARK ID, e.g. 11-4461.1 -> hm21114461@2E1, K-3711a-f -> hm210K3711a@2Df
    options[:value].collect do |musno|
      ark = 'hm2' + if musno.include? '-'
        left, right = musno.split('-', 2)
        left = '1' + left.rjust(2, '0')
        right = right.rjust(7, '0')
        CGI.escape(left + right).gsub('%', '@').gsub('.', '@2E').gsub('-', '@2D').downcase
      else
        'x' + CGI.escape(musno).gsub('%', '@').gsub('.', '@2E').downcase
      end

      link_to "ark:/21549/" + ark, "https://n2t.net/ark:/21549/" + ark
    end.join.html_safe
  end

end
