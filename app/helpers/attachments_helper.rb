module AttachmentsHelper
  def file_icon_classes(file)
    ext = file_extension(file)
    case ext
    when 'pdf'
      'bg-danger-800/20 border-danger-800 text-danger-400'
    when 'mp3', 'wav', 'ogg', 'flac'
      'bg-purple-950 border-purple-800 text-purple-400'
    when 'zip', 'rar', '7z', 'tar', 'gz'
      'bg-yellow-950 border-yellow-800 text-yellow-400'
    when 'doc', 'docx'
      'bg-jordy-blue-950 border-jordy-blue-900 text-jordy-blue-400'
    else
      'bg-bunker-875 border-bunker-825 text-bunker-400'
    end
  end

  def file_extension(file)
    File.extname(file.filename.to_s).delete('.').downcase
  end

  def file_extension_label(file)
    file_extension(file).upcase
  end

  def human_file_size(bytes)
    if bytes < 1024
      "#{bytes}b"
    elsif bytes < 1024 * 1024
      "#{(bytes / 1024.0).round(1)}kb"
    elsif bytes < 1024 * 1024 * 1024
      "#{(bytes / (1024.0 * 1024)).round(1)}mb"
    else
      "#{(bytes / (1024.0 * 1024 * 1024)).round(1)}gb"
    end
  end

  def image_grid_class(count)
    case count
    when 1 then 'grid-cols-1'
    else 'grid-cols-2'
    end
  end
end
