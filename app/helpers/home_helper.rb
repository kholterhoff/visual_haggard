module HomeHelper
  def linked_biography_novel_title(novel, fallback:, short: false, **options)
    return work_title(fallback) if novel.blank?

    linked_novel_title(novel, short:, **options)
  end
end
