class ApplicationController < ActionController::API
  include ExceptionHandler

  DEFAULT_PAGE_SIZE = 10

  def paginate(queryset)
    return queryset.all if params[:paginate] == 'false'

    limit = (params[:page_size] || DEFAULT_PAGE_SIZE).to_i
    offset = (((params[:page] || 1).to_i)-1) * limit

    queryset.offset(offset).limit(limit)
  end
end
