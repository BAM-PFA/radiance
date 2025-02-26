module ApplicationHelper

  def get_random_documents(query: '*', limit: 12)
    params = {
      :q => query,
      :rows => limit,
      :sort => 'random'
    }
    builder = Blacklight::SearchService.new(config: blacklight_config, user_params: params)
    response = builder.search_results
    docs = response[0][:response][:docs].collect { |x| x.slice(:objcsid_s,:canonicalNameComplete_s,:commonname_s,:locality_s, :blob_ss)}
    return docs
  end

  def generate_image_gallery
    docs = get_random_documents(query: 'blob_ss:[* TO *]')
    puts docs
    return format_image_gallery_results(docs)
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
    puts document
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

  def render_media options = {}
    # return a list of cards or images
    content_tag(:div) do
      options[:value].collect do |blob_csid|
        content_tag(:a, content_tag(:img, '',
          src: render_csid(blob_csid, 'Medium'),
          class: 'thumbclass'),
          href: "https://webapps.cspace.berkeley.edu/botgarden/imageserver/blobs/#{blob_csid}/derivatives/OriginalJpeg/content",
          # href: "https://webapps.cspace.berkeley.edu/botgarden/imageserver/blobs/#{blob_csid}/content",
          target: 'original',
          style: 'padding: 3px;',
          class: 'hrefclass')
      end.join.html_safe
    end
  end

  def render_linkless_media options = {}
    # return a list of cards or images
    content_tag(:div) do
      options[:value].collect do |blob_csid|
        content_tag(:a, content_tag(:img, '',
            src: render_csid(blob_csid, 'Medium'),
            class: 'thumbclass'),
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
                class: 'thumbclass')
          end.join.html_safe
        else content_tag(:img, '',
                src: '../kuchar.jpg',
                class: 'thumbclass',
                alt: 'log in to view images')
        end
    end
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
