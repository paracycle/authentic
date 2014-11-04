module Authentic
  module Clipboard
    def pbcopy(input)
      str = input.to_s
      IO.popen('pbcopy', 'w') { |f| f << str }
      str
    end

    def pbpaste
      `pbpaste`
    end

    module_function :pbcopy, :pbpaste
  end
end
