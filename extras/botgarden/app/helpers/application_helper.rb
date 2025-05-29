module ApplicationHelper

  def bookmark_control_label document, counter, total
    label = "#{document['canonicalNameComplete_s']}, accession number #{document['accessionnumber_s']}"
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

  def format_requery_params(blacklight_q_params)
    # puts "hello "*100
    # puts blacklight_q_params
    solr_params = {}
    if blacklight_q_params.key?("search_field")
      if blacklight_q_params["search_field"] == "advanced"
        blacklight_q_params.except("f","search_field").each do |k,v|
          solr_params.merge!({k => v})
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


        # if blacklight_q_params['f']["Has image"][0] == "no_image"
        # end



        # solr_params.merge!({"blob_ss" => "[* TO *]"})
        # blacklight_q_params['f'] = blacklight_q_params['f'].delete("Has Image")
      end
      puts solr_params
      blacklight_q_params['f']&.each do |k,v|
        if v.kind_of?(Array)
          v = v.join(separator = " ")
        end
        solr_params.merge!({k => v})
      end
      solr_params.delete('f')
    end
    solr_params&.delete("advanced")
    puts solr_params


    endpoint_params = ""
    solr_params.each do |k,v|
      endpoint_params+="#{k} : #{v} "
    end
    url_string = "https://webapps.cspace.berkeley.edu/solr/botgarden-public/select?defType=edismax&df=text&q.op=AND&q=#{endpoint_params}"
    url_string = url_string.gsub("'","%22").gsub(" ","%20")
    puts url_string
    
    return url_string, solr_params
  end

  def get_paginated_solr_results requery_url, solr_params, fields_to_export
    # TODO this method is too sprawling, refactor
    require 'uri'
    require 'net/http'
    require 'json'
    require 'thread'
    require 'securerandom'
    require 'csv'

    # define the number of results per page returned by solr
    # this is a guess at a reasonable number without overloading the server? 
    # it could be too low though, esp for large result sets
    first_row = JSON.parse(fields_to_export).map { |value| "" }
    first_row = first_row.unshift(solr_params)
    headers = []

    # headers = JSON.parse(fields_to_export)
    headers = headers.unshift("Query parameters")
    JSON.parse(fields_to_export).each do |f|
      headers << config.csv_output_fields[f]
    end
    results_per_page = 500
    requery_url_string = "#{requery_url}&rows=#{results_per_page}"
    response = get_single_solr_page(requery_url_string,0)
    
    total_items = response['response']['numFound'].to_i
    number_of_full_pages, last_page_num_items = total_items.divmod(results_per_page)
    starting_row = 0
    last_page = number_of_full_pages + 1
    last_page_start_row = (number_of_full_pages*results_per_page)
    last_row = total_items - 1

    uuid = SecureRandom.uuid[0..7]
    filepath = "public/query_results_#{uuid}.csv"

    page_queue = Queue.new
    (0..last_page_start_row).step(results_per_page) do |start_row|
      page_queue << start_row
    end

   
    CSV.open(filepath, "a") do |csv|
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
                JSON.parse(fields_to_export).each do |field|
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

    return filepath
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

  def get_random_documents(query: '*', limit: 12, sort: 'random')
    params = {
      :q => query,
      :rows => limit,
      :sort => sort
    }
    builder = Blacklight::SearchService.new(config: blacklight_config, user_params: params)
    response = builder.search_results
    response[0][:response][:docs].collect { |x| x.slice(:objcsid_s,:canonicalNameComplete_s,:commonname_s,:locality_s, :blob_ss, :gardenlocation_s)}
  end

  def generate_image_gallery
    documents = get_random_documents(query: 'blob_ss:[* TO *]')
    return format_image_gallery_results(documents)
  end

  def generate_garden_bed_preview(garden_bed)
    query = "#{garden_bed}"
    docs = get_random_documents(query: query, limit: 4)
    docs.collect do |doc|
      content_tag(:a, href: "/catalog/#{doc[:objcsid_s]}") do
        content_tag(:div, class: 'show-preview-item') do
          unless doc[:canonicalNameComplete_s].nil?
          canonical_name = doc[:canonicalNameComplete_s]
        else
          canonical_name = "[No name given]"
        end
        unless doc[:commonname_s].nil?
          commonname = doc[:commonname_s]
          commonname_tag = content_tag(:div, class: "gallery-caption-artist") do
            "Common Name: ".html_safe +
            content_tag(:span, commonname)
          end
        else
          commonname_tag = content_tag(:span, "[No common name given]", class: "gallery-caption-artist")
        end
        unless doc[:locality_s].nil?
          country = doc[:locality_s]
        else
          country = "[No collection country given]"
        end
        unless doc[:blob_ss].nil?
          image_tag = content_tag(:img, '',
            src: render_csid(doc[:blob_ss][0], 'Medium'),
            class: 'thumbclass')
        else
          image_tag = content_tag(:span,'Image not available',class: 'no-preview-image')
        end
        unless doc[:blob_ss].nil?
          image_tag = content_tag(:img, '',
            alt: render_alt_text(doc),
            src: render_csid(doc[:blob_ss][0], 'Medium'),
            class: 'thumbclass')
        else
          image_tag = content_tag(:span,'Image not available',class: 'no-preview-image')
        end
        image_tag + 
        content_tag(:div) do
          content_tag(:span, canonical_name, class: "gallery-caption-title") +
          content_tag(:span, "("+country+")", class: "gallery-caption-date") +
          commonname_tag
        end
        end
      end
    end.join.html_safe
  end

  def generate_artist_preview(artist)#,limit=4)
    # artist should already include parsed artist names
    # this should return format_artist_preview()
    searchable = extract_artist_names(artist)
    searchable = searchable.split(" OR ")
    random_string = SecureRandom.uuid
    query = ""
    searchable.each do |x|
      query = query + "#{x}"
    end

    docs = get_random_documents(query: query, limit: 4)
    docs.collect do |doc|
      content_tag(:a, href: "/catalog/#{doc[:objcsid_s]}") do
        content_tag(:div, class: 'show-preview-item') do
          unless doc[:title_txt].nil?
            title = doc[:title_txt][0]
          else
            title = "[No title given]"
          end
          unless doc[:artistcalc_txt].nil?
            artist = doc[:artistcalc_txt][0]
          else
            artist = "[No artist given]"
          end
          artist_tag = content_tag(:span, artist, class: "gallery-caption-artist")
          unless doc[:datemade_s].nil?
            datemade = doc[:datemade_s]
          else
            datemade = "[No date given]"
          end
          unless doc[:blob_ss].nil?
            image_tag = content_tag(:img, '',
              src: render_csid(doc[:blob_ss][0], 'Medium'),
              class: 'thumbclass')
          else
            image_tag = content_tag(:span,'Image not available',class: 'no-preview-image')
          end
          image_tag +
          content_tag(:h4) do
            artist_tag +
            content_tag(:span, title, class: "gallery-caption-title") +
            content_tag(:span, "("+datemade+")", class: "gallery-caption-date")
          end
        end
      end
    end.join.html_safe
  end

  def extract_artist_names(artist)
    searchable = artist.tr(",","") # first remove commas
    matches = searchable.scan(/[^;]+(?=;?)/) # find the names in between optional semi-colons
    if matches.length != 0
      matches = matches.each{|m| m.lstrip!}
      matches.map!{|m| m.tr(" ","+").insert(0,'"').insert(-1,'"')} # add quotes for the OR search
      searchable = matches.join(" OR ")
    end
    return searchable
  end

  def make_artist_search_link(artist)
    searchable = extract_artist_names(artist)
    return "/catalog/?&op=OR&search_field=artistcalc_s&q=#{searchable}"
  end

  def format_image_gallery_results(docs)
    # puts docs
    docs.collect do |doc|
      content_tag(:div, class: 'gallery-item') do
        # puts doc.keys
        # puts "x "*100
        unless doc[:canonicalNameComplete_s].nil?
          canonical_name = doc[:canonicalNameComplete_s]
        else
          canonical_name = "[No name given]"
        end
        unless doc[:commonname_s].nil?
          commonname = doc[:commonname_s]
          # artist_link = make_artist_search_link(artist)
          commonname_tag = content_tag(:div, class: "gallery-caption-artist") do
            "Common Name: ".html_safe +
            content_tag(:span, commonname)
          end
        else
          commonname_tag = content_tag(:span, "[No common name given]", class: "gallery-caption-artist")
        end
        unless doc[:locality_s].nil?
          country = doc[:locality_s]
        else
          country = "[No collection country given]"
        end
        content_tag(:a, content_tag(:img, '',
          alt: render_alt_text(doc),
          src: render_csid(doc[:blob_ss][0], 'Medium'),
          class: 'thumbclass'),
          href: "/catalog/#{doc[:objcsid_s]}") +
        content_tag(:h4) do
          content_tag(:span, canonical_name, class: "gallery-caption-title") +
          content_tag(:span, "("+country+")", class: "gallery-caption-date") +
          commonname_tag
        end
      end
    end.join.html_safe
  end

  def render_map options = {}
    document = options.to_json
    # puts document
    render partial: "/map/map", locals: { latitude: options[:document][:latitude_f], longitude: options[:document][:longitude_f] }
  end

  def render_csid csid, derivative
    "https://webapps.cspace.berkeley.edu/botgarden/imageserver/blobs/#{csid}/derivatives/#{derivative}/content"
  end

  def render_status options = {}
    options[:value].collect do |status|
      content_tag(:span, status, style: 'color: red;')
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

  def render_alt_text document
    canonical_name = unless document[:canonicalNameComplete_s].nil? then " #{document[:canonicalNameComplete_s]}" else ' unnamed plant' end
    common_name = unless document[:commonname_s].nil? then " , with the common name #{document[:commonname_s]}," else '' end
    object_number = unless document[:accessionnumber_s].nil? then " , accession number #{document[:accessionnumber_s]}" else ' , no accession number available' end
    "Image of UC Botanical Garden accession, #{canonical_name}#{common_name}#{object_number}.".html_safe
  end



  def determine_month_color(month,field)
    if field.downcase.include? "fruit"
      action = "fruiting"
    elsif field.downcase.include? "flower"
      action = "flowering"
    end
    if ['x','no','f'].include? month.to_s.downcase
      cell_class = 'table-secondary'
      text = "not #{action}"
    elsif month.downcase == "some"
      cell_class = "table-warning"
      text = "some #{action}"
    elsif month.downcase == "many"
      cell_class = "table-danger"
      text = "many #{action}"
    elsif month.downcase == "t"
      cell_class = "table-danger"
      text = "#{action}" 
    end
    return [cell_class,text]
  end

  def find_no_data(options)
    skip = false
    if options[:value].all? {|action| ['x','no','f'].include? action.to_s.downcase }
      skip = true
    end
    return skip
  end

  def render_flower_n_fruit_calendar options = {}
    skip_render = find_no_data(options)
    if skip_render == true
      return "No data"
    end
    columns = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']
    
    thead = content_tag :thead do
      content_tag(:tr) do
        columns.collect {|column| content_tag(:th,column)}.join().html_safe
      end
    end

    tbody = content_tag(:tbody) do
      content_tag(:tr) do
        options[:value].collect { |month|
          # puts month
          status = determine_month_color(month,options[:field])
          content_tag(:td, status[1],class: status[0])
        }.join().html_safe
      end
    end
   
    # content_tag(:div, class: "table-responsive", st) do
      content_tag(:table, thead.concat(tbody).html_safe, class: "table-bordered")
    # end
  end

  # use imageserver and blob csid to serve audio
  def render_audio_csid options = {}
    # render audio player
    content_tag(:div) do
      options[:value].collect do |audio_csid|
        content_tag(:audio,
          content_tag(:source, "I'm sorry; your browser doesn't support HTML5 audio in MPEG format.",
            src: "https://webapps.cspace.berkeley.edu/botgarden/imageserver/blobs/#{audio_csid}/content",
            id: 'audio_csid',
            type: 'audio/mpeg'),
          controls: 'controls',
          style: 'height: 60px; width: 640px;')
      end.join.html_safe
    end
  end

  # use imageserver and blob csid to serve video
  def render_video_csid options = {}
    # render video player
    content_tag(:div) do
      options[:value].collect do |video_csid|
        content_tag(:video,
          content_tag(:source, "I'm sorry; your browser doesn't support HTML5 video in MP4 with H.264.",
            src: "https://webapps.cspace.berkeley.edu/botgarden/imageserver/blobs/#{video_csid}/content",
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
            src: "https://cspace-prod-02.ist.berkeley.edu/botgarden_nuxeo/data/#{l1}/#{l2}/#{audio_md5}",
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
            src: "https://cspace-prod-02.ist.berkeley.edu/botgarden_nuxeo/data/#{l1}/#{l2}/#{video_md5}",
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
            url: "https://webapps.cspace.berkeley.edu/botgarden/imageserver/blobs/#{x3d_csid}/content",
            id: 'x3d',
            type: 'model/x3d+xml')),
        style: 'margin-bottom: 6px; height: 660px; width: 660px;')
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
            url: "https://cspace-prod-02.ist.berkeley.edu/botgarden_nuxeo/data/#{l1}/#{l2}/#{x3d_md5}",
            class: 'x3d',
            type: 'model/x3d+xml')),
          style: 'margin-bottom: 6px; height: 660px; width: 660px;')
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
