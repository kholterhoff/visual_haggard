class SearchController < ApplicationController
  def index
    @search_query = params[:search].presence || params[:q]
    @search = ArchiveSearch.new(query: @search_query, page: params[:page])
  end
end
