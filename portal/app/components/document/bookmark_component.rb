# frozen_string_literal: true

module Document
  # Render a bookmark widget to bookmark / unbookmark a document
  class BookmarkComponent < Blacklight::Component
    # @param [Blacklight::Document] document
    # @param [Boolean] checked
    # @param [Object] bookmark_path the rails route to use for bookmarks
    def initialize(document:, counter: nil, total: nil, checked: nil, bookmark_path: nil)
      @document = document
      @checked = checked
      @bookmark_path = bookmark_path
      @counter = counter
      @total = total
    end

    def bookmarked?
      return @checked unless @checked.nil?

      helpers.bookmarked? @document
    end

    def bookmark_path
      @bookmark_path || helpers.bookmark_path(@document)
    end

    def label
      helpers.bookmark_control_label @document, @counter, @total
    end
  end
end
