module Jekyll
  class PopularTags < Liquid::Tag

    def initialize(tag_name, text, tokens)
      super
    end

    def render(context)
      tags = context.registers[:site].tags

      html = ""
      sorted = tags.sort_by { |t,posts| posts.count }
      sorted.reverse.each do |t, posts|
        html << "<a href=\"/tags/##{ t }\" class=\"tag\">#{ t }</a> "
      end

      html
    end
  end
end

Liquid::Template.register_tag('popular_tags', Jekyll::PopularTags)
