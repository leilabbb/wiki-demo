require "kramdown"
require "uri"

module Jekyll
  class WikiLinks < Generator
    safe true
    priority :low

    def initialize(config = {})
      unless config["wikiToJekyll"]
        raise "Missing wikiToJekyll configuration in _config.yml"
      end

      $wikiDatas = {
        "conf" => config,
        "pages" => {}
      }
    end

    def generate(site)
      config = $wikiDatas["conf"]
      wiki_config = config["wikiToJekyll"]

      wiki_pages = site.pages.select do |page|
        page.data["menu"] == "wiki"
      end

      wiki_pages.each do |page|
        local_url =
          "#{config["baseurl"]}/" \
          "#{wiki_config["wiki_dest"]}/" \
          "#{page.basename}.html"

        $wikiDatas["pages"][page.basename] = {
          "possible_uris" => get_possible_uris(page),
          "jekyll_url" => local_url
        }
      end
    end

    private

    def get_wiki_repository_url
      config = $wikiDatas["conf"]
      wiki_config = config["wikiToJekyll"]

      if wiki_config["wiki_repository_url"]
        wiki_config["wiki_repository_url"]
          .sub(".wiki.git", "")
          .concat("/wiki")
      else
        "https://github.com/" \
          "#{wiki_config["user_name"]}/" \
          "#{wiki_config["repository_name"]}/wiki"
      end
    end

    def get_possible_uris(page)
      wiki_base_url = get_wiki_repository_url
      uri = URI.parse(wiki_base_url)
      page_name = page.data["wikiPageName"]

      names = [
        page_name,
        page_name.gsub(" ", "-").downcase,
        *camel_case(page_name, "-"),
        *camel_caps(page_name, "-"),
        page_name.gsub("-", " ").downcase
      ].uniq

      patterns = []

      names.each do |name|
        patterns << "#{wiki_base_url}/#{name}"
        patterns << "#{wiki_base_url}/#{name}/"
        patterns << "#{uri.path}/#{name}"
        patterns << "#{uri.path}/#{name}/"
        patterns << name
      end

      if page_name.downcase == "home"
        patterns << wiki_base_url
        patterns << "#{wiki_base_url}/"
        patterns << uri.path
        patterns << "#{uri.path}/"
      end

      patterns
    end

    def camel_case(string, separator = " ")
      words = string.downcase.split(separator)
      words[0] = words[0].capitalize

      [
        words.join("-"),
        words.join(" ")
      ]
    end

    def camel_caps(string, separator = " ")
      words = string.downcase
                    .split(separator)
                    .map(&:capitalize)

      [
        words.join("-"),
        words.join(" ")
      ]
    end
  end
end

module Kramdown
  module Converter
    class Html < Base
      alias_method :original_convert_a, :convert_a

      def convert_a(element, indent)
        attributes = element.attr.dup

        href = attributes["href"]

        unless href.nil? || href.start_with?("mailto:")
          $wikiDatas["pages"].each_value do |page|
            if page["possible_uris"].include?(href)
              Jekyll.logger.info(
                "Changed wiki URL",
                "#{href} => #{page["jekyll_url"]}"
              )

              attributes["href"] = page["jekyll_url"]
              break
            end
          end
        end

        content = inner(element, indent)
        format_as_span_html(element.type, attributes, content)
      end
    end
  end
end