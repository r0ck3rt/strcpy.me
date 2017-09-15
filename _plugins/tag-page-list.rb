module Jekyll
  class TagPageList < Liquid::Tag

    def initialize(tag_name, text, tokens)
      super
    end

    def render(context)
      tags = context.registers[:site].tags

      html = ""
      sorted = tags.sort_by { |t,posts| posts.count }
      sorted.reverse.each do |t, posts|
        html << "<li><span class=\"tag-name\" id=\"#{ t }\">「#{ t }」</span>"
        posts.each do |post|\
          html << "<a class=\"tag-post\" href=\"#{ post.url }\" title=\"#{ post.title }\">#{ post.title }</a>"
        end
        html << "</li>"
      end

      html
    end
  end
end

Liquid::Template.register_tag('tag_page_list', Jekyll::TagPageList)
