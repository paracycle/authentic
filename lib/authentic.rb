require "authentic/version"
require "authentic/clipboard"
require "thor"
require "keychain"
require "rotp"
require "colorize"
require "ostruct"

module Authentic
  class CLI < Thor
    package_name "Authentic"
    default_task :generate

    desc "add NAME SECRET_KEY [LABEL]", "Add a new TOTP key"
    def add(name, secret_key, label = nil)
      params = {
        service:  "authentic gem",
        password: secret_key,
        account:  name,
      }
      params[:comment] = label if label

      begin
        item = Keychain.generic_passwords.create(params)
      rescue => e
        message = e.message
      end

      unless item.nil?
        say "\u2713".colorize(:green) + " Service #{name.colorize(:green)} add to keychain"
      else
        say "\u2717".colorize(:red) + " Couldn't add service #{name.colorize(:red)}..."
        say "Error: #{message}" unless message.nil?
      end
    end

    desc "delete NAME", "Delete a TOTP key"
    option :force, default: false, type: :boolean, aliases: '-f'
    def delete(name)
      item = Keychain.generic_passwords.where(service: "authentic gem", account: name).first
      unless item
        return say "\u2717".colorize(:red) + " Couldn't find service #{name.colorize(:red)}..."
      end
      if options[:force] || yes?("Do you want to permanently delete #{name.colorize(:green)}?")
        item.delete
        say "\u2713".colorize(:green) + " Service #{name.colorize(:green)} deleted from keychain"
      else
        say "Leaving service #{name.colorize(:green)} in keychain"
      end
    end

    CLOCKS = {
      0 => "🌕",
      7 => "🌖",
      14 => "🌗",
      21 => "🌘",
      28 => "🌑",
    }

    desc "generate", "Generate TOTP codes"
    option 'skip-copy', default: false, type: :boolean, aliases: '-s'
    def generate
      now  = Time.now
      keys = Keychain
              .generic_passwords
              .where(service: "authentic gem")
              .all.map do |key|
                totp = ROTP::TOTP.new(key.password.gsub(/=*$/, ''))
                OpenStruct.new(
                  code:   totp.at(now),
                  name:   key.attributes[:account],
                  label:  key.attributes[:comment],
                  remain: now.utc.to_i % totp.interval
                )
              end

      table = keys.each_with_index.map do |key, idx|
        number = (idx + 1).to_s.rjust(keys.size.to_s.size, ' ')
        [
          number.colorize(:red),
          key.code.colorize(:green),
          "#{key.name} #{(" (#{key.label})" if key.label)}",
          CLOCKS[7 * (key.remain / 7)].colorize(:blue)
        ]
      end

      print_table(table.to_a)

      unless options['skip-copy']
        if keys.size > 1
          prompt = "\nWhich key should I copy?"
          prompt += " [1-#{keys.size}, leave empty to exit]"
          response = ask prompt
          return if response.empty?
          idx = response.to_i - 1
          key = keys[idx]
        else
          key = keys.first
        end
        Clipboard.pbcopy key.code
        say "\nKey for account #{key.name.colorize(:green)} copied to clipboard"
      end
    end
  end
end
