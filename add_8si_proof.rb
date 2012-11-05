#!/usr/bin/env ruby

require 'rubygems'
require 'cgi'
require 'RMagick'
include Magick

BASE_DIRS = {
  :incoming   => ARGV[0],
  :thumbnails => ARGV[1],
  :proofs     => "#{ ARGV[1] }/proofs"
}

JPG_COMPRESSION = {
  :thumbnail => 60,
  :proof     => 75
}

WATERMARK_ROTATION = -45

# in pixels...
DIMENSIONS = {
  :proof     => 500,
  :watermark => 334,
  :thumbnail => 200
}

def make_thumbnail(base_img, output_img, text='', size=9, font='Times', rotation=0, fill='white', stroke='none')
  mark = Magick::Image.new(DIMENSIONS[:thumbnail], DIMENSIONS[:thumbnail]) do
    self.background_color = 'none'
  end
  gc = Magick::Draw.new
  gc.annotate(mark, 0, 0, 0, 0, text) do
    self.gravity     = Magick::CenterGravity
    self.pointsize   = size
    self.font_family = font
    self.fill        = fill
    self.stroke      = stroke
  end
  mark.rotate!(rotation)

  img   = Image.new(base_img)
  thumb = img.resize_to_fill(DIMENSIONS[:thumbnail], DIMENSIONS[:thumbnail])
  thumb = thumb.watermark(mark, 0.15, 0, Magick::EastGravity)
  thumb.write(output_img) { self.quality = JPG_COMPRESSION[:thumbnail] }
end

def make_proof(base_img, output_img, text = '', size = 32, font = 'Times', rotation = WATERMARK_ROTATION, fill = 'white', stroke = 'none')
  mark = Magick::Image.new(DIMENSIONS[:watermark], DIMENSIONS[:watermark]) do
    self.background_color = 'none'
  end
  gc = Magick::Draw.new
  gc.annotate(mark, 0, 0, 0, 0, text) do
    self.gravity     = Magick::CenterGravity
    self.pointsize   = size
    self.font_family = font
    self.fill        = fill
    self.stroke      = stroke
  end
  mark.rotate!(rotation)

  _img = Magick::Image.read(base_img)
  _img = _img.watermark(mark, 0.15, 0, Magick::EastGravity)
  _img.write(output_img) { self.quality = JPG_COMPRESSION[:proof] }
end

cgi = CGI.new('html4')
base_dirs = {
  :incoming    => ARGV[0] || cgi[ 'sourcedir' ],
  :destination => ARGV[1] || cgi[ 'destdir'   ]
}

if (base_dirs[:incoming].empty? || base_dirs[:destination].empty?)
  missing = []
  missing << 'sourcedir' if ( base_dirs[ :incoming    ].empty? )
  missing << 'destdir'   if ( base_dirs[ :destination ].empty? )
  cgi.message('Missing: %s', missing.join(', '))
  exit
end

images = ImageList.new(Dir.entries("#{ BASE_DIRS[:incoming] }/#{ source_dir }").reject{ |n| n[/^\./] }.select{ |n| n[/\.jpg$/i] }) rescue []

if (images.any?)
  images.each do |_image|
    make_thumbnail("#{ BASE_DIRS[:incoming] }/#{ _image }", "#{ BASE_DIRS[:thumbnails] }/#{ _image }")
    make_proof("#{     BASE_DIRS[:incoming] }/#{ _image }", "#{ BASE_DIRS[:proofs]     }/#{ _image }")
  end
else
  puts "No images to process"
  exit
end

