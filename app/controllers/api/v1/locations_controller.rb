# frozen_string_literal: true

module Api
  module V1
    # This is locations Controller
    class LocationsController < ApplicationController
      # Fetch all available locations in the cumulative dump
      def index
        locations = Location.where(location_id: Encounter.all.select(:site_id).distinct.map(&:site_id))
        render json: paginate(locations), status: :ok
      end
    end
  end
end
