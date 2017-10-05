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

    desc "add NAME SECRET_KEY [SERVICE]", "Add a new TOTP key"
    def add(name, secret_key, service = nil)
      params = {
        label: "authentic gem",
        account:  name,
        service:  service || name,
        password: secret_key,
      }

      begin
        item = Keychain.generic_passwords.create(params)
      rescue => e
        message = e.message
      end

      unless item.nil?
        say "\u2713".colorize(:green) + " Service #{name.colorize(:green)} added to keychain"
      else
        say "\u2717".colorize(:red) + " Couldn't add service #{name.colorize(:red)}..."
        say "Error: #{message}" unless message.nil?
      end
    end

    desc "delete NAME", "Delete a TOTP key"
    option :force, default: false, type: :boolean, aliases: '-f'
    def delete(name)
      item = Keychain.generic_passwords.where(label: "authentic gem", account: name).first
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
    option 'qr-codes', default: false, type: :boolean, aliases: '-qr'
    def generate
      now  = Time.now
      keys = Keychain
              .generic_passwords
              .where(label: "authentic gem")
              .all.map do |key|
                secret = key.password.gsub(/=*$/, '')
                totp = ROTP::TOTP.new(secret)
                OpenStruct.new(
                  secret:  secret,
                  code:    totp.at(now),
                  name:    key.attributes[:account],
                  service: key.attributes[:service],
                  remain:  now.utc.to_i % totp.interval
                )
              end.sort_by { |k| [k.service, k.name] }

      if options['qr-codes']
        keys.each do |key|
          puts "#{key.service} - #{key.name}\n"
          puts `qrencode 'otpauth://totp/#{key.name}?issuer=#{key.service}&secret=#{key.secret}' -s 5 -o - | ~/.iterm2/imgcat`
        end
        return
      end

      table = keys.each_with_index.map do |key, idx|
        number = (idx + 1).to_s.rjust(keys.size.to_s.size, ' ')
        service_prefix = "#{key.service} - " if key.service && key.service != key.name
        [
          number.colorize(:red),
          key.code.colorize(:green),
          "#{service_prefix}#{key.name}",
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
