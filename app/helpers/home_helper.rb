module HomeHelper
  def linked_biography_novel_title(novel, fallback:, short: false, **options)
    return work_title(fallback) if novel.blank?

    linked_novel_title(novel, short:, **options)
  end

  def linked_editors_statement_novel_title(novel, label:, **options)
    return work_title(label) if novel.blank?

    linked_work_title(label, novel_path(novel), **options)
  end

  def linked_editors_statement_illustrator_name(illustrator, label:, **options)
    return label if illustrator.blank?

    link_to label, illustrator_path(illustrator), **options
  end
end
