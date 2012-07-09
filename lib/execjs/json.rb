require "multi_json"

module ExecJS
  module JSON
    if MultiJson.respond_to?(:dump)
      def self.decode(obj, json_options = ExecJS.json_options)
        MultiJson.load(obj, json_options)
      end

      def self.encode(obj, json_options = ExecJS.json_options)
        MultiJson.dump(obj, json_options)
      end
    else
      def self.decode(obj, json_options = ExecJS.json_options)
        MultiJson.decode(obj, json_options)
      end

      def self.encode(obj, json_options = ExecJS.json_options)
        MultiJson.encode(obj, json_options)
      end
    end
  end
end
