class OriginalIllustrationsController < ApplicationController
  def show
    @original_illustration = OriginalIllustration.includes(:novel, :illustrations, image_attachment: :blob).find(params[:id])
    @printed_illustrations = @original_illustration.illustrations
                                                   .browseable
                                                   .includes(:illustrator, { edition: :novel }, { image_attachment: :blob })
                                                   .to_a
                                                   .sort_by { |ill| [ill.edition.publication_sort_key, ill.id] }
  end
end
